# Movement and portals — source audit and focused native transfer

R16 remains partial. This review verifies one SDK-recorded Dimension Door
transfer and the hatch mask against the unchanged original native scenarios.
The hatch evidence is source-qualified, not SDK/Studio acceptance.

## Source boundaries

Read `movement.ts`, `movement-media.ts`, `portals.ts`, `portal-sample.ts`,
`portal-media.ts`, `retained-portals.ts`, the descendant transfer handling in
`compiler.ts`, and the existing transport/movement-tail tests. Compared with
original `portal_art.py`, `portal_animation.py`, `portal_draw.py`, portal/flight
presentation tests and scenarios, and the native Dimension Door/projection code.
Master §6 portal prescriptions, R16 and the selected portal/movement catalogs
remain the governing sources.

- The existing transport recording exercised Misty Step and Conjure Animals;
  it did not prove an upright or ground portal transfer.
- Selected `walkRecovery` and `jumpRecovery` are disabled with empty media.
  They are not missing enabled effects to invent. Flight and window connectors
  retain their explicit source clips, frame keys, clearance and passage values;
  this audit does not claim new native acceptance for them.
- Native descendant `portal_transfer` events already reach `compilePortal`
  after their causative occurrence. Portal identity, admitted endpoint positions,
  authored timing and final native state remain separate from the visual stride.
- Original `clip_portal_bodies` clips and removes contact shadows only while
  entering or emerging. The client previously attached `portalClip` throughout
  the opening wait, prematurely cutting the body and suppressing its shadow.
  `samplePortalPose` now gates that existing clip to the original crossing phase.
  No renderer path or global mask was added.
- Ground-hatch descent now consumes the original inverse hatch-front alpha
  mask in the existing body coverage filter. The selected opening frame,
  quarter, pivot and scale share the visible hatch's source coordinates. Its
  source is prepared during opening and released with the scene. The front mask
  applies only during departure crossing; arrival and settled bodies remain
  unchanged. This is local image coverage, separate from native world geometry.

## Actual native case

`/recordings/dimension-door/case.json` contains three unchanged SDK-delivered
records. The existing native setup selects a level-7 Generic Caster with only
the Dimension Door grant and one passive noncaster Gloomplate. No source rig,
native spell outcome, backend handler or packet was modified.

Discovery admits the caster as the self target at `[3,7]`. The first preview
requires a destination and supplies 225 native next positions, including `[7,7]`.
The completed selection previews `can_confirm: true` and the exact caster UUID.
Sequence 2 commits `portal_content_id: spell.dimension_door`, start `[3,7]`, end
`[7,7]`, `committed: true`. Its selected source has `transitMs: 0`; the client
preserves that immediate authored handoff instead of adding an absence interval.
Private capture server 8807 was stopped after recording.

## Acceptance and limits

`tests/transport.test.ts` first failed on the premature clip, then passed after
the phase correction. It checks the actual committed destination, intact opening,
crossing-only mask, restored settled pose and both original front/back endpoint
banks in every quarter. A separate occurrence check restricts drawing to admitted
visible endpoint cells; that check is not a native one-end witness recording.

`tests/portal-transfer.browser.mjs` passes 40 native samples: four quarters,
camera zoom 1 and 2, opening, entering, emerging, settled and complete. The
production worker, occurrence preparation and sole renderer draw the actual
recording. Opening and settled shadows retain alpha 0.5; crossing suppresses
them. Temporarily omitting the local clip changes visible pixels; restoring the
same sample restores the image exactly. Reapplying the old premature clip also
changes opening pixels, proving the repaired phase has an observable effect.

All samples have empty compile issues, zero repeated-draw differences and zero
diagnostic restoration differences. Both endpoint banks remain until the authored
end, then disappear. Disposed views and resource leases return to zero; browser
errors are empty. PNGs and `gpu.json` are under `.runtime/reviews/dimension-door/`.
Opening, entry, emergence and settled captures were visually inspected. Typecheck
passes. These are native scene/phase checks, not a byte-for-byte Pygame body oracle
or a hardware performance claim.

## Ground-hatch mask and native input boundary

`tests/portal-hatch-capture.py` executes unchanged original
`portal_scenarios.portal_history` for `hatch-walk` and `hatch-open`, then uses the
original projection and encoder. Both real native transfers commit `[3,2]` to
`[17,2]`. The traveler receives both endpoints, the departure witness receives
only the entrance, and the arrival witness receives only the exit. The original
opening delay and already-open timing are preserved. These six native views
are not repackaged as an SDK recording or added to the Studio case index.

`tests/portal-hatch.browser.mjs` exercises the shared production actor renderer
with these inputs: 48 samples across four quarters, two zooms, two original
programs and forward/backward descent samples. Disabling only the front mask
changes visible body pixels beyond the aperture. Repeated draws, restoring the
actual mask and all eight backward seeks reproduce pixels exactly; arrival has
no front mask. Disposal returns views and resource leases to zero; errors are
empty. Evidence is in `.runtime/reviews/ground-hatch/`.

`tests/portal-hatch-reference.py` applies the unchanged original
`clip_portal_bodies` to the production-rendered baseline body, isolating the
coverage operation. All 24 samples at native portal pixel size match exactly
in alpha and premultiplied RGBA. At half size, Pygame's nearest resize and Pixi's
pixel-center nearest sampling select different source-pixel phases. The largest
residual affects 77 pixels and reaches 255 alpha bytes at the edge. The lowest
alpha intersection-over-union is 83.54% in the small remaining body near
disappearance.
Those half-scale samples are diagnostic, not a pixel-parity acceptance claim.
The mask stays aligned with the visible hatch; no offset or second raster path
was introduced to imitate the other resizer. This oracle isolates the mask,
not complete Pygame character rendering.

SDK hatch acceptance remains blocked at supported encounter setup:
`ServerConfig`/`EncounterRecipe` expose a catalog battlefield and roster, but
the available public battlefield builders do not materialize a portal and the
configuration has no portal placement option. The hatch ground-hardware builder
creates its passive body, not the portal payload/control. No custom backend
setup, scenario registry patch or invented transfer was added. Flight, window
and other unexercised movement families remain outside this acceptance.
