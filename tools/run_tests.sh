#!/bin/bash
# One entry point for the test set in tests/manifest.json:
#   tools/run_tests.sh [--tier fast|gate|live|all] [--only name,...] [--all-status] [--jobs N]
# fast: headless, before every commit; gate: GPU picture/order checks, before
# every merge; live: real games through tools/play.py, after every merge.
cd "$(dirname "$0")/.." && exec python3 tools/run_tests.py "$@"
