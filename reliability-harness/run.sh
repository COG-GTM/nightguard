#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ "${1:-}" == "--merge" ]]; then
  shift
  exec python3 "$ROOT/reliability-harness/scripts/merge.py" "$@"
fi
exec python3 "$ROOT/reliability-harness/scripts/run.py" "$@"
