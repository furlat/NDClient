# Character layers

**Goblin/Orc and Demon layer controls are implemented:** 65 characters, all
1,368 combined sheets. Each has original clean body and shadow sources; 330
have nonempty original swoosh/glow sources. Unimplemented creatures are included
without inventing gameplay assignments. Existing rig identities, frames, facing rows,
contacts, sockets and clocks are unchanged.

`sheet-components.json` is the single tracked authoring owner, assembled into
`AnimationData.sheet_components`. Resolve a clip's existing resource ID through
`catalog.resources`, then look up that URL here. No second creature binding map.

## Use and inspect

```sh
npm ci
python3 tools/serve_character_review.py
# http://127.0.0.1:8798/
```

The review lets you select every character/action, scrub every frame/facing,
play, adjust body/shadow/VFX strengths, recolour body and VFX independently with
hue/tint, and inspect each component alone against dark/light backgrounds.
Registered source sheets use an existing authored clip FPS for inspection; the
page does not select a semantic body context or apply its playback-speed modifier.
Library-only actions explicitly use a 12 FPS inspection clock, not a new authored
gameplay rate. Slider values are temporary review inputs, not saved animation recipes.

The review imports **`tools/character-review/material-reference.mjs`**, a bounded
source-comparison harness. It shares the component equations in
`src/rendering/character-material.mjs`; production uses `character-filter.ts`
and ordinary Sprites through the shared gameplay/Studio renderer. The harness
is not imported by either application.

## Goblin and Demon source interaction

A combined URL has this shape:

```json
{
  "composition": {
    "kind": "source_interaction",
    "has_accent": true
  },
  "source_layers": {
    "shadow": "/media/smallscale/authored/orcs-and-goblins/Seperate shadows and effects/Goblin 08/Shadows/Attack 5.png",
    "accent": "/media/smallscale/authored/orcs-and-goblins/Seperate shadows and effects/Goblin 08/Effects/Attack 5.png",
    "body": "/media/smallscale/authored/orcs-and-goblins/Bodies/Goblin 08/Attack 5.png"
  }
}
```

The actual companion paths are the JSON values; the source pack's effect/shadow
folder names are preserved. `has_accent=false` means the original effect is absent
or fully transparent. Its VFX controls do nothing; it does not acquire fake effects.
The original combined sheet remains the exact neutral reference, rather than being
replaced with a visually different stack of isolated sheets.

Four original RGBA sources feed one WebGL2 Pixi mesh. No generated per-frame
residual textures, fitted masks, CPU per-frame image work or image copies per
material setting. Images are sampled as straight RGBA and premultiplied once in
the shader. All four use the same source region; the material does not own clocks,
load images, choose rig contacts or resize creatures. Its Pixi transform supports
normal parent transforms. Texture ownership remains with the caller.

The algebra is explicit. In premultiplied RGBA, `over(A,B)=A+(1-A.a)*B`.
`C` is combined, `B` clean body, `S` original shadow, `E` original effect.
`H` is the observed visible shadow contribution; `F=C-H`.
For body/effect strengths `b,f` and shadow strength `s`:

```text
b*f*(F+sH) + b*(1-f)*over(B,sS)
           + (1-b)*f*over(E,sS) + (1-b)*(1-f)*sS
```

This uses the user's subtraction principle: preserve the combined interaction
rather than assume the full separate VFX always lies in front of the body.
At neutral colours/strengths it returns `C`. At effect-off it returns the clean
body and requested shadow; at body-off it returns the original standalone effect
and requested shadow. All-off is transparent. Intermediate strengths interpolate
these observed endpoints; they are not a recovered physical emission simulation.

For a sheet without effects, interpolate the body/shadow endpoints instead:
`b*s*C + b*(1-s)*B + (1-b)*s*S`. This preserves the combined neutral image and
returns the actual clean body when the shadow is disabled. The VFX knob has no role.

`H` uses source shadow colour/coverage, corrected by observed exposed shadow
samples and bounded so that both `H` and `C-H` remain valid premultiplied colours.
Recolouring allocates retained body colour using the clean-body/effect colours;
the remaining visible colour is treated as the effect contribution. Allocation
is nonnegative and bounded by the observed combined image. Hue/tint changes keep
alpha unchanged. Neutral highlights remain neutral under hue rotation; the tint
control can also colour those highlights. LDR output stays within its alpha.

**Limits:** overlapping vendor exports do not uniquely identify the original 3D
blend. Colour attribution and removal of a shadow mixed with glow are an explicit
rendering convention, not recovered material IDs or exact hidden illumination.
Body-off can reveal a different shape from combined-off because the isolated
vendor effect includes portions occluded/changed in the combined export. No hidden
geometry, normals or collision shape is inferred from these colour controls.

## Production consumption

- The existing clip selects the action, frame, facing and source rectangle;
  `createCharacterMaterial` receives those sources, rectangle, dimensions and
  authored pivot. `setCharacterRegion` and `setCharacterControls` only update uniforms.
- Load each original sheet once through the eventual shared resource owner. Use
  straight-alpha (`no-premultiply-alpha`) sources, identical aligned UVs, nearest
  sampling for these pixel sheets, and no browser premultiplication/colour conversion.
  The shader outputs premultiplied colour, using normal premultiplied blending.
- **Draw the combined interaction once.** Its `source_layers` are consumed inputs,
  not automatic additional draws. All 330 registered semantic clip uses retain a
  matching shadow slot; all 85 nonempty accent uses now have an explicit
  `BodyClip.layers` owner (19 enabled, 66 disabled). Consume
  each selected companion once at the same clip/frame occurrence. Preserve unrelated
  aura/spell layers and the original rig records. `has_accent` means source availability,
  not permission to activate it: 66 clip uses have a nonempty source effect that the
  original clip does not request. Apply the authored layer selection before composition.
  Apply `BodyRig.shadow_alpha` once; the review's neutral source strength of 1 is not
  a replacement for the game's appearance policy.
- Body/ground/effect depth roles remain distinct. A baked ground shadow must not
  write actor depth, body normals, hit areas or selection outlines. This leaf colour
  material is ready to integrate; the world's depth/resource/event machinery remains
  a separate part of the master plan.
- Destroy the mesh's geometry and shader when releasing it. The caller retains
  ownership of shared sources. The review demonstrates releasing sources/bitmaps
  when changing the selected sheet instead of accumulating the whole library.

## Pygame integration scan — 9 October 2026

**Data foundation ready; production animation/material integration not complete.**
The 65-character control page demonstrates source composition, not the full
semantic animation path. The initial scan confirmed all 43 fixed rigs matched
the engine originals. The completed authoring connection below adds only explicit
FX selections and their source slots/references; it preserves the original
actions, timing, contacts, scale, sockets and contexts. With the modular rig, the catalog
has **44 rigs, 452 semantic clips and 767 body-context bindings**. Of the 1,368
interaction-backed sheets, 322 are used by those existing rigs, across 24
characters and 330 semantic clip uses. The other 1,046 sheets are library assets;
they have source controls but no invented gameplay assignments or rig contexts.

Pygame's actual path is:

```text
received PlayerLineage + retained PlayerState
 → presentation_groups / bind_presentation_group
 → bind_choreography or bind_motion, with existing recipes and rig contexts
 → sample_body_presentation / BodySample at the displayed clock
 → resolve_actor_layers + BodyClip.layers + selected cast/condition layers
 → rig frame/row/socket registration and material treatment
 → support shadow and physical body/effect draws
```

Source owners in the engine and the corresponding client JSON:

| Concern | Existing authoring owner | Runtime semantics to preserve |
| --- | --- | --- |
| Creature identity → rig | `catalog/creature_rigs.json`, `root_rig.json` | Disclosed actor identity selects a registered rig; library presence grants no abilities. |
| Semantic action → source clip | `catalog/rigs.json`: `BodyRig.clips`, `BodyClip.source_clip`, `sheets` | Aliases select existing images, not copied animations. E.g. Demon Beast 1 semantic Attack5 uses source Attack 3. |
| Frame geometry and camera facing | `BodyRig.cell_width/cell_height/facing_rows/origin_y_from_ground/body_anchor` | Use actual rig dimensions and viewed facing. Other existing rigs also use 64/84/96px cells; the page's 128px/eight-row subset is not a universal loader. |
| Timing and transitions | `BodyClip.frames/fps/anchors`; `BodyContext.actor.playbackSpeed`, `playback`, `reversed`, `restFrame`, `frameKeys`; `action_playback_rates.json` | Exact qualifier → role default → shared recipe; finite completion at the last frame, explicit loop/rest/reverse/normalized-travel sampling. Apply each rate once. |
| Hands and ground contacts | `BodyClip.source_sockets`, `BodyRig.pose_sockets/rest_pose_anchors` | Shared body time/facing supplies sockets. Do not substitute the sheet centre or infer contacts from colour. |
| Rig-specific spell conversion | `BodyRig.body_contexts`, `BodyClip.owns_cast_preparation`; `spells/*.json` | `adapt_cast_body`/`resolve_cast_recipe` replace gesture/anchors/sockets while retaining spell delivery. Clip-owned preparation suppresses duplicate hand preparation; adaptation clears incompatible modular accents/equipment changes/recovery. |
| Appearance and fixed accents | Existing `RigLayer`, `BodyClip.layers`, `slot_order/categories`, item appearance sections | Resolve equipment set, hidden slots, exact original accent selection and rig shadow alpha before source composition. |
| Spell layer colours | `StudioActorLayer.colors/palette/sourceSheet/blendMode`, `PaletteTreatment`; draft `elementColors` | Resolve automatic spell palette, preserve explicitly baked overrides, normal/add/screen. Hue/tint sliders are not a replacement for these records. |
| Conditions, manifestation and finite materials | `condition_recipes.json`, `body_materials.json`, `action_materials.json`; `ConditionBodyRamp`, `StudioBodyMaterialTrack` | Keep original texture/normal/noise references and envelope clocks, frozen poses, alpha, outline and equipment ownership. |
| Pixel components | `characters/sheet-components.json` | Select source treatment and registered companions for the already chosen clip. It owns no gameplay timing, spell identity or material lifetime. |

The main implementation sources are engine `game/animation_data.py`
(`resolve_actor_layers`, rig import), `game/animation.py` (`resolve_body_context`,
`adapt_cast_body`, `resolve_cast_recipe`, `context_frame`, `context_anchor_ms`),
`game/animation_draw.py` (`_body_image`, `_actor_blit`),
`game/condition_animation.py`, `game/finite_material.py`, and
`game/presentation_group.py`. These are semantic references; their CPU surface
loading/recolouring/cache architecture is not the Pixi implementation template.
Pygame itself does not consume the new `sheet_components` field.

### Remaining connections, with precise ownership

1. **Port the pure rig/context sampler and layer resolver.** Feed it the existing
   catalog and displayed event-derived actor state. Its derived result is an
   ordinary render input, not another saved animation database. Companions share
   the selected body frame, facing and clock. Use the source slots to decide which
   contributions are active; never enable all effects merely because C contains them.
2. **Connect full material operators.** The leaf shader currently implements hue
   and multiplication tint, not `PaletteTreatment`, `ConditionBodyRamp`, donor
   textures, finite material envelopes or item coatings. Those typed parameters
   are already copied. Port their mathematical operators, with source preparation
   outside the frame loop, rather than silently approximating them with hue rotation.
   The optional `material: ConditionBodyRamp` field now exists on both
   `StudioActorLayer` and native `RigLayer`. Consume that existing passive record;
   do not create a second hand/glow material schema. No new artistic treatment
   has been assigned merely to populate the optional field.
3. **Keep physical roles separate.** Use the registered clean-body source for body
   selection/outline coverage, not combined C or the colour allocation coefficient.
   Ground shadows follow receiving supports and do not rise with a jumping body.
   Body/effect colour composition alone does not implement their depth/lighting
   behavior; shared-source inputs may feed distinct world passes without reloading
   or duplicating the visible contribution.
4. **Use the existing resource owner and schema.** Load/cache source pages once,
   drive all aligned companions together, and generate TS authoring types from the
   existing passive Python owners once when the actual amendments are settled.
   Play and recorded-server Studio share the same compiler/sampler/material path.
   No review-specific clock, page loader or DOM slider becomes production state.

The review controls need not all become permanent JSON knobs. Body opacity,
shadow strength, palette and material timing already have semantic owners above.
Persist actual authored choices there; transient preview knobs stay in the review.
If an independent artistic setting is genuinely absent, extend its existing
layer/treatment owner, not `SheetComponents` or a parallel preset system.

### Completed authoring connections — 9 October 2026

This preparation is complete for the existing Goblin/Demon and animal/dinosaur
rigs. `catalog/rigs.json`, `catalog/resources.json`, this component catalog and
`schemas/animation.schema.json` are the tracked current inputs. Do not rerun the
original importer over them. No artwork was copied or regenerated in this step.

- Each of the 85 semantic clips using a nonempty original Goblin/Demon effect now
  has its exact companion in `clip.sheets` and an explicit `clip.layers` selection.
  **19 remain enabled; 66 are disabled.** The disabled choices preserve Pygame's
  original clean-body selection without its unrequested effect, rather than the
  inspection page's all-on combined-source comparison. Eleven rigs gained the
  needed effect slot/category; no gameplay identity, ability or animation was added.
- All 420 unique existing fixed body/shadow pairs are connected through
  `source_layers.shadow`, including **98 new animal/dinosaur links** across 18
  rigs and 99 semantic clips. Source aliases share one component record. Animals
  retain their measured source selection, receiving-shadow registration and
  existing scale; a source link does not claim hidden clean-body reconstruction.
- `RigLayer.enabled` defaults to true. The existing `alpha` and `tint` fields are
  now permitted on clip accents as authored controls, rather than restricted to
  opaque white. To hide an original FX, set that layer's `enabled` to false;
  leave its category, sheet and slot membership in place.
- `RigLayer.material` and `StudioActorLayer.material` optionally carry the existing
  `ConditionBodyRamp` record. When assigned, it supplies the layer's full material
  operation instead of the legacy palette/tint operation; when absent, the
  existing palette/automatic spell-colour/tint path remains unchanged. Visibility,
  opacity, source coverage, timing and blend retain their existing owners. No
  speculative new palettes or textures were assigned.

For example, in `catalog/rigs.json` under
`smallscale.goblin08.clips.Attack5.layers`, the editable selection is:

```json
{"slot": "effect", "category": "Goblin08Effect", "enabled": true}
```

Changing that `enabled` to false disables the **original embedded FX contribution**,
not just an extra draw. The renderer must consume matching companions exactly once
whether enabled or disabled. Disabled clip layers still reserve their slots so
fixed-rig appearance selection cannot resurrect them as persistent effects.
Unrelated spell/condition layers remain independent. `owns_cast_preparation` stays
an ownership decision: disabling its visual does not implicitly turn on shared
hand preparation or change a release marker.

Library-only creatures retain source metadata without invented gameplay rigs.
Other packs' qualifications remain unchanged. The asset page still uses temporary
inspection sliders; it does not pretend to consume these gameplay selections.
The shared runtime, palette/material operators and event-driven Studio remain
future implementation, with no further character-library import needed first.
Anti-slop and data-owner/ECS reviewers checked this bounded authoring connection.

## Other Smallscale sheets

There are 12,705 source records in total: 8,314 `whole`, 2,370 `source_rgba`,
653 label `mask`, and the 1,368 `source_interaction` records above.
Modular original sheets already have whole body/gear, shadow or accent roles.
The remaining fixed packs retain the initial source partition and explicit
limitations; this work does **not** certify their overlapping body/VFX separation.

`whole` chooses one source role. `source_rgba` evaluates ordered inclusive original
RGBA-byte rules before interpolation/recolouring, then its remainder role.
`mask` uses registered lossless L8 labels: 0 empty, 1 body, 2 shadow, 3 accent.
Numeric masks are sampled nearest without colour conversion or premultiplication.
Alpha-zero is empty for these character PNGs; **do not generalize this to Factory
radiance packets**, which can emit RGB at zero alpha.

`visible_partition_only`, `source_body_pose_mismatch` and `accent_body_overlap`
remain meaningful qualifications on those other packs. In particular the vendor
Wizard Run body's pose mismatch is not repaired by substituting that source.
Remaining `accent_material_mask` fields outside Goblins/Demons are earlier
unaccepted experiments, not this material's inputs. Their presence is not acceptance.

## Preparation and evidence

`tools/prepare_character_layers.py` copies original clean bodies to each pack's
`Bodies/<character>/<action>.png`, connects existing source URLs, retains PNG bytes,
and retires only the now-unreferenced generated masks for these two families.
It added 198.69 MiB of original bodies and retired 1,089 generated mask files.
Original colour/effect/shadow images and Pygame authoring were not overwritten.
Art remains ignored; authoring/schema/material/tools/tests belong in Git.

Preparation validates all 1,368 layer sets' registered dimensions. The existing
Python `SheetComponents` owner exports the schema; the client does not define a
second wire type. The ordinary assembler needs neither archives nor the engine.

Verification on 9 October 2026:

- 25 client authoring tests pass; 78,772 assembled media references resolve.
- GPU/source endpoint comparisons: 69 actions covering all 65 characters, seven
  endpoints each on dark/light backgrounds, **483 comparisons with zero byte error**.
- Whole-sheet neutral comparisons cover all **360 frames/facings** of Goblin 08
  Attack 5/6 and Demon Beast 1 Attack 1. Independent source checks also ensure the
  test is not merely comparing two blank shader outputs.
- Hue changes retain alpha; real selection/playback controls run without browser
  errors. Representative overlap, solo and recoloured views were inspected.
- These checks use Chromium WebGL2/SwiftShader. They establish composition behavior,
  not native GPU performance claims or a visual review of every frame of every sheet.

Reproduce CPU authoring checks with `python3 -m unittest discover -s tests` and
`python3 tools/build_authoring.py`. GPU checks are in
`tests/character-material.browser.mjs` (its header lists Playwright, browser and
Python/Pillow/NumPy environment options). The original subtraction trial and earlier
source investigations remain local under `.runtime/character-components/`.
