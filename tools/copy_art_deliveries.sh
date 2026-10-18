#!/bin/bash
# Copies every art delivery the client presents into the project's own
# assets/art/ (git-ignored binaries; the deliveries stay where they are as the
# backup). Only the files presentation reads are copied: colour, depth, normals
# and masks, plus small catalogs; review images, float caches (.npz) and
# per-pixel metric dumps stay behind. Re-running copies only what changed.
# Uses Windows robocopy (multi-threaded): a WSL copy of ~100k small files onto
# the Windows drive runs at a few files per second.
#   tools/copy_art_deliveries.sh
set -uo pipefail
DOCS=/mnt/c/Users/tommaso/Documents
CAT=$DOCS/assets/fantasy-unified-catalog
ART=$(cd "$(dirname "$0")/.." && pwd)/assets/art
mkdir -p "$ART"
# Godot must not import tens of thousands of raw sheets; the build reads them
# from disk and writes the shipped resources into build/.
touch "$ART/.gdignore"

# copy <from> <to> [file patterns...]: whole tree, or only matching files.
copy() {
  local from=$(wslpath -w "$1") to=$(wslpath -w "$2"); shift 2
  cmd.exe /c robocopy "$from" "$to" "$@" /S /MT:32 /R:1 /W:1 /NFL /NDL /NJH /NP > /dev/null
  local code=$?
  if [ $code -ge 8 ]; then echo "robocopy failed ($code): $from"; exit 1; fi
}

# Colour sheets, icons, portraits, environment banks and legacy effect banks.
copy "$DOCS/Dev/NDClientData/.media" "$ART/media"

# Modular component depth/normals (one packet per category and action).
copy "$CAT/modular-character-geometry-2026-10-11/full-components/exports/fused/maps" "$ART/geometry/modular" \
  depth.png normals.png raw-support.png normal-valid.png solid-valid.png lighting-valid.png
copy "$CAT/modular-character-geometry-2026-10-11/full-components/exports/queue/package" "$ART/geometry/modular" catalog.json HANDOFF.md
# Gentle and Reference profiles of the modular normals.
copy "$DOCS/Dev/NDCharacterLight/.derived/normals" "$ART/geometry/modular-profiles"

# Creature depth/normals: first delivery (goblins, orcs, demons), animals and
# the full library (people, undead, zombies, dinosaurs).
PACKET=(colour.png depth.png normals.png normals-gentle.png normals-reference.png raw-support.png
  normal-valid.png layout.json metrics.json normal-profiles.json "catalog*.json" complete-source-index.json HANDOFF.md)
copy "$CAT/authored-creature-geometry-2026-10-12/delivery" "$ART/geometry/creatures/first" "${PACKET[@]}"
copy "$CAT/authored-creature-geometry-2026-10-12/animals/delivery" "$ART/geometry/creatures/animals" "${PACKET[@]}"
copy "$CAT/authored-creature-geometry-2026-10-12/full-library/delivery" "$ART/geometry/creatures/library" "${PACKET[@]}"
copy "$CAT/authored-creature-geometry-2026-10-12/authoring" "$ART/geometry/creatures" registered-rigs.json

# Environment receiving normals (quality pass) and the light cookie.
copy "$CAT/environment-normal-quality-2026-10-12/source-render" "$ART/geometry/environment-quality/source-render"
copy "$CAT/environment-normal-quality-2026-10-12" "$ART/geometry/environment-quality" quality.json /LEV:1
copy "$DOCS/Dev/NDCharacterLight/.reference-template/scenes/vfx/textures" "$ART/lighting" T_basic1_vfx.PNG /LEV:1

# Icons and portraits delivered on 18 October. The delivery ships its runtime
# files inside a zip: icons (smooth48), portraits (192x256), the manifest and
# the coverage/binding maps.
mkdir -p "$ART/ui-delivery-20261018"
unzip -o -q "$DOCS/Codex/2026-10-15/bg3-36-spell-icons-20261015/outputs/combined/combined-runtime.zip" -d "$ART/ui-delivery-20261018"
echo "art copied into $ART"
du -sh "$ART"
