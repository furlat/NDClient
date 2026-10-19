#!/bin/bash
# Live gameplay acceptance: the manifest's live tier (every bounded play.py scene,
# each against a fresh pinned backend). Kept as the old name for tools/run_tests.sh.
cd "$(dirname "$0")/.." && exec tools/run_tests.sh --tier live "$@"
