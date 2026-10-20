# Original class burst render oracle

The unchanged original source is Factory commit
`51f55198b28113fdcc90df9d0613b1f50960d354`, directory
`evidence/native-class-palette-repair-v176/accepted-sources/`.
`ClassComponents.gd`, `Flow.gdshader` and `flow_noise.tres` were read from that
committed source, matching the installed evidence and the previous ignored
`.runtime/native-effects/reference` oracle. This is an independent pre-adapter
source, not a current renderer exported as its own expected output.

Permitted changes: only resource-path relocation in `ClassComponents.gd`.
The Flow shader and procedural noise Resource are byte-for-byte originals.
The native render test always sets `kind="burst"`, rear/front halves, four
quarters and the same three original times. That executed branch's complete
code/resource closure is these three text files; it uses Godot's built-in
meshes/materials and the pinned procedural noise, with no external bitmap.
No artwork, binary, new effect or simulation was copied/generated.

The original film/charge branches remain in the source with their previously
installed asset paths. They are not executed or qualified by this burst gate;
this folder does not claim to close those unrelated branches' dependencies.
Production still uses its own native effect source and composition adapter.
`native_effect_render_checks.gd` captures them independently, and
`tools/check_native_effect_pixels.py` retains its original 24-frame raw/palette
comparison. Source pinning alone is neither a passing native receipt nor user
visual approval.
