# Nightguard alarm reliability harness

This harness measures the real Nightguard app against pinned, local
`cgm-remote-monitor` replicas. Synthetic glucose records are inserted into
MongoDB; the measured app requests pass through the fault gateway to the real
Nightscout replicas. The harness does not change production networking,
polling, or alarm behavior.

## Fresh macOS setup

Use macOS with Xcode 26.6, `xcodebuild`, the iOS 26.5 or 27.0 iPhone 17
simulator runtime, and Python 3. The runner uses Node 20 and MongoDB Community.
For a Homebrew installation:

```sh
brew tap mongodb/brew
brew trust mongodb/brew
brew install node@20 mongodb-community
export NODE20_BIN="$(brew --prefix node@20)/bin"
export MONGOD_BIN="$(brew --prefix mongodb-community)/bin/mongod"
```

Set `NIGHTGUARD_REPO_URL` and `APP_COMMIT` to the repository URL and the
identical committed revision on each VM. Clone it, then enter the checkout:

```sh
git clone "$NIGHTGUARD_REPO_URL" nightguard
cd nightguard
git checkout "$APP_COMMIT"
```

Install the pinned Nightscout dependencies:

```sh
reliability-harness/scripts/setup-nightscout.sh
```

The script installs `nightscout/cgm-remote-monitor` tag `v15.0.9` in
`.state/`, verifies the exact tag commit, and runs `npm ci` with Node 20.
The first `run.sh` invocation automatically performs `xcodebuild
build-for-testing` when no matching cached build exists, reuses persistent
iPhone 17 clones named `Nightguard Reliability slot <n>` (creating a slot only
when missing), starts services, and runs the UI test. Clones are cold-booted
serially with load-average waits between boots, retained booted for the run,
and reused across session waves. Per-session cleanup uninstalls the app and
clears its app-group state without rebooting the clone; all clones are shut
down at run end.
Before launching each UI test, the runner waits for the 1-minute load average
to drop below three times the logical CPU count, for up to 120 seconds. On the
reference host, clean-checkout setup
from clone through first UI-test launch took about **2.1 minutes**. The
Homebrew MongoDB tap and the Node 20.20.2 and MongoDB Community 9.0.4 installs
were already present on that host and were skipped during that measurement.

Allow at least **20 GB free** on the volume containing
`~/Library/Developer` before starting a run. A full run needs about **3 GB**
for derived data plus **2–4 GB per booted simulator clone**. Derived data is
cached by app commit and local overlay and the two most recently used keys are
kept.

The runner starts one local MongoDB process and two real Nightscout replicas
per simulator slot. Slot replicas share `ns_slot_<slot>`; different slots
have separate databases. It generates synthetic API secrets, sets
`AUTH_DEFAULT_ROLES=denied`, `DISPLAY_UNITS=mg/dl`, `INSECURE_USE_HTTP=true`,
and enables the `careportal` plugin. It creates a synthetic `readable`
authorization subject per slot and verifies v3 version, v3 entries, and v1
entries on both replicas before measuring. Authorization subjects are cached in
memory at Nightscout startup: the runner creates each synthetic subject on
replica A, restarts replica B to load the shared subject, then checks both.
Service PID, port, command, and checkout metadata is kept under `.state/`; a
later run stops only matching harness-owned listeners before starting new
services. An occupied untracked MongoDB port is refused.

## Session shape and runs

History contains 13 synthetic records at five-minute intervals across 60
minutes, ending at the nominal t0−2m point. The UI test anchors t0 and the
fault gateway to the first display of the latest history record. Live readings
are LOW 64 at t0+3m, 58 at t0+8m, and 52 at t0+13m. The session ends at t0+14m.
Missed Readings uses the smallest AlarmView picker option, 15 minutes; the
picker options are 15, 20, 25, 30, 35, 40, 45 minutes.

Run one healthy control and one pilot treatment concurrently for a quick
validation:

```sh
reliability-harness/run.sh \
  --app-ref origin/devin/za-135-alarm-reliability-harness \
  --label quick-validation \
  --n 2 \
  --control-treatment-profile reliability-harness/profiles/fault-profile.pilot.json \
  --workers 2 \
  --keep-services-running
```

Index 0 is the healthy control and index 1 uses the pilot profile. For full
arms, use the harness branch for control and merge it into the hypothesis
branch before running treatment:

```sh
reliability-harness/run.sh --app-ref origin/devin/za-135-alarm-reliability-harness --label healthy --n 24 --healthy --seed 135 --workers 2
git merge origin/devin/za-135-alarm-reliability-harness
reliability-harness/run.sh --app-ref "$HYPOTHESIS_BRANCH" --label pilot --n 12 --profile reliability-harness/profiles/fault-profile.pilot.json --seed 135 --workers 2
```

Current planning sizes are healthy N=24–50 as the time budget permits, pilot
N=12, and baseline N=50. The harness seed for each session is derived only
from `(run_seed, sessionIndex)` using FNV-1a32; session IDs are deterministic
as `<label>-<sessionIndex>`. `--seed S` overrides the profile's authored seed.
Replay one session using its original global index, label, seed, N, profile,
and app ref:

```sh
reliability-harness/run.sh --app-ref "$APP_COMMIT" --label baseline --seed 135 --n 50 --profile reliability-harness/profiles/fault-profile.pilot.json --session-index 7
```

To distribute one N=50 arm across fresh VMs, use the same committed app ref,
`--label`, `--seed`, `--n 50`, and profile on every VM. Each shard owns a
contiguous range of global indices:

```sh
reliability-harness/run.sh --app-ref "$APP_COMMIT" --label baseline --seed 135 --n 50 --profile reliability-harness/profiles/fault-profile.pilot.json --shard 1/3 --workers 2
reliability-harness/run.sh --app-ref "$APP_COMMIT" --label baseline --seed 135 --n 50 --profile reliability-harness/profiles/fault-profile.pilot.json --shard 2/3 --workers 2
reliability-harness/run.sh --app-ref "$APP_COMMIT" --label baseline --seed 135 --n 50 --profile reliability-harness/profiles/fault-profile.pilot.json --shard 3/3 --workers 2
```

Copy the result directories from each VM to one checkout, then merge them:
set `VM1_RESULTS`, `VM2_RESULTS`, and `VM3_RESULTS` to those copied directories.

```sh
reliability-harness/run.sh --merge "$VM1_RESULTS" "$VM2_RESULTS" "$VM3_RESULTS"
```

Merge validates shared run metadata, deduplicates identical repeated
`sessionIndex` rows, and errors if overlapping rows conflict. It writes a new
`results.json`, `scorecard.md`, and `run.json` under `results/merged-*`.
By default every index from `0` to `N-1` must be present; missing indices are
listed as an error. `--allow-partial` merges an incomplete set and marks the
scorecard `PARTIAL (k/N)`.

The runner builds the requested app ref in a detached Git worktree with
`xcodebuild build-for-testing`, then runs only
`nightguardUITests/AlarmReliabilityUITests/testAlarmSession` using the resulting
`.xctestrun`. The app ref must already contain the registered
`AlarmReliabilityUITests.swift` and the `--reliability-host-uri` AppDelegate
hook; refs that do not are rejected rather than overlaid. Uncommitted local
changes are still copied into the build worktree. The runner recommends no
more workers than it has measured.
`--keep-services-running` leaves the local services running after the run;
simulator clones are shut down but retained for reuse.

Run output is written to `results/<label>-<timestamp>/`:

- `results.json` contains scored session rows and aggregates.
- `scorecard.md` summarizes success, failures, latency, and harness errors.
- `gateway.jsonl` records gateway requests; token query values and authorization
  request path tokens are redacted.
- `events/` contains host-wall-clock UI samples as JSONL.
- `sessions/` contains per-session metadata and test logs.
- `capacity.json` records the observed parallel worker count and sampled
  simulator/test-process CPU and memory use, plus a target-N time estimate.
- `run.json` records each clone's boot duration, status, and inter-boot load wait.

Per-slot access tokens, per-session runner configuration, MongoDB state,
Nightscout checkout/dependencies, simulator clones, Xcode build products, and
`.xcresult` bundles are under `.state/`. Access tokens are local synthetic
Nightscout tokens; host URIs and tokens stay under `.state/session-configs/`
and `.state/slots/`. Text artifacts under `results/` redact `token=` values.
Do not copy token/config files into results or commit runtime state. Generated
results and `.state/` are gitignored.

## Fault profile and scoring

`profiles/fault-profile.pilot.json` is the authored pilot profile. Its values
and ordered per-request rules are consumed as-is. The gateway derives
deterministic per-session/per-endpoint decisions from FNV-1a and Mulberry32;
episodes are independently selected per session and override request-level
faults for their affected endpoint classes. `profile=null` leaves requests
pass-through.

The gateway round-robins session requests between that slot's actual replicas.
Faults include held-open requests, HTTP 503, delays, stale cached entries,
duplicate entries, JWT/v3 failure episodes, and a replica-B episode that
connects to a closed localhost port and returns 502 after the real
`ECONNREFUSED`.

With replicas running, exercise the pilot per-request rules without simulators:

```sh
node reliability-harness/gateway/self-test.js \
  --replica-a "$NS_A_PORT" \
  --replica-b "$NS_B_PORT" \
  --token-file reliability-harness/.state/slots/slot-1-token.json
```

This issues 200 requests per run against the real replicas, checks each
ordered fault and deterministic decisions, and shortens only hold/delay
durations while disabling timed episodes for the per-request self-test.

The scorer uses Python 3's standard library and the frozen metric: the low
reading must appear in the UI and a `Low BG` reason must appear no later than
five minutes after that reading's timestamp; any `Missed Readings` reason
while server-fresh data exists also fails the session. Failure types can
co-occur; the success denominator counts each valid session once, with
harness-error sessions reported separately.

## UI-only test hooks

The app additions are gated by the existing `--uitesting` launch argument and
do not modify app networking or alarm rules:

- `nightguard/AppDelegate.swift`: copies the test's host URI, low threshold,
  units, and missed-reading threshold from `--reliability-*` launch arguments
  into the existing app-group-backed settings; explicitly enables the
  missed-reading alarm for the test.
- `nightguard/views/MainView.swift`: adds accessibility identifiers for BG,
  last-update, and time labels. The BG label's accessibility value exposes the
  existing alarm reason to the test.
- `nightguardUITests/AlarmReliabilityUITests.swift`: reads the session config
  through the host-only `TEST_RUNNER_SESSION_CONFIG` path. It samples the real
  UI once per second, notifies the gateway when t0 first appears, and batches
  host JSONL writes through the gateway control API.

The Xcode project adds that test source to the existing UI-test target.

## Mocks / build-only stubs

The runner removes the `nightguard` target's `Embed Watch Content` phase and
WatchKit target dependency from `nightguard.xcodeproj/project.pbxproj` in its
temporary build worktree. This lets the iOS UI-test scheme build on hosts without
a watchOS simulator runtime, so fresh VMs do not need to download one. The
exclusion exists only in the temporary build worktree; the repository project
still embeds the WatchKit app, and the measured iOS app behavior is unchanged.
The WatchKit app is not part of the measured path.

If the ignored `nightguard/.env` resource is absent, the runner adds an empty
file in the temporary build worktree so Xcode can copy the configured resource.
It contains no credentials; StoreKit receipt validation and push/backend
registration are outside the measured path.

No mock or placeholder replaces Nightscout, app networking, polling, or alarm
decisions in the measured path.
