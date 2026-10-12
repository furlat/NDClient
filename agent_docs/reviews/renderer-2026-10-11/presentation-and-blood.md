# NDClient presentation / ECS audit — 11 October 2026

Read-only code scan for the newly requested repair plan. This is evidence for planning, not implementation or visual acceptance. Engine/Pygame, SDK and original artwork remain read-only. Latest human policy supersedes the earlier half-resolution-environment experiment: native environment; source cleanEdge2x for characters only; distinct multiplication tint, explicit colour swap, and material filters; ordinary clothes use tint; Magic2 hand effects inherit their owning spell material. Preserve the functional pipeline and actual body/item materials.

## Confirmed findings for the plan

1. **Isolated layer materials have an admitted data owner but no consumer.** `StudioActorLayer.material` and `RigLayer.material` are `ConditionBodyRamp` in the animation schema/generated types. `spells.ts:95` and `attacks.ts:93` copy material onto the layer. `actors.ts:100–123` only resolves palette, itemMaterial and physical bodyMaterials; no runtime reader consumes actorLayer.material or actorEffect.material. Only whole-physical-body bindings reach `prepareBody`. Current authoring scan found zero non-null isolated layer.material assignments; that does not make the admitted capability disposable. The new Magic2 requirement must resolve the owning spell material and apply it only to the hand-effect source mask through the existing material operators. Do not apply it to weapon/clothes because the legacy slot happens to be named weaponGlow.

2. **Ordinary dropped item tint is lost.** `items.ts:16–26` supplies `part.tint` only to `itemMaterial`; since `item-material.ts:32` now returns undefined for ordinary unmodified equipment, the occurrence receives neither a material nor a tint. Equipped ordinary items still carry `layer.tint` through actors.ts:121. Restore the ground caller's tint semantics, with the same base-colour policy as its equipped representation. There are hundreds of non-white ground appearance tint inputs; this is not a theoretical schema-only field.

3. **An exact colour-swap family exists and is not consumed by NDClient.** 35 current `authoring/media/definitions/*.json` records contain non-null `paletteSwap {originalColors,targetColors,tolerance}`. Example `summoning.fey_spirit.arrival.ground`, tolerance 0, eight explicit pairs. `resolveMedia` retains it within source.asset but `mediaOccurrences` emits only track.tint/sourceColor and no swap. Repo runtime searches find no originalColors/targetColors/paletteSwap reader outside generated declarations. Pygame's `projectile_media.py:366` explicitly reads asset.paletteSwap and calls `spell_palette.replace_palette`, which copies the image and alters only matching visible source colours, preserving alpha and every unmatched colour. Preserve this family and validate whether each current selected storage is original or already baked before applying a swap twice. This is separate from `ProjectileSprite.paletteSwap`: Pygame explicitly rejected that per-instance path; do not conflate its coverage with the working per-asset path.

4. **Palette naming currently hides different operations.** `LayerColors.mode` admits tint/multiTint/paletteSwap/shaderUniform. 296 authored mode=paletteSwap occurrences and one mode=tint were counted in non-bank/non-schema inputs. `resolveCastLayer` always installs a PaletteTreatment ramp for auto sources; `effectiveLayerPalette` ignores mode, and actors suppress their tint. `surface-shaders.ts` PaletteTreatment selects colours by source brightness/tone range, gamma and optional noise, not explicit source→target equality. `SpriteOccurrence.colors`/multiTint has a renderer branch but no current producer found. Retain the legitimate legacy ramp as a material/filter; keep a distinct precise swap operation. Do not rename all historical modes or delete accepted palettes blindly.

5. **Explicit item effects must survive separation from base tint.** `itemMaterial` selects native unsuppressed item effects, targeted equipmentModifiers, priority, palette-generated HLS shades, saturation/brightness, glint and emission. It is not the same thing as ordinary clothes tint. Its `if(tint===0xffffff)` return precedes glint/brightness/saturation/emission construction: a supported neutral/white modifier can lose those independent operations. Audit real inputs before repair; do not erase these controls as a fix for base clothes colouring. Ground items currently classify every non-Off-hand category as weapon for modifier selection; preserve ownership by actual item role rather than broadening that fallback.

6. **Source/body/effect ownership remains partially slot-derived.** Explicit cast layers are excluded from bodyColour/bodyMaterials/flash with `!authored`; semantic role is present on StudioActorLayer. But `physicalBodySlots` includes weaponGlow and actor occurrences use role body for every non-shadow/non-effect slot. Clip-owned effect layers without authored_layers can still be classified as physical. Fixed rigs deliberately combine source C/B/S/E: their shadow/accent controls and overlap reconstruction must remain independent. Plan must specify the source-role/subject mapping once and reuse it in actor, material and Studio consumers without another executor.

## Colour fields mapped to current callers and concepts

| Current input / derived field | Actual caller and behaviour | Required concept / preservation |
|---|---|---|
| Native skin_tint/hair_tint/beard_tint; item equipment_layers.tint_rgb; RigLayer.tint | actorLayers → actors occurrence.tint; fixed components use componentLayers controls | Baseline multiplication tint; not a timed operation by itself. |
| Ground binding.tint and ground layers.tint_rgb | items → itemMaterial only; missing occurrence tint for ordinary items | Same baseline tint as equipped source. |
| StudioActorLayer.colors and elementColors/castPalettes | resolveCastRecipe/resolveCastLayer/effectiveLayerPalette → PaletteTreatment | Resolve spell ownership once. Separate explicit tint from ramp/material; Magic2 full material inherits owning spell. |
| PaletteTreatment.colors/gamma/noiseSheet/untinted | actors → occurrence.palette → shader palette mode 1 | Brightness/noise colour ramp material; not exact swap. Preserve authored noise and no-treatment overrides. |
| Asset.paletteSwap originalColors/targetColors/tolerance | Generated/retained asset; no current ND draw consumer; Pygame per-asset reader exists | Explicit colour swap. Unmapped pixels and alpha unchanged. Exact current tolerance=0 must stay exact. |
| ProjectileSprite.paletteSwap | Present schema; no ND consumer; old Pygame rejected this per-instance field | Record separate unresolved capability; do not silently substitute asset ramp. |
| SourcePalette.colors/isGray | actors/items resolve palette; itemMaterial consumes colors; renderer sourcePalette used only with occurrence.colors | Source matching/provenance data. Do not turn it into automatic recolouring of all clothing. isGray consumer absent in ND. |
| ItemMaterial original/target/glints/emission/alpha | itemMaterial → shader palette mode 3 and item emission/glint controls | Explicit item effect material with native membership/suppression. Preserve unmatched source colours. |
| ConditionBodyColor tintRgb/saturation/brightness | conditionAppearance selects priority → physicalBody occurrence.bodyColor | Body colour filter on physical source only. Independent from an exact swap and from spell hand media. |
| ConditionBodyRamp on persistent.bodyRamp, manifestation.palette, finite bodyMaterials/action_materials | actors → bodyMaterialBinding → body composition passes | Explicit body material filter, including textures/normals/clocks/mappings. Preserve all operators; do not replace with tint. |
| StudioActorLayer/RigLayer.material | Carried to layer; not consumed | Existing isolated-source material owner; missing consumer, no new material framework needed. |
| HitFlash color or palette | damage→FlashTrack→sampleOperation→actors | Finite feedback operation scoped to its source policy; palette flash is a ramp, plain color is replacement. |
| Action actor media colors + vfx_source_hues | compileActorMedia → MediaTrack.sourceColor | Explicit source hue rotation + optional white replacement; not exact swap or generic clothes tint. |
| MediaTrack.tint (projectile.sprite.tint, movementMedia.tint, condition layer.colors.primary) | mediaOccurrences → occurrence.tint | Multiplication tint with explicit source provenance; don't inherit unrelated body/item settings. |
| ConditionLayer.colors secondary/tertiary | Schema retains values; condition-media currently only sends primary tint | Check original family semantics and selected source; do not claim all colour controls are consumed. |
| ParticleTrack.colors; asset.region.palette; blood_responses colors/detail | bodyParticleTracks, particle draw and residue shaders | Procedural particle/deposit material. Native residue amounts/ellipses unchanged. |
| PalettePreview.colors | Authored asset metadata, no production recolour operation | Inspection data; not permission to replace source colours. |
| Spatial/arc/orbit/directed palettes, material identifiers | Explicit procedural operators and component equations | Preserve effect-specific material semantics rather than merging them into actor tint. |
| World treatments.rgb / SceneLighting samples, receiving.diffuseReflectanceLinear, emitters.colorLinear | world/actors/lighting; renderer ambient/direct light | Lighting data, independent from artist colour changes and numeric geometry. |
| Water tint/shallowColor/deepColor | terrain passes water source to shader | Water material, not ordinary sprite tint. |
| Feedback color, number style, UI tint_rgb | NumberTrack and UI source consumers | UI/feedback appearance; not actor material. |

## Functional architecture and timeline controls to preserve

The handwritten presentation modules use exported functions and passive records. No domain class hierarchy was found. Keep release-owned maps and explicit arguments; don't introduce material classes, a registry, a second store, a generic ECS or a second scene model. The current metadata/presentation executor is `compileOperation → eventCommits → sampleOperation → occurrences/scenePatch`, shared by player and Studio through presentation/playback. Moving rendering handles out of broad prepareScene responsibilities should retain these owners and source identities.

Authored frame markers are converted using the owning clip FPS and playback rate. Media has its own FPS/windows/time maps; body release frames are not arbitrary milliseconds. Preserve reverse markers, half-open intervals, source sockets, emitters, registration, contact commits, last-facing maps, corpse terminal poses and condition/item/spatial lifetime dates. No new Haste work is authorized by the earlier explanatory exchange. Existing cancellation/unsupported-media issues are explicit; a renderer plan must list them without silently expanding a colour cleanup into new gameplay choreography.

Known remaining consumer gaps already reported by source code: action variants/projectiles, canceled action/cast choreography, equipment transition media, attack actor.media, weapon trails/interception, movement recovery, healing body/media, top-clearance/sort-depth media attachment, partially suppressed rings, safe-side wall tint, several wallAssembly/recipient/spatial placements, Finger of Death missing companions. Do not call 20 recordings or successful compilation complete authored-feature coverage.

## Inventory inspected

All handwritten src/presentation modules were source-scanned, grouped below; generated authored declarations/schema properties were inventoried with focused inspection of colour/material/layer/registration/timing contracts. No claim that every authored value or every visual case has been accepted.

- Actor and colour: actors, cast, item-material, items, item-effects, condition-appearance, condition-media, body-materials, component-effects, poses.
- Compilation/timing: compiler, timeline, commits, equipment, actions, attacks, spells, spell-media, damage, result-feedback, entity-lifecycle, finite-material.
- Movement/lifetimes: movement, movement-media, condition-time, spatial-time, finite-media, maintained-media, portals, portal-sample, portal-media, retained-portals.
- Media/procedural: media, arcs, directed, effects, orbit-media, particles, particle-media, residue-media, trajectory, direction.
- World: world, terrain, environment, environment-tracks, spatial-media, spatial-placement, lighting, support, target-feedback.
- Shared loading/playback: release, playback, scene-patch, ui.
- All 13 schema entry points and generated authored types inventoried. Focused authored data traversal excluded schemas, large environment banks and provenance source-records from colour occurrence counts; exact layer materials, mode values and explicit paletteSwap families were checked.
- Tests inventoried across tests/. Read focused source/consumer assertions for particles, actor/cast routing, item authoring, fixed-rig components, body/character materials and playback/preview. A new full test run and exhaustive browser visual acceptance have NOT been performed for this documentation-only audit.

## Blood diagnosis — dedicated source-function and GPU comparison

**Confirmed cause of the added elongated streaks:** NDClient projects the ground residue onto the floor image's entire numeric receiving geometry, including its vertical skirts. Pygame projects this deposit onto the tile plane. This is separate from the copied authored landing templates and native residue ellipses.

Evidence and call path:

- `src/presentation/residue-media.ts:45–59` obtains the floor occurrence and borrows its complete `image` and `registration` for the residue. `src/rendering/composition.ts:244,275` selects primitive 4 and binds the procedural density as colour while retaining that image's numeric geometry.
- `src/rendering/surface-shaders.ts:366–383` reconstructs `p` from every admitted floor geometry sample, then passes `p` to `residueColour`. `src/rendering/residue-shader.ts:9` uses only `p.xz`, so the same edge field sample is repeated down a vertical return. There is no top-plane-only admission there.
- Decoding the actual `terrain.stone.e` receiver establishes the geometry, not a guessed screenshot explanation. Source pixels (160,224), (160,228), (160,232) reconstruct approximately `(x,z)=(.5,-.0078)` while `y` changes `-.0117,-.0742,-.1367`. On the original plane their xz samples would advance outside the tile, and be clipped. The documented source bank describes these skirts as coarse inferred vertical returns; no new measured source relief should be claimed.
- Pygame `game_obsolete/surface_residue.py:209–239,268–289` calls `geometric_residue_image → _deposit_texture → _project_texture`; its admitted square field is projected onto the 128×64 tile diamond, with no floor geometry packet.
- Diagnostic geometry-only bypass, keeping the current 128² density, noise, clocks and deposits, removes the long streaks in all four camera views. Thus 128-vs-64 is a second appearance difference, not the cause of the skirt-shaped stretches.

The complete reference was generated by importing the **unchanged original Pygame functions**, not implementing a guessed approximation: `geometric_residue_image`, `_deposit_texture`, `_shade_liquid`, `_project_texture`, plus the original `region_media_assets`. No old game app was launched. Both sides use actual `anchored-spells` prefix-26 fields and an equivalent 2× projection, neutral and original lighting variants, all four quarters. Pygame's different map rotation centre was accounted for by focusing both cameras on the same world contact. The composite comparison uses the same current floor backdrop on both sides, so it compares residue rather than two unrelated floor treatments.

Actual scene data:

- 16 disclosed residue cells, with two world-centred contributions at `(3,6)` and `(5,7)`; each has radii `(1.5,1.5)`, angle 0, amount 1 and max_amount 5. Two cells contain both contributions. These are not elongated native ellipses.
- Blood selects `particles.region.blood`, not a PNG strip or the old atlas fallback. The actual blood-specific four templates of 56 particles match Pygame. The unrelated global fallback templates must not be blamed for this case.
- Both integer world centres select template index 0 / authored seed 1 through the same banker's-round/modulo selector in both implementations. Hence the repeated overall motif exists in the original Pygame reference too. Do not invent random seeds or new blood art to hide the renderer defect.
- Independent GPU density readback against the source kernel equations on the settled fields had per-field RMSE ≤0.00276 and max delta 0.0663. This excludes a gross transposition/ellipse stretch but does not prove final rendering parity.

Secondary concrete differences:

- `src/rendering/residue-fields.ts:9` uses 128² density, while Pygame uses 64². `residue-shader.ts:12` also changes world-noise scale to 128. Pygame shades its fixed 64² source pixel centres, rounds RGBA to bytes, then projects nearest; ND shades the reconstructed receiver fragment position.
- A diagnostic-only combination of plane projection + 64² field + original fixed source-centre noise brings alpha-mask intersection-over-union to 98.78% in all four views, versus 53.8–56.9% for current rendering and ~80.5% for plane-only. At quarter 0 the original mask has 6,212 nonzero-alpha display pixels, current 8,476, plane-only 6,214, and the 64² diagnostic 6,192. These metrics are explanatory evidence, not acceptance tolerances.
- Final colour is still not identical in that diagnostic (neutral premultiplied RGB MAE about 3.96/255 over the mask union). GPU float accumulation, byte rounding, sampling/compositing and the lighting conversion still need a bounded source-fidelity check; do not call the diagnostic a completed repair or use it to authorize unrelated global gamma work.

Timing and preservation:

- `particles.ts` and Pygame `residue_media.py` share delay, flight, melt and landed-fraction equations. `residueKernels` retains native contribution amounts and only subtracts unlanded increments; settled fields do not age away when the transient particle track ends. Fresh elemental shading is limited to its newly landed share and authored `surfaceSeconds`, with the source's 12 FPS age quantization.
- The visual comparison deliberately used fully settled time with no active tracks. Therefore it isolates the persistent long-splat complaint from flight tails and fresh Fire effects; it does **not** certify all active-phase pixels. Repair acceptance should compare before impact, flight/landing, melt, fresh surface response, settled state, replay/seek and quarter rotations while preserving received amounts and membership.
- Existing `tests/particles.test.ts` usefully checks clocks, airborne endpoints, quantities and old-vs-new fields. Its assertion that residue must borrow actual floor image/registration hard-codes the faulty receiver choice and should become an observable footprint/source-parity check. Do not preserve that assertion as a requirement merely because it is in a test.

Diagnostic artifacts were produced under `/tmp` during read-only review; the primary agent retained copies in `.runtime/reviews/renderer-audit-20261011/`. No product code or artwork was changed:

- `/home/tommaso/Dev/NDClient/.runtime/reviews/renderer-audit-20261011/ndclient-blood-cause-comparison.png`: three columns, original Pygame / current NDClient / geometry-only bypass, cropped on the actual repeated stains.
- `/home/tommaso/Dev/NDClient/.runtime/reviews/renderer-audit-20261011/ndclient-blood-comparison-q0.png` through `q3.png`: original/full-current composites at matching four cameras.
- `/home/tommaso/Dev/NDClient/.runtime/reviews/renderer-audit-20261011/ndclient-blood-reference64-composed-q0.png` through `q3.png`: the additional source-density/noise diagnostic; not an implemented fix.
- `/home/tommaso/Dev/NDClient/.runtime/reviews/renderer-audit-20261011/ndclient-blood-composed.mjs`, `/home/tommaso/Dev/NDClient/.runtime/reviews/renderer-audit-20261011/ndclient-blood-ablation.mjs`, `/home/tommaso/Dev/NDClient/.runtime/reviews/renderer-audit-20261011/ndclient-blood-reference.py`: reproducible read-only browser extraction/interception and unchanged Pygame-reference calls.
- `/home/tommaso/Dev/NDClient/.runtime/reviews/renderer-audit-20261011/ndclient-blood-composed-input.json`, `/home/tommaso/Dev/NDClient/.runtime/reviews/renderer-audit-20261011/ndclient-blood-reference-report.json`, `/home/tommaso/Dev/NDClient/.runtime/reviews/renderer-audit-20261011/ndclient-blood-ablation-report.json`: exact input deposits, camera/lighting and metrics.

Plan guidance: restore the authored/Pygame ground-plane residue receiving rule and source-scale shading explicitly; keep lighting as a separate receiving operation. This needs neither a replacement blood asset nor a generic depth/geometry framework. Preserve the original particle flight and state composition owners. The full renderer plan should retain a dedicated blood acceptance section instead of burying it inside broad Mesh removal.
