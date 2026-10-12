# Banishment departure and witnessed return

The existing `absenceEcho` recipe now consumes a witnessed departure body sample
and a separately witnessed return. Both use the same native body composition,
scoped Pixi filters, fixed character cleanEdge and ordinary Sprite drawing path
as gameplay and Studio. The echo adds no actor, shadow, legal target or hit region.
Native absence, visibility and target legality remain unchanged.

The original `absence_media.py`, `condition_media_lifetime.py` and
`body_effects.absence_silhouette` supply the phase clocks, source-cell dissolution,
palette, current-contact visibility gate and known-edge requirements. Departure
captures the preceding displayed pose once. A return requires actual
`entity_entered` evidence and the committed absent-to-present transition. Cold
acquisition cannot invent either witnessed edge. The ordinary returned actor is
prepared concurrently, remains hidden until the original echo finishes, and then
resumes living Idle with its ordinary shadow.

The portal uses the original back/front media and `recipe.scale` multiplied by
the captured visual body size. Visual inspection caught an additional actor-rig
conversion in the first implementation: the original portal function does not
apply that factor. It was removed and the original scale is now asserted. No
source artwork, recipe value or world registration was changed. The failed large
portal screenshot remains beside the final evidence.

## Native evidence

`.runtime/recordings/absence-echo/case.json` preserves nine exact SDK packets from
the retained server spool. The original level-9 caster's first Banishment saves at
sequence 2; the second applies at 7, and native Drop Concentration returns the
recipient at 8. Supported native character setup was used without forced rolls,
condition edits or changed outcomes. A preceding level-7 attempt could not afford
a second cast; its refusal remains private and was not turned into a fake case.
Both private capture hosts were stopped after capture.

`tests/condition-absence.test.ts` passes canonical-state equality, departure and
return ownership, four-quarter registration, current-contact gating, cold-base
behavior, phase expiry and portal scale. The focused held-pose, Blur, Mirror,
feedback and actor-dust regressions and TypeScript pass.

`tests/condition-absence.browser.mjs` passes 28 production views across all four
quarters: three departure times and four return times, including finished Idle.
The frozen body remains unchanged while dissolution advances. The portal keeps
its original finite interval, the returned ordinary body is hidden only during
the echo, and source selection never adds interactive duplicate bodies.
Explicit directional lighting uses the same receiver path.

The 28 source outputs match the unmodified original Pygame operator with exact
alpha and 100% occupied-pixel overlap. Maximum premultiplied RGB rounding error
is 0.4942/255 and mean error is at most 0.2309/255. Rewind and graphics-context
restoration are exact, restoration performs zero new decodes, and camera zoom
changes no prepared source pixels and takes one world pass. Disposal leaves zero
views and leases; browser errors are empty. Corrected departure, return and Idle
screenshots were inspected. Evidence: `.runtime/reviews/absence/` and its original
comparison `reference.json`.

Independent review then caught a live-start discrepancy: the first capture used
the canonical recording clock for an ambient Idle frame. The snapshot now retains
its existing `PresentationDate`; the normal actor and body samplers resolve that
one capture against actual playback starts. It does not advance with the echo.
The source registration is applied once by the normal actor sampler.

The focused q0 follow-up at `.runtime/reviews/absence-delayed-source/` passes an
actual 375 ms start delay. It selects a different Idle frame, matches the ordinary
pre-contact body pixels exactly at that actual date, stays unchanged while the
echo advances 200 ms, reconstructs identical pixels from a cold worker view, and
returns exactly to the canonical sample on rewind. The original Pygame comparison
and context/zoom/disposal checks still pass. Studio also passes the actual
Mirror/Blur/absence source-link, visible operation row, folded physical parts and
production-thumbnail checks in the body-presentation review.

## Remaining scope

This accepts the captured Banishment departure and actual concentration-removal
return. It does not establish every absence combination, an unseen destination,
native sensory behavior after death, or hardware performance. The
complete N0–N5 plan remains active.
