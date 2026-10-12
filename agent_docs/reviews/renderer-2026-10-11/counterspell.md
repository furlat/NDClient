# Native Counterspell — canceled Fireball and Finger of Death

11 October 2026. N2 reaction grouping and N3 original interruption media.

The unchanged native server produced three SDK records. Sequence 2 contains the automatic successful Counterspell followed by the spent, canceled Fireball. Its exact handler attribution links the two lineages even though `reaction.triggered_lineage_uuid` is null. The client uses that disclosed link; it does not join events by spell name or actor proximity. Capture configuration, native choices, preview, receipt and provenance are in `.runtime/private/counterspell/` and `.runtime/recordings/counterspell/`.

The old client discarded every canceled spell before compiling its attempt. The compiler now preserves the original body/prepare/travel prefix up to the authored interruption rule. A spent projectile stops halfway through its original flight; clipping its lifetime does not increase its source animation or travel speed. There is no destination impact or invented damage. Reaction release and interruption coincide at 871.597 ms in this native case. The source actor and reactor face each other and their gestures overlap.

The reaction uses the original `Special1` context, `Magic3` hand sheet, per-camera ring and 500 ms dissipation mask. The carrier remains at its last logical pre-interruption sample while the mask advances. Mask coordinates refer to the original full image and account for both carrier and mask crops. The existing positive-alpha coverage filter draws it on an ordinary Pixi Sprite; no extra renderer or shader route was added. Contrary to an earlier preliminary description, original `media_coverage.py` uses `pygame.transform.scale`, not `smoothscale`; mask sampling remains nearest.

Grouping changes presentation scheduling only. At each displayed milestone the client reduces due facts in native lineage/source order. Each native event appears once, final state equals native reduction, and backward seek returns the same state/pose. Unconnected reaction families report their missing timing instead of silently overlapping unrelated tracks.

Validation:

- `counterspell.test.ts` passes alongside Globe, weapon-trail, cast-routing and ordinary action regressions; typecheck passes.
- `counterspell.browser.mjs`: 16 production samples, four quarters × attempt/dissipation/late/completion, with an explicit directional review light. Disabling only the mask changes actual pixels; restoring it and repeating rendering gives zero differing channels. No browser errors, prepared views or resource leases remain.
- Attempt, dissipation and reverse-camera late screenshots were inspected. Evidence is in `.runtime/reviews/counterspell/{gpu.json,q0-attempt.png,q0-dissipation.png,q2-late.png}`.
- Independent review checked native grouping, state/facing and original mask ownership: `.runtime/reviews/counterspell/group-review.json`.

## Finger of Death cancellation profile

The focused `finger-counterspell` case contains three exact SDK records. Supported native setup uses two original level-13 generic casters, the Finger spell grant and Counterspell behavior grant. Discovery identifies the defender at [9,7]; preview permits that exact creature, and committed declared targets match it. The native matching level-7 slot produces automatic successful Counterspell. No dice/outcome or event overrides were used. Capture provenance is `.runtime/recordings/finger-counterspell/capture-notes.json`; the case is listed in Studio.

The consumer now uses the original `cancellationMedia` cutoff offset, two cameo tracks, reaction point by facing, success bank by camera and reaction scale. The incoming cast holds through its original 1,275 ms cutoff; the two cameo layers then sample original frames 28–103 for 2,375 ms. Original `interrupt_sample` disables delivery, and `animation_draw.py` gates both normal hand media and directed drawing on that flag. Consequently this canceled case preserves its body/cast-accent prefix and then cameo, without emitting the normal darkness mesh or recipient contact/damage. The 500 ms ring uses the profile's world point rather than a guessed body anchor.

`counterspell.test.ts` passes both native Fireball and Finger cases, including source frames, cutoff, no recipient damage, native final state and deterministic backward seek. `counterspell.browser.mjs finger-counterspell` passes 16 full native scene samples (four cameras × attempt/early/late/completion), with actual media contributions, ordinary Sprite ownership, exact restore/repeat, and zero errors or remaining resource leases/views. Early and late scene/source captures were inspected.

The separate original-source oracle calls unchanged `stationary_media_draw_commands` and `reaction_media_draw_commands` for 16 isolated samples (four cameras × two zooms × early/late). This is a rendering comparison, not substitute native gameplay. Raw silhouette IoU is 89.28–100%; RGB mean error is 0.056–18.26/255, maximum 238. The measured registration explains fractional-size differences: at source scale 1.5, a 54-pixel crop spans 81 continuous pixels, while original rounded edges 468.5→468 and 549.5→550 produce an 82-pixel SDL resize. Pixi retains the continuous Sprite transform. The separate one-pixel-neighbour diagnostic has mean colour error 0.056–0.390/255; it does not replace the raw comparison or establish byte parity. No image shift, source rescale or alternate raster path was added. Evidence is `.runtime/reviews/finger-counterspell/{gpu,reference,sampling-diagnostic}.json`; the repeatable oracle is `tests/finger-cancellation-reference.py`.

These checks establish the two recorded automatic-success cases. Failed checks, nested/lethal reactions and interrupted arcs remain separate work. Software WebGL evidence makes no hardware-performance claim; this does not complete N2/N3.
