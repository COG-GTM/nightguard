#!/usr/bin/env python3
import argparse
import datetime as dt
import json
import sys
from pathlib import Path


SCORER_DIR = Path(__file__).resolve().parents[1] / "scorer"
sys.path.insert(0, str(SCORER_DIR))
import score


METADATA_KEYS = (
    "appRef",
    "appCommit",
    "label",
    "profileFingerprint",
    "shapeFingerprint",
    "controlTreatmentValidation",
    "requestedSessions",
    "runSeed",
)


def read_json(path):
    with path.open(encoding="utf-8") as source:
        return json.load(source)


def main():
    parser = argparse.ArgumentParser(description="Merge compatible reliability-harness shard results.")
    parser.add_argument("results_dirs", nargs="+", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()

    inputs = []
    metadata = []
    sessions = {}
    for directory in args.results_dirs:
        directory = directory.resolve()
        run_metadata = read_json(directory / "run.json")
        result = read_json(directory / "results.json")
        for key in METADATA_KEYS:
            if metadata and run_metadata.get(key) != metadata[0].get(key):
                raise ValueError(f"Incompatible shard metadata for {key}: {directory}")
        if not metadata:
            metadata.append(run_metadata)
        inputs.append(str(directory))
        for row in result.get("sessions", []):
            index = row.get("sessionIndex")
            if not isinstance(index, int):
                raise ValueError(f"Missing integer sessionIndex in {directory}")
            if not 0 <= index < run_metadata["requestedSessions"]:
                raise ValueError(f"sessionIndex {index} is outside the requested N in {directory}")
            previous = sessions.get(index)
            if previous is not None and previous != row:
                raise ValueError(f"Conflicting results for overlapping sessionIndex {index}")
            sessions[index] = row

    source = metadata[0]
    merged_rows = [sessions[index] for index in sorted(sessions)]
    result = score.aggregate_rows(merged_rows)
    result["run"] = {
        "appRef": source["appRef"],
        "appCommit": source["appCommit"],
        "label": source["label"],
        "profileFingerprint": source["profileFingerprint"],
        "shapeFingerprint": source["shapeFingerprint"],
        "controlTreatmentValidation": source["controlTreatmentValidation"],
        "runSeed": source["runSeed"],
        "requestedSessions": source["requestedSessions"],
        "mergedSessionIndexes": sorted(sessions),
        "inputs": inputs,
    }
    now = dt.datetime.now().strftime("%Y%m%d-%H%M%S")
    output = args.output or (
        Path(__file__).resolve().parents[1]
        / "results"
        / f"merged-{source['label']}-seed{source['runSeed']}-{now}"
    )
    output = output.resolve()
    if output in {Path(item) for item in inputs}:
        raise ValueError("Merge output must not overwrite an input results directory")
    output.mkdir(parents=True, exist_ok=False)
    score.write_result_files(output, result)
    (output / "run.json").write_text(
        json.dumps(result["run"], indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"Merged results: {output / 'results.json'}")
    print(f"Scorecard: {output / 'scorecard.md'}")


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(f"Merge failed: {error}", file=sys.stderr)
        raise SystemExit(1)
