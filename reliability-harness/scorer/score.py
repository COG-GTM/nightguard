#!/usr/bin/env python3
import argparse
import json
import math
from collections import Counter
from datetime import datetime
from pathlib import Path


def read_json(path):
    with path.open(encoding="utf-8") as source:
        return json.load(source)


def read_jsonl(path):
    if not path or not Path(path).exists():
        return []
    with Path(path).open(encoding="utf-8") as source:
        return [json.loads(line) for line in source if line.strip()]


def percentile(values, fraction):
    if not values:
        return None
    ordered = sorted(values)
    rank = max(1, math.ceil(fraction * len(ordered)))
    return ordered[rank - 1]


def wilson_interval(successes, total):
    if total == 0:
        return [None, None]
    z = 1.96
    rate = successes / total
    denominator = 1 + z * z / total
    centre = (rate + z * z / (2 * total)) / denominator
    margin = z * math.sqrt(rate * (1 - rate) / total + z * z / (4 * total * total)) / denominator
    return [max(0, centre - margin), min(1, centre + margin)]


def numeric_bg(value):
    try:
        return float(str(value).strip().replace(",", "."))
    except (TypeError, ValueError):
        return None


def dominant_fault(logs, start_ms, end_ms):
    affected = Counter()
    for entry in logs:
        try:
            entry_ms = int(datetime.fromisoformat(
                entry["tsStart"].replace("Z", "+00:00")
            ).timestamp() * 1000)
        except (KeyError, TypeError, ValueError):
            continue
        if not start_ms <= entry_ms <= end_ms:
            continue
        name = f"episode:{entry['episode']}" if entry.get("episode") else entry.get("fault")
        if name:
            affected[name] += 1
    return affected.most_common(1)[0][0] if affected else None


def score_session(metadata, gateway_logs, shape):
    session_id = metadata.get("sessionId")
    events = read_jsonl(metadata.get("eventFile"))
    readings = metadata.get("readings", [])
    threshold = shape["low_threshold_mgdl"]
    missed_threshold_ms = shape["missed_readings_threshold_minutes"] * 60_000
    low_reading = next((item for item in readings if item["sgv"] < threshold), None)
    row = {
        "sessionId": session_id,
        "sessionIndex": metadata.get("sessionIndex"),
        "slot": metadata.get("slot"),
        "profileMode": metadata.get("profileMode", "profile"),
        "t0Ms": metadata.get("t0Ms"),
        "testExitCode": metadata.get("testExitCode"),
        "types": [],
        "success": False,
        "harnessError": None,
        "lowReading": low_reading,
        "lowDisplayedAtMs": None,
        "lowAlarmAtMs": None,
        "falseMissedReadingsAtMs": [],
        "dominantFault": None,
        "latencyMsFromAvailableAt": None,
        "latencyMsFromReadingTimestamp": None,
        "overheadMs": metadata.get("overheadMs"),
    }
    if metadata.get("testExitCode") not in (0, None) or metadata.get("harnessError"):
        row["harnessError"] = metadata.get("harnessError") or f"test exit {metadata.get('testExitCode')}"
    elif not events:
        row["harnessError"] = "UI test produced no event stream"

    if low_reading:
        for event in events:
            if numeric_bg(event.get("bgValue")) == low_reading["sgv"]:
                row["lowDisplayedAtMs"] = event.get("hostWallClockMs")
                break
        for event in events:
            reason = event.get("alarmReason") or ""
            if "Low BG" in reason and event.get("hostWallClockMs") is not None:
                row["lowAlarmAtMs"] = event["hostWallClockMs"]
                break

    for event in events:
        reason = event.get("alarmReason") or ""
        at_ms = event.get("hostWallClockMs")
        if at_ms is None or "Missed Readings" not in reason:
            continue
        fresh = any(
            reading["availableAtMs"] <= at_ms and reading["timestampMs"] > at_ms - missed_threshold_ms
            for reading in readings
        )
        if fresh:
            row["falseMissedReadingsAtMs"].append(at_ms)

    if not row["harnessError"]:
        if low_reading and row["lowDisplayedAtMs"] is not None and row["lowAlarmAtMs"] is not None:
            latency_timestamp = row["lowAlarmAtMs"] - low_reading["timestampMs"]
            latency_available = row["lowAlarmAtMs"] - low_reading["availableAtMs"]
            row["latencyMsFromReadingTimestamp"] = latency_timestamp
            row["latencyMsFromAvailableAt"] = latency_available
            if 0 <= latency_timestamp <= 5 * 60_000:
                row["success"] = not row["falseMissedReadingsAtMs"]
            elif latency_timestamp > 5 * 60_000:
                row["types"].append("LATE")
            else:
                row["types"].append("MISSED")
        else:
            row["types"].append("MISSED")
        if row["falseMissedReadingsAtMs"]:
            row["types"].append("FALSE_MISSED_READINGS")
            row["success"] = False

    target = low_reading["timestampMs"] if low_reading else metadata.get("t0Ms", 0)
    mr_alarm = next(iter(row["falseMissedReadingsAtMs"]), None)
    end = mr_alarm or row["lowAlarmAtMs"] or target + 5 * 60_000
    session_logs = [
        entry for entry in gateway_logs
        if entry.get("sessionId") == session_id and entry.get("endpointClass") != "control"
    ]
    row["dominantFault"] = dominant_fault(session_logs, target, end)
    return row


def aggregate_rows(rows):
    valid = [row for row in rows if not row["harnessError"]]
    successes = sum(row["success"] for row in valid)
    types = Counter(issue for row in valid for issue in row["types"])
    dominant_counts = Counter(
        row["dominantFault"] for row in valid
        if not row["success"] and row["dominantFault"]
    )
    success_and_late = [
        row for row in valid
        if row["success"] or "LATE" in row["types"]
    ]
    availability_latencies = [
        row["latencyMsFromAvailableAt"] for row in success_and_late
        if row["latencyMsFromAvailableAt"] is not None
    ]
    timestamp_latencies = [
        row["latencyMsFromReadingTimestamp"] for row in success_and_late
        if row["latencyMsFromReadingTimestamp"] is not None
    ]
    aggregate = {
        "sessions": len(rows),
        "validSessions": len(valid),
        "successes": successes,
        "successRate": successes / len(valid) if valid else None,
        "wilson95CI": wilson_interval(successes, len(valid)),
        "failureCountsByType": dict(sorted(types.items())),
        "failureCountsByDominantFault": dict(sorted(dominant_counts.items())),
        "harnessErrorSessions": sum(bool(row["harnessError"]) for row in rows),
        "latencyMsFromAvailableAt": {
            "p50": percentile(availability_latencies, 0.50),
            "p95": percentile(availability_latencies, 0.95),
        },
        "latencyMsFromReadingTimestamp": {
            "p50": percentile(timestamp_latencies, 0.50),
            "p95": percentile(timestamp_latencies, 0.95),
        },
    }
    return {"aggregates": aggregate, "sessions": rows}


def render_scorecard(result):
    aggregate = result["aggregates"]
    rows = result["sessions"]
    valid = [row for row in rows if not row["harnessError"]]
    successes = aggregate["successes"]
    ci = aggregate["wilson95CI"]
    lines = [
        "# Nightguard alarm reliability scorecard",
        "",
        f"- N: {aggregate['sessions']} sessions ({aggregate['validSessions']} scored, "
        f"{aggregate['harnessErrorSessions']} harness errors)",
        f"- Success rate: {successes}/{len(valid)}"
        + (f" ({aggregate['successRate']:.1%})" if valid else " (n/a)"),
        f"- Wilson 95% CI: {ci[0]:.1%}–{ci[1]:.1%}" if valid else "- Wilson 95% CI: n/a",
        f"- Failure counts: {json.dumps(aggregate['failureCountsByType'], sort_keys=True)}",
        f"- Failures by dominant fault: "
        f"{json.dumps(aggregate['failureCountsByDominantFault'], sort_keys=True)}",
        f"- Low-reading availableAt → Low BG latency p50/p95: "
        f"{aggregate['latencyMsFromAvailableAt']['p50']} / "
        f"{aggregate['latencyMsFromAvailableAt']['p95']} ms",
        f"- Low-reading timestamp → Low BG latency p50/p95: "
        f"{aggregate['latencyMsFromReadingTimestamp']['p50']} / "
        f"{aggregate['latencyMsFromReadingTimestamp']['p95']} ms",
        "",
        "| Session | Arm | Result | Failure types | Dominant fault | Low BG latency (availableAt) |",
        "|---|---|---|---|---|---:|",
    ]
    for row in rows:
        result_name = "HARNESS ERROR" if row["harnessError"] else "SUCCESS" if row["success"] else "FAILED"
        lines.append(
            f"| {row['sessionId']} | {row['profileMode']} | {result_name} | "
            f"{', '.join(row['types']) or '—'} | "
            f"{row['dominantFault'] or '—'} | {row['latencyMsFromAvailableAt'] or '—'} ms |"
        )
    return "\n".join(lines) + "\n"


def write_result_files(run_dir, result):
    (run_dir / "results.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    (run_dir / "scorecard.md").write_text(render_scorecard(result), encoding="utf-8")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--run-dir", required=True, type=Path)
    parser.add_argument("--shape", required=True, type=Path)
    args = parser.parse_args()

    shape = read_json(args.shape)
    session_dir = args.run_dir / "sessions"
    metadata_files = sorted(session_dir.glob("*.json"))
    metadata = [read_json(path) for path in metadata_files]
    gateway_logs = read_jsonl(args.run_dir / "gateway.jsonl")
    rows = [score_session(item, gateway_logs, shape) for item in metadata]
    write_result_files(args.run_dir, aggregate_rows(rows))


if __name__ == "__main__":
    main()
