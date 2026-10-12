# Fireball: rule, admitted area, bank dimensions and final texture policy

Read-only diagnostic, 11 October 2026, supporting [renderer v3 §3.4](../../NDCLIENT_PIXI_RENDERER_PLAN_2026-10-11_v3.md#34-spell-dimensions-under-the-final-texture-policy). No product code, authored data, backend or artwork change. Diagnostic scripts and JSON are retained under `.runtime/reviews/renderer-audit-20261011/`: `ndclient-fireball-scale-audit.mjs`, `ndclient-fireball-scale-current.json`, `fireball-bank-scale.mjs` and `fireball-bank-scale-samples.json`. Source lines below are at audit time.

## Comparison with the accepted lighting example

The preserved source is `/home/tommaso/Dev/ndclient-reference/2026-10-08/fireball-proof/`, with original v4 artwork under `/home/tommaso/Dev/neurodragon_art/sources/fireball-single-view-24fps-v4/`. The old engine `.runtime/ndclient-fireball-proof/` location no longer exists. Reference `renderer.js:35,48–50` uses the manifest calibration and raw crop dimensions without another occurrence multiplier. `shaders.js:68` applies camera zoom to those source-pixel offsets; `scene.js:40` projects a tile diamond to 128×64 before zoom. The two-room proof used camera zoom 0.8 (`main.js:26`).

The production session/compiler was run on actual Fireball operation 3, then `mediaOccurrences` sampled its impact. It emits impact `scale: 2` and a doubled `sourceToLocal` matrix for both near/far contributions. Ordinary PNG travel is separately `scale: 1.2`. This diagnostic uses the actual compiler, not a handwritten reproduction of it.

At frame 21, with common camera magnification normalized so a tile diamond is 128×64:

| Source | Near/far crop union in source pixels | Drawn dimensions | Width / tile-diamond width |
| --- | ---: | ---: | ---: |
| Accepted lighting proof v4, scale 1 | 848×654 | 848×654 | 6.625 |
| Current project capture, current scale 2 | 793×633 | 1586×1266 | 12.391 |
| Current project capture, calibrated scale 1 | 793×633 | 793×633 | 6.195 |

The current frame is 1.87× wider and 1.94× taller than the corresponding proof crop, because the extra ×2 acts on a slightly different source capture. Both have 46 frames at 24 FPS, a 1536×1536 capture and pivot (768,768), and the same calibration. Their images are not identical. These are rectangular crop extents, not damage diameters; frame 21 is in the smoke tail. The current camera's `zoom * .5` is common to terrain and effects and does not remove the relative error.

## Gameplay evidence

- Official SRD/current spell reference: Fireball has a **20-foot-radius sphere**, not a 20-foot diameter. [D&D Beyond Fireball](https://www.dndbeyond.com/spells/2618887-fireball), also [SRD 5.1 Fireball](https://www.dndbeyond.com/spells/2102-fireball).
- Engine `dnd/spells/evocation.py:900–908`: `Fireball.model_post_init` constructs `Sphere(radius_feet=20, propagation="connected")`.
- Engine `dnd/core/aoe.py:242–258`: Sphere returns `radius_feet // 5` cells and `circle_positions(..., include_center=True)`. `dnd/core/geometry.py:41–82` enumerates the filled squared-distance circle. One horizontal grid unit is five feet.
- Actual client recording `.runtime/recordings/fireball/000003.json`, `lineages[0].root.fact`: `area_geometry={shape:"sphere",center:[10,7],radius_feet:20}` and **49 `resolved_area_positions`**, exactly the full disk of integer cell centres `(x-10)^2+(z-7)^2 <= 16`. Extrema x=6..14, z=3..11; maximum centre distance=4. Suppressions are empty in this packet.
- These facts certify the current two-dimensional native ground footprint. The engine Sphere uses cell positions; this diagnostic does not claim a separately tested vertical 20-foot volume-damage boundary. No backend extension is part of this task.

## Current extra scale and valid calibration

- `src/presentation/spells.ts:61` computes `128 / rigInfo.TILE_W`; `authoring/catalog/rig.json:254` supplies 64. `spells.ts:159` multiplies projectile phase scale by that factor.
- `authoring/spells/spell.fireball.json:628–633` sets impact scale 1. The resulting impact MediaTrack therefore has scale 2.
- `tools/import_vfx_authoring.py:120–123,192` explicitly set migrated paired impact scale to 1 because the bank owns pixel/world calibration. The phase value overrides the projectile's global fallback; it is not multiplied by that global value.
- `src/presentation/media.ts:125–149` applies that occurrence scale to both image and geometry. Their mutual alignment can pass while both have the wrong world extent.
- `authoring/media/banks/core-fireball.json` already supplies `source_to_host=diag(2/3,sqrt(6)/3,2/3)`. With host projection `(64(X-Z),32(X+Z)-64Y)`, this equals the bank's capture-relative projection `(42.6667(x-z),21.3333(x+z)-52.2558y)`. It is a source-pixel/world registration, not a radius declaration.
- The accepted source handoff `dnd_engine/agent_docs/FIREBALL_SINGLE_VIEW_PIXI_HANDOFF_2026-10-08.md:77–93` explicitly identifies source coordinates×2/3 as five-foot grid units. Preserve that calibration. The source scene's name `Fireball20ftGround` is not an independently measured radius; its override only flattens/repositions the shockwave node.
- Removing the duplicate legacy 2× conversion restores the delivered calibration. It alone cannot establish that the evolving artwork communicates the native four-cell radius correctly.

## All media scale producers and current reach

Parsed current authoring contains **392 paired definitions and 193 banks**. Only Fireball supplies explicit `source_to_host`; the others derive registration from capture matrices in `media.ts:135–138`. Sixteen spell drafts reference 33 distinct paired definitions; spatial bindings reference 168. These sets can overlap and include consumers not yet connected.

`media.ts:174` is the only production caller of `pairedImage`. The scale arrives from the following producers; multiplying both image registration and geometry by the same occurrence scale is correct parallel treatment, not two successive enlargements. Fireball's invalid extra operand enters before that function.

| Producer | Existing scale calculation | Current paired reach / disposition |
| --- | --- | --- |
| `spells.ts:151,159` | `(phase.scale ?? projectile.scale) × 128/TILE_W` | Fireball, Sleep, Ice Knife and Ice Knife burst. Fireball duplication is independently confirmed. Verify source extent/units for the others. Fireball travel is ordinary PNG at scale 1.2 and retains its conversion. |
| `media.ts:212`, through `spell-media.ts:60,84` | `row.scale × factor × optionalActorScale`, with factor 2 | Burning Hands, Cone of Cold, Thunderwave, Sunbeam and its strike draft, Color Spray, Ice Storm, Sacred Flame, Sunburst, Shatter, Flame Strike, Gust of Wind. Inherited authored scales need source-unit verification, not blanket halving. |
| `spatial-media.ts:99` | `binding.scale × layer.scale × nativeRadiusRatio × 2` | Material fire, burning Web, Wall of Fire modules; Cloudkill, Darkness, Fog Cloud, Gust of Wind, Ice Storm, Incendiary Cloud, Insect Plague, Sleet Storm, Stinking Cloud. Includes application/hold/removal. Preserve the native-radius ratio at line 55. |
| `actions.ts:97,104`; `action-media.ts:31` | Shared authored row/actor-strip conversion, factor 2 | No current paired references. Strips explicitly require strip storage. |
| `movement-media.ts:20`; `movement.ts:78,115` | `row.scale × 2 × actorScale` | No current paired references. Keep ordinary jump/trail and rig-offset units. |
| `condition-media.ts:62` | `(media.scale ?? .5) × optionalActorScale × 2` | No current paired application/removal/mask references. |
| `item-effects.ts:58` | Binding scale × equipped-body registration scale or factor 2 | No current paired attachment references; Continual Flame artwork is ordinary. |
| `entity-lifecycle.ts:38` | Shared authored compiler with factor 1 plus lifecycle/appearance scale | No current paired references. A global division inside the shared compiler would also break callers without the legacy factor. |
| `orbit-media.ts:43`; `portal-media.ts:27` | Explicit `sizePixels/160`; authored `art.scale` | Neither adds the rig factor 2; neither currently references paired definitions. |
| `finite-media.ts:32`; `effects.ts:37` | Forward existing media tracks | No new scale conversion. |

Frigid Air, Wind Wall and Wall of Thorns are authored paired families but skipped by `spatial-media.ts:68`, as are Ice Storm's two recipient-track spatial layers. Ice/stone construction authoring references 192 paired definitions with no runtime `construction_media` consumer yet. These are existing unconnected consumers, not demonstrated oversized drawings. Retain them in full-port coverage.

### Why storage kind alone cannot choose a correction

Representative arithmetic in current data:

| Source | Derived horizontal source-to-host factor | Authored multiplier | Product including legacy ×2 |
| --- | ---: | ---: | ---: |
| Fireball (explicit transform) | 2/3 | 1 | 4/3 — accepted proof uses 2/3 |
| Burning Hands / Thunderwave | .5 | 1 | 1 |
| Cone of Cold main planes | .67 | .7462686567 | 1 |
| Cone of Cold contact planes | .85 | .5882352941 | 1 |
| Ice Storm ground planes | .65 | .7692307692 | 1 |
| Sleet Storm | .35 | 1.4285714286 | 1 |
| Fog Cloud / Darkness | .5 | .5 | .5 |

These products are measured source arithmetic, not proof that every resulting world size is correct. The operands show inherited capture compensation. Removing ×2 everywhere would alter sources whose actual intended extent has not been independently established. Trace source bindings and native areas; correct confirmed duplicate unit conversions through the common functions. Do not add spell-name exceptions, halve all VFX, or change authored JSON to conceal the Fireball defect.

Rig/socket conversion remains separate (`media.ts:25,53,214`, `spells.ts:152`); the image's own emission-point offset at `media.ts:56` follows its corrected image scale. Geometry and inverse-transpose normals share the occurrence transform; no separate inverse-scale defect was found. Incorrect world positions affect receiver distance/attenuation (`surface-shaders.ts:377,401`). Fireball emitter positions/range already use world units and are not multiplied by track scale (`composition.ts:716–717`); halving them would introduce a new error. Source-pixel material coordinates, palette/noise domains and numeric companions retain their source units.

## Geometry sample measurement: method and limits

All 46 installed frames, both near/far layers, were decoded directly from their gzip RGBA8 appearance and geometry packets. A sample is admitted only when its RG16BE depth code is nonzero **and at least one appearance RGBA byte is nonzero**. There is no alpha cutoff, luminance threshold, trimming or opacity weighting. Thus faint samples and valid RGB emission with alpha zero are included.

For each admitted pixel:

1. Use crop origin + pixel coordinate + 0.5.
2. Decode depth as `depth_min + (code-1)*(depth_max-depth_min)/65534`.
3. Apply that frame's `capture_pixels_depth_to_source_world` matrix and the bank's `source_to_host`, at occurrence scale 1.
4. Record horizontal radius `hypot(hostX,hostZ)` and height, with pixel-count quantiles. Near/far samples are separate observations, not unique world points.

Reported height bands (`<0`, `0..0.125`, `.125..0.25`, `.25..0.5`, `.5..1`, `>1`) are diagnostic slices in host units, **not authored ground masks or gameplay boundaries**. The delivered geometry includes billboard/card surfaces and qualified continuation/proxy samples. Therefore distributions are neither physical volume mass nor an exact surface of the SRD sphere.

Examples from the scale-1 samples:

| Frame / elapsed from impact | Diagnostic low-height radius maximum, 0..0.25 host units | Meaning |
|---|---:|---|
| 4 / 166.7ms | 3.185 cells | Early burst has not filled the eventual area. |
| 8 / 333.3ms | 4.678 cells | Some admitted low samples extend beyond four cells. |
| 12 / 500ms | 3.263 cells | Different parts/timing; not monotonic sphere growth. |
| 20 / 833.3ms | 4.348 cells | Tail/cloud expands independently of hit selection. |
| 45 / 1875ms | 6.220 cells | Late artwork is not the damage boundary. |

The whole sample set reaches farther than those low slices; it includes upper smoke and proxies. Current occurrence scale 2 doubles all these distances. Neither full crop width, the maximum sample nor a chosen percentile proves or defines a desired 20-foot boundary. The source timing metadata is ignition [0,4), burst [4,12), tail [12,46).

The emitter's authored range reaches **9 host units**, separate from damage radius 4. `src/rendering/composition.ts:708–717` samples that light curve independently; its intensity/range and local position are not a hit-region definition. Do not scale the light to force agreement with a crop or smoke edge.

## Minimum acceptance under renderer v3

- Keep the actual admitted footprint and source centre as the independent reference; compare the visually significant main burst over that footprint in the actual scene. Retain separate semantics for propagation/suppression, artistic smoke/sparks and cosmetic light falloff.
- Verify one declared source-to-world conversion, then any explicit authored occurrence size, in both colour and geometry. Check more than one quarter and zoom. Avoid a Fireball-name branch or halving JSON to cancel a shared conversion defect.
- Use final texture policy: native environment detail and fixed 2× character-source cleanEdge with unchanged logical dimensions; common viewport transform preserves grid spacing, world contacts and native reach. Texture resolution never multiplies world size.
- Do not infer a new artistic scale from crop width or one geometry outlier. If scale-1 main-burst appearance still fails the native-area comparison, report that measured mismatch for discussion. No new backend radius, damage clipping or asset rewrite is implied.

This is a scale/area diagnostic and plan review, not final visual acceptance of Fireball.

Targeted anti-slop/rendering and anti-OOP/ECS reviews passed after narrowing the correction to proven source-unit mismatches and using the actual SDK field `resolved_area_positions`. Final texture-policy visual checks remain implementation acceptance.


## Renderer v3 production verification — 11 October

The duplicate source-unit conversion is now corrected by `mediaScale` in the shared media consumer. A bank with explicit `source_to_host` uses the authored occurrence scale directly; inherited matrix-derived banks retain their legacy source conversion. Projectile preparation/impact, authored spell rows and retained spatial rows call that same function. Ordinary sprite travel, rig/socket offsets, movement/condition/item source units, and the native spatial-radius ratio retain their existing meanings. No spell-name branch or compensating JSON scale was added.

Fresh production captures are in `.runtime/reviews/renderer-v3-final/`: `fireball.json`, the 11 corresponding image/area-overlay PNGs, and the existing diagnostic's updated `fireball.mjs`. They use the actual `/recordings/fireball/case.json`, compiled operation 3, native centre `[10,7]`, `area_geometry.radius_feet = 20`, and all 49 received `resolved_area_positions`. Frame 8 is shown in all four quarters at camera zoom 1 and 1.6; quarter 0 also shows frames 4, 20 and 45. Every sample has impact scale 1 and seven character targets at logical 128×128 / physical 256×256. Environment decoding remains native resolution. Browser errors are empty. Extraction explicitly supplies an opaque dark background, preserving the paired-radiance display convention; a transparent extraction is not evidence for compositing this radiance over arbitrary later backgrounds.

The preserved proof was also rendered with its unmodified `renderer.js`, `scene.js`, `frames.js`, shaders and original v4 packets. A diagnostic HTTP mapping served the retained files read-only from `/home/tommaso/Dev/ndclient-reference/2026-10-08/fireball-proof/` and `/home/tommaso/Dev/neurodragon_art/sources/fireball-single-view-24fps-v4/`; no reference source or artwork was edited. `proof.json` records eight frame-8 captures in all quarters at proof zoom .5/.8, matching the client's zoom 1/1.6 and tile dimensions 64×32 / 102.4×51.2 display pixels. The exact native footprint is translated to the proof origin solely as a comparison overlay. Proof lighting/bloom/receiving illumination were disabled for this size comparison. Its original walls remain visible. This is source/reference evidence, not native gameplay or acceptance of the client's wall interaction.

`equal-grid-z1.png` and `equal-grid-z1.6.png` compare all eight view/zoom pairs. Both use the same diagonal source-to-host calibration `(2/3, sqrt(2/3), 2/3)`. The current burst stays registered to the recorded centre without the rejected extra ×2. The two source revisions differ: frame-8 union crops are 666×382 in v4 and 702×391 in the current bank (ratios 1.054 and 1.024). These are source coverage bounds, not damage diameters. Visually the main burst occupies the interior of the same native footprint at the same grid magnification; smoke/sparks and light falloff are not clipped to that footprint. The comparison provides no basis for another artistic scale change.

This closes the previously missing final-policy, all-quarter/multiple-zoom, actual-area/equal-grid-proof comparison. It does not close Fireball/wall interaction, combined lifecycle/performance acceptance or the complete renderer/client plan. Positioned-light on/off evidence remains separately recorded in `renderer-final/positioned-light/`; the current captures additionally retain the emitter/time metadata. Production diagnostic draw counts are visible occurrence counts and source-pass counts, not hardware GPU profiling.
