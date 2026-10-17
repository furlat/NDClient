#!/bin/bash
# Run N live Gallery spell routes serially (native Windows Godot via tools/play.py)
# and print each run directory with its check/failure/script-error counts.
# Usage: tools/live_routes.sh [N]
cd "$(dirname "$0")/.." || exit 1
N=${1:-1}
for i in $(seq 1 "$N"); do
  out=$(PYTHONPATH="$PWD/../dnd_engine:$PWD/../dnd_engine/sdk/python/src" timeout 600 \
    /home/tommaso/.cache/dnd-engine/venv/bin/python tools/play.py --scenario gallery_sorcerer \
    --test-script res://tests/live_spell_checks.gd --live-fireball-ui --profile-pipeline --profile-view-size 18 2>&1)
  dir=$(echo "$out" | grep -o '/mnt/c[^ ]*player-runs/[0-9TZ.]*' | head -1)
  checks=$(python3 -c "import json;d=json.load(open('$dir/player-live-checks.json'));print(d['checks'],len(d['failures']))" 2>/dev/null || echo "NO_REPORT")
  errors=$(grep -c "SCRIPT ERROR" "$dir/godot.log" 2>/dev/null)
  echo "$dir checks/failures=$checks script_errors=$errors"
done
