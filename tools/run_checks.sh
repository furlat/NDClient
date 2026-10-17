#!/bin/bash
# Run Godot check scripts serially with the native Windows Godot.
# Usage: tools/run_checks.sh [--native] tests/a_checks.gd [tests/b_checks.gd::--arg=value ...]
# Arguments after "::" are passed to that script after "--".
# --native renders with Forward+/Vulkan instead of --headless (needed by tests
# that await RenderingServer.frame_post_draw). Logs go to .runtime/checks/.
cd "$(dirname "$0")/.." || exit 1
GODOT=/mnt/c/Users/tommaso/Documents/Dev/Tools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe
PROJECT=$(wslpath -w "$PWD")
MODE=(--headless)
if [ "$1" = "--native" ]; then MODE=(--rendering-method forward_plus --rendering-driver vulkan); shift; fi
mkdir -p .runtime/checks
status=0
for item in "$@"; do
  script=${item%%::*}
  extra=()
  if [ "$item" != "$script" ]; then extra=(-- ${item#*::}); fi
  name=$(basename "$script" .gd)
  log=.runtime/checks/$name.log
  timeout "${CHECK_TIMEOUT:-300}" "$GODOT" "${MODE[@]}" --path "$PROJECT" --script "res://$script" "${extra[@]}" > "$log" 2>&1
  code=$?
  errors=$(grep -c -E "SCRIPT ERROR|^ERROR:" "$log")
  summary=$(grep -o -E '"checks": ?[0-9]+|"failures": ?\[[^]]{0,200}' "$log" | tail -2 | tr '\n' ' ')
  echo "$name exit=$code errors=$errors $summary"
  if [ "$code" != 0 ] || [ "$errors" != 0 ]; then status=1; fi
done
exit $status
