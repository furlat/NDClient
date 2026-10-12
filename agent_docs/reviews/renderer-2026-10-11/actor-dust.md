# Native actor Disintegrate retirement

The shared presentation compiler retains the witnessed body immediately before an actual `LifeFact` with `remains_disposition: disintegrated`. Gameplay state commits death at impact. The ordinary actor stops drawing and picking; its finite retained source becomes dust through the existing body compositor and ordinary Pixi Sprite/filter path. No backend, SDK, source artwork or recorded packet changed.

## Input and source ownership

The Studio case `/recordings/actor-disintegration/case.json` contains eight original SDK packets, each compared byte-for-byte with the private server spool. Supported ServerConfig uses the original generic level-13 caster, its Disintegrate grant, native Gloomplate and the existing bright open-floor battlefield. Gloomplate saves against the first actual cast. After both actual turns end, the second cast applies 86 Force damage and emits the native disintegrated life fact. No hit points, saving throw or outcomes were edited.

Original `body_presentation.py` supplies the immediately preceding presented body, CRC32 of the life-event UUID and the exact preserved-equipment exclusion. `animation_draw.py` retains the pose's complete body image and treats the shadow separately. `body_effects.py::silhouette_dust` and `reveal_body` supply the particle and shadow laws.

The client freezes source frames, prior appearance/material samples, pose registration, facing, scale and alpha. Retained rest poses, witnessed context, condition lifetimes and the canonical start reach the compiler before this sample is resolved. A life event at time zero samples the before-state. Fixed rigs split their ground shadow from the combined body; the body keeps its authored accent and pose layers. Preserved item UUIDs are excluded; actual item facts retain gameplay ownership. Existing item attachment consumption also receives the finite effect sources.

Dust operates once on the composed native body image, followed by the existing fixed 2× cleanEdge stage. It never emits particles per separately upscaled body part. The shadow uses the original source-pixel dissolve without particles. Padded display registration leaves source material and receiving coordinates consistent. Zoom and pan do not change source targets.

## Verification

- `tests/actor-dust.test.ts`: actual contact/life commit, finite 2500 ms retirement, four camera source registrations, no ordinary Die/corpse/picking contribution, original event commits once, final native prefix and rewind — pass. The initial test failed because no actor dust track existed.
- `tests/actor-dust.browser.mjs`: 20 native production samples across four quarters; ordinary Sprite output, no hit entry, no remaining actor after retirement, real directional receiving source, one warm/zoom scene pass, unchanged dust bytes across zoom, exact rewind/context restore, zero remaining views/leases/errors — pass. The scene screenshot was visually inspected.
- `tests/actor-dust-reference.py`: the unchanged original Pygame function applied to the actual composed native input. All 20 comparisons have 100% silhouette overlap and exact alpha; mean PMA error 0–0.174/255, maximum below 0.5/255 from byte rounding. This checks the dust operator, not an independently running complete Pygame scene. Raw GPU bytes avoid Pixi's PNG alpha-conversion ambiguity.
- Shared integration: all 61 Node tests pass in 18.15 s after the compiler/context change; typecheck passes. Existing corpse and whole-prop tests pass.

Independent source review corrected the precontact registration, prior condition context, zero-time life event and retained accent semantics. The native case has no preserved equipment; that exclusion is source-reviewed rather than claimed as a captured equipment case. Original Blur/absence/live-copy capabilities still have their own unfinished global consumers. This slice does not claim those missing operators, hardware GPU performance or full N0–N5 completion.

Evidence: `.runtime/reviews/actor-dust/{evidence,reference}.json`, raw source/output samples and `q0-450-scene.png`.
