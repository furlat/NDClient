#!/bin/bash
# Live gameplay acceptance: every bounded production-scene test that tools/play.py
# offers, each against a freshly started backend (the pinned engine copy), run one
# after another. Prints one line per test: exit code, checks, failures, script
# errors, run directory. Run it after every merge, before calling the work done.
#   tools/live_suite.sh [engine]   (default: the pinned dnd_engine-229ce025f copy)
set -u
cd "$(dirname "$0")/.."
E=${1:-/home/tommaso/.cache/ndclient/dnd_engine-229ce025f}
PY=/home/tommaso/.cache/dnd-engine/venv/bin/python
TESTS="player_startup_checks live_idle_ui_checks player_wait_checks player_live_checks player_interaction_checks live_spell_checks live_gallery_checks lighting_live_checks chest_live_checks"
for t in $TESTS; do
  scenario=crypt_gallery
  case $t in live_spell_checks) scenario=gallery_sorcerer;; esac
  log=$(mktemp)
  PYTHONPATH=$E:$E/sdk/python/src timeout 1800 $PY tools/play.py --engine "$E" --scenario $scenario \
    --test-script res://tests/$t.gd > "$log" 2>&1
  code=$?
  run=$(grep -oE '/[^ ]*\.runtime/player-runs/[0-9TZ.]+' "$log" | head -1)
  result=""; errors="?"
  if [ -n "$run" ]; then
    [ -f "$run/player-live-checks.json" ] && result=$(python3 -c "import json,sys;d=json.load(open(sys.argv[1]));print('checks',d.get('checks'),'failures',len(d.get('failures',[])))" "$run/player-live-checks.json" 2>/dev/null)
    errors=$(grep -c 'SCRIPT ERROR' "$run/godot.log" 2>/dev/null)
  fi
  echo "$t exit=$code $result script_errors=$errors $run"
  [ $code -ne 0 ] && tail -3 "$log" | sed 's/^/    /'
  rm -f "$log"
done
