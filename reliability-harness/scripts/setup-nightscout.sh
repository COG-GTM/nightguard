#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STATE="$ROOT/reliability-harness/.state"
NIGHTSCOUT="$STATE/cgm-remote-monitor"
NODE20_BIN="${NODE20_BIN:-/opt/homebrew/opt/node@20/bin}"
TAG="v15.0.9"

mkdir -p "$STATE"
if [[ ! -d "$NIGHTSCOUT/.git" ]]; then
  git clone --depth 1 --branch "$TAG" https://github.com/nightscout/cgm-remote-monitor.git "$NIGHTSCOUT"
fi

pinned_commit="$(git -C "$NIGHTSCOUT" rev-parse "refs/tags/$TAG^{commit}")"
current_commit="$(git -C "$NIGHTSCOUT" rev-parse HEAD)"
if [[ "$current_commit" != "$pinned_commit" ]]; then
  printf 'Expected Nightscout %s at %s, found %s\n' \
    "$TAG" "$pinned_commit" "$current_commit" >&2
  exit 1
fi
if [[ ! -x "$NODE20_BIN/node" || ! -x "$NODE20_BIN/npm" ]]; then
  printf 'Node 20 was not found in %s\n' "$NODE20_BIN" >&2
  exit 1
fi

export PATH="$NODE20_BIN:$PATH"
node_major="$(node -p 'process.versions.node.split(".")[0]')"
if [[ "$node_major" != "20" ]]; then
  printf 'Expected Node 20, found %s\n' "$(node --version)" >&2
  exit 1
fi

cd "$NIGHTSCOUT"
npm ci
printf 'Nightscout %s installed with Node %s and npm %s\n' \
  "$TAG" "$(node --version)" "$(npm --version)"
