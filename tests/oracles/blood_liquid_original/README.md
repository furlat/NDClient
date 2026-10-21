# Existing original liquid-field reference

The twenty `.bin` files and `source.json` are unchanged copies of the existing
`.runtime/blood-liquid-reference` reference. The original receipt identifies
`game_obsolete/surface_residue.py::_deposit_patch` and the captured Dash seed3
operation 3. Each file contains a 64×64 float32 field for the named cell.

The durable schema16 Dash original at
`tests/fixtures/schema16/scenarios/dash/amber/0000000000000003.json` discloses the
same twenty cells in its actual slashing body release at `[4,6]`, with the
ellipse centered at `[3.58,6]`, radii 2.1/1.6 and angle π. The existing native
residue gate compares every field pixel against these independent values,
retaining its 0.008 numeric bound and positive scene-coverage assertions.

`original_operation.json` preserves that exact original schema8 packet unchanged
as numerical-reference provenance. The gate compares its entire body-release
object with the current actual operation before using any expected field. The
old packet is never admitted or replayed through the current SDK.

No expected field was recomputed from the current client. Preservation of this
reference is not a fresh native pass, new art, performance or human acceptance.
