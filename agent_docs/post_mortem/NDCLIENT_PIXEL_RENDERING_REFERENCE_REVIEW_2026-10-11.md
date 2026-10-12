# Pixel rendering reference review — 11 October 2026

Scope: the current floor, character scaling and blood complaints; the requested comparison with Pixi, NeuroClient and the supplied Unity project; and the cleanEdge experiment. This is an evidence report, not a replacement implementation plan. Engine, Pygame, NeuroClient, Unity and original artwork were read-only. The user liked the cleanEdge character comparison and asked whether it can run as a shader. No library-wide conversion or production cleanEdge implementation has been made.

## cleanEdge: what was actually compared

The experiment used [torcado's original cleanEdge shader and demo](https://torcado.com/cleanEdge/), with the actual assembled Sorcerer and Fighter source frames. It compared nearest enlargement at 2× against cleanEdge enlargement at 2× over the same native floor artwork. Character placement and proportions were identical. The improved contours therefore do not establish a different character-to-environment size ratio.

[Character comparison](../.runtime/reviews/pixel-scaling/characters-cleanedge-comparison.png).

cleanEdge can run on the GPU; offline preprocessing of all assets is unnecessary. For this specific 2× appearance, the recommended integration to test is native character composition, a cleanEdge GPU pass into a 2× RenderTexture, and reuse of that result until the source frame or appearance changes. Pixi would subsequently transform that texture with the camera. A moving camera alone would not invalidate the character image. Animated appearance operations may require more frequent updates than the body animation.

This is different from evaluating cleanEdge directly at every screen fragment on every redraw. That live approach can respond to arbitrary enlargement, but repeats neighbourhood sampling. Its cost has not been measured here. A filter on the already combined world would incorrectly include floor/wall neighbours. A normal post-zoom actor filter also receives rasterized output rather than the native frame used in the comparison. [Pixi's filter documentation](https://pixijs.com/8.x/guides/components/filters) explains its input-render-target model.

Integration remains to be implemented and verified: ordinary modular actors are currently separate draw inputs. `body-composition.ts` already creates native frame targets and tracks appearance changes for `bodyMaterials`, but does not currently provide that reusable composition for every ordinary actor. Preserve physical parts, separately controlled effects, pivots, sockets, source-frame boundaries and premultiplied alpha. Enlarging only colour while accidentally reinterpreting ownership/depth/component coordinates would be incorrect. A 2× result has four times the raster area; resource reuse and actual GPU cost require verification before rollout.

## Floor reduction remains provisional

The half-resolution environment conversion initially used nearest sampling. In the inspected `ground-d1-e.png`, a diagnostic count found native brown grout in 223 source 2×2 blocks; nearest retained it in only 92. That accounts for substantial missing fine detail before Pixi draws the floor.

The worker currently uses a one-time averaged colour reduction, while GPU texture sampling remains nearest. Originals and numeric geometry remain unchanged. Independent 2×2 premultiplied colour/alpha comparisons pass for four views; a negative control using the old nearest reduction fails. This verifies the conversion, not aesthetic acceptance: the user found the averaged result blurry.

Mapping the averaged result back to the original 131 opaque RGB colours changed 415 occupied reduced pixels but did not restore the lost line definition. It was not added to production. cleanEdge at half size also retained gaps; its enlargement from native pixels produced the useful result. The half-resolution environment conversion is therefore still a provisional policy under review, not a completed floor-art repair.

## Unity: actual playable scene, native artwork

Project: `C:/Users/tommaso/Documents/UnityProjects/SmallscaleExplore`. The inspected playable source is `Assets/SmallScaleInt/Fantasy kingdom Tileset/Example scene/Example scene.unity`, not the mostly empty `SampleScene` named in the build list.

| Input in that scene | Pixels per Unity unit | Object/ancestor scale | Consequence |
| --- | ---: | ---: | --- |
| Player animation sheets, 128×128 frames | 100 | 1 | One source pixel spans 0.01 world units |
| Dominant ground artwork | 127 | 1 | One source pixel spans 1/127 world units |
| Isometric grid | — | 1 | Cell spacing 1×0.5 world units |

Thus a character source pixel is typically **1.27×** an environment source pixel. Common camera zoom preserves that ratio. The scene does not use character ×2, environment ×0.5, or cleanEdge. This is reference evidence, not authorization to change NDClient's proportions.

The ground PNG's 256×256 image extent includes transparent margins. `Ground A1_E` has 128 visible pixels across: its visible width is 128/127 = 1.007874 world units. A whole-image comparison against a 128px character frame would be misleading. A representative playable Idle frame has a 40px visible body height, comparable to the current modular body source.

Evidence locations relative to the Unity project:

- `Example scene.unity`: Player root transform at 1142713 (scale 1, no parent); actual Animator at 1146357; Grid at 415386; Ground sprite reference at 856351; main camera at 474003; camera settings at 474099.
- `Characters/player1/Idle.png.meta:783`: 100 PPU; frame rectangle at 2481 is 128×128. All 24 player sheets use 100 PPU and Point filtering. Animation clips contain no scale curves.
- `Characters/player1/Animation Clips/Idle/Idle_S.anim:24`: valid runtime sprite reference; this animator chain, rather than stale initial serialized sprite references, establishes the rendered source.
- `Environment/Sprites/Ground A1_E.png.meta:54` and `Ground A2_N.png.meta:54`: 127 PPU. All 156 used Ground sprites use 127; other layers include small numbers at 126/128.

Those asset paths are under `Assets/SmallScaleInt/Fantasy kingdom Tileset/`. Four inspected Unity images (Ground A1_E, A2_N, J1_S and Tree A1_N) match retained NDClient library originals exactly in RGBA pixels.

Character and environment imports use Point filtering, no mipmaps and no active compression override. Main camera orthographic size is 2, continuous zoom limits 1–3, pixel snapping disabled. URP render scale is 1. Core player/ground/wall/object rendering uses Sprite-Unlit-Default with an ordinary texture sample. There are explicit shadow tilemaps; custom water/foam shaders are not general sprite upscalers. Postprocessing is enabled, including bloom, grain, vignette and chromatic aberration, so the final picture is not untouched point-sampled colour. Inspection was static; no Unity runtime/seam acceptance is claimed.

## Pixi and NeuroClient review

**Confirmed and fixed: stale ordinary Sprite frames.** `composition.ts` mutated a Texture frame and called only `updateUvs()`, without opting into dynamic texture notifications. The selected frame changed while a stationary Sprite could retain its previous displayed pixels. Texture construction now uses `dynamic: true`, and frame changes call `update()`.

`tests/sprite-animation.browser.mjs` verifies frame 1/7/0 through production sampling with a stationary camera, visible changed pixels, exact rewind, agreement with explicit Pixi invalidation, zero new sources and no browser errors. `tests/retained-actor-sampling.browser.mjs` also passes: frame 1→8 changes pixels, matches fresh preparation, preserves airborne body versus grounded shadow, and rewinds exactly. TypeScript checking passes. This does not change Studio's explicit pause at recording completion.

**Confirmed, still open: ordinary tint differs between paths.** Pixi Sprite tint multiplies encoded colour channels; the material path currently multiplies in linear colour. White-tint tests cannot expose this. A nonwhite `[128,96,64]` comparison, with lighting disabled and neutral material treatment, found up to 4/255 body and 8/255 chest differences at tested zooms. No tint correction was made in this review.

**Observed structure, unmeasured cost:** preparation creates material resources even for occurrences that eventually display as ordinary Sprites. This may be avoidable work, but the review did not establish its contribution to the reported GPU utilization. No broad renderer rewrite is justified by that observation alone.

Current premultiplied image handling, numeric raw sampling and frame-edge clamping did not reveal a general corruption bug. Warm static-floor cache checks showed zero new sources/uploads; cache/direct checks establish consistency, not original-art fidelity. Old NeuroClient uses AnimatedSprite frames and scoped colour filters, but its floor diamonds are Graphics geometry, not evidence of raster-floor quality.

Primary references: [Pixi Texture](https://pixijs.download/v8.22.0/docs/rendering.Texture.html), [Sprite update subscription](https://raw.githubusercontent.com/pixijs/pixijs/v8.22.0/src/scene/sprite/Sprite.ts), [Texture implementation](https://raw.githubusercontent.com/pixijs/pixijs/v8.22.0/src/rendering/renderers/shared/texture/Texture.ts), [Pixi tilemap frame clamping](https://raw.githubusercontent.com/pixijs-userland/tilemap/main/src/gl_tilemap.ts), [cacheAsTexture](https://pixijs.com/8.x/guides/components/scene-objects/container/cache-as-texture).

## Blood: separate unresolved appearance comparison

Both clients use the same material-specific procedural templates and server residue ellipses; this is not a wrong blood PNG selection. Actual density readback agrees closely with the old kernel equations (RMSE at most 0.00276); no gross transpose or stretch was identified.

There is a concrete sampling difference: Pygame shades the complete liquid appearance on a 64×64 source grid (`game_obsolete/surface_residue.py:232`) and projects that result. NDClient caches a 128×128 density field (`residue-fields.ts:9`) but evaluates appearance/noise in world/output samples (`residue-shader.ts:12`). This can alter grain and small silhouettes. It has not yet been corrected or proven to explain the full splat complaint. Template repetition also exists in Pygame; no arbitrary randomization or ellipse changes were introduced.
