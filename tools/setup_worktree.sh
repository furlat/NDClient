#!/bin/bash
# Prepare a worktree for an agent: branch at a commit, its own copy of the VFX
# package binaries, and junctions (no copies) to the shared art, audio and data.
#   tools/setup_worktree.sh <suffix> <branch> <commit>   (worktree ../NDClientGodot-<suffix> must exist:
#   git worktree add ../NDClientGodot-<suffix> -b <branch> <commit>)
set -uo pipefail
W=/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot-$1
MAIN=/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot
win() { wslpath -w "$1"; }
junction() { # junction <path in worktree> <path in main>
  if [ -e "$W/$1" ] || [ -L "$W/$1" ]; then return; fi
  mkdir -p "$(dirname "$W/$1")"
  cmd.exe /c mklink /J "$(win "$W/$1")" "$(win "$MAIN/$1")" > /dev/null
}
# A whole-assets junction would let git write the tracked package into the main tree.
if [ -L "$W/assets" ]; then rm "$W/assets"; fi  # a WSL symlink: removes the link only
git -C "$W" checkout -q -B "$2" "$3" || exit 1
mkdir -p "$W/assets/vfx"
cmd.exe /c robocopy "$(win "$MAIN/assets/vfx")" "$(win "$W/assets/vfx")" '*.res' '*.scn' /S /MT:32 /R:1 /W:1 /NFL /NDL /NJH /NJS /NP > /dev/null
for p in assets/audio assets/native_effects assets/art .derived generated/render_cache \
  .runtime/studio-cases .runtime/studio-spells-20261015 .runtime/studio-spells-20261018 \
  .runtime/gallery-route .runtime/gallery-sorcerer-20261015-seed3-door; do junction "$p"; done
git -C "$W" log --oneline -1
git -C "$W" status --short | head -5
