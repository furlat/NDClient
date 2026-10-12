# Shader and material pipeline review — 12 October 2026

Read-only audit of `/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot`, including every project shader/include, material creation/binding path, inline tool shader, shader-specific tests and current generated evidence. Excludes `.runtime` preserved project copies and `.godot` generated imports. No native process or benchmark was launched for this review. Root is separately evaluating native ambient/point lighting; this report describes the source snapshot with ambient disabled and the custom disclosed-light loop still active.

The latest user request for readable native ambient supersedes earlier “no ambient” restrictions. Review findings do not propose changing backend visibility, light rules, original artwork, source alpha, equipment selection or game elevation.

## What the live renderer actually does

`play.tscn` uses `play.gd`, which inherits the source/material helpers in `main.gd` but overrides scene setup. The live scene creates an orthographic camera and `WorldEnvironment`, explicitly disables ambient at [play.gd:136](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/play.gd:136), and adds authored directional nodes when present. The current authored directional list is empty. It does **not** create native `OmniLight3D` nodes for torches.

Instead, [lighting.gd:102](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/presentation/lighting.gd:102) uploads every disclosed active source into a two-row float texture. [source_lighting.gdshaderinc:34](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/presentation/source_lighting.gdshaderinc:34) loops through that list in each receiving fragment, computes a horizontal circular falloff and Lambert response, and the environment/modular shaders put the resulting reflected radiance into **EMISSION**. This uses Godot's 3D draw/compositing pipeline, but torch evaluation is custom, not native Omni lighting. `ALBEDO`, `NORMAL` and `LIGHT_VERTEX` remain populated, so native directional/Omni and ambient receiving are already possible.

The default `project.godot` main scene is `demo.tscn`, an older exploration path. Its [main.gd:127](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/main.gd:127) creates a diagnostic native Omni, while several demo shaders also emit their full source colour. A screenshot or test of that scene does not demonstrate the live player's lighting setup.

## Complete shader inventory and ownership

| Shader / include | Bound by / active use | Current behavior and disposition |
| --- | --- | --- |
| [environment.gdshader](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/environment.gdshader:1) | `main.gd:add_entry/set_environment`; live `_environment_row` and `_ground_batch`; offline terrain batches | Original colour, source-role masks, door leaf/frame partition, RG16BE depth + octahedral normals, source transforms, wall alpha/ownership. Custom torch contribution enters EMISSION. Its native `light()` supplies the explicit two-sided architectural convention. Keep source decoding/selection/order adapters; native lights can own illumination. |
| [modular.gdshader](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/modular.gdshader:1) | Live `_sync_actors/_sample_actors`; offline modular setup; `CharacterGeometry.bind` | Exact original colour×tint, authored alpha/layer order, selected source frame. RGB normal + affine byte depth and paired masks reconstruct optical receivers. Custom torch EMISSION; native diffuse remains enabled. Keep source adapter; remove custom torch evaluation only when replacement is validated. |
| [source_lighting.gdshaderinc](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/presentation/source_lighting.gdshaderinc:1) | Included by environment/modular and test oracle | White scalar illumination, three custom horizontal radius bands, all-source loop, manual colour boundary, optional two-sided diffuse. Main replacement candidate for native direct light; it is not a geometry decoder. |
| [water.gdshader](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/water.gdshader:1) | `main.gd:set_environment` switches materials with water metadata; inherited by live | Unshaded mask/ripple/colour graph, screen-edge sheen, `TIME` animation. No source lighting, normals, or optical depth. Keep authored graph only if this luminous-water appearance is intentional; see findings below. |
| [fixture_flame.gdshader](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/presentation/fixture_flame.gdshader:1) | Live `_add_fixture_flame/_sample_fixtures` | Unshaded original Texture2DArray frame, original alpha. Appropriate for the flame artwork itself; the separate one-per-item light supplies receiving illumination. No duplicate light should be added by the material. |
| [wall_coverage.gdshader](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/presentation/wall_coverage.gdshader:1) | Live `_sync_wall_mask`, 2D SubViewport/ColorRects | Numeric RGB24 owner IDs; unshaded, blending disabled, original opaque alpha and role selection. Not lighting or FOW. Needed for current overlapping translucent wall source-over policy; do not apply colour conversion to its IDs. |
| [grid.gdshader](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/grid.gdshader:1) | `grid_renderer.gd` and `tools/compile_grid.gd`, older exploration cache only | Custom instanced billboard vertices, numeric atlas metadata/selection/depth/normals, per-instance order slices. Ordinary surfaces emit full source colour; water is procedural emission using TIME. Not a live-player native-light substitute. |
| [actor.gdshader](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/actor.gdshader:1) | Legacy `main.gd` actor path | Source colour in both ALBEDO and EMISSION, planar normal. Full-colour diagnostic baseline plus native light. Not used by live `_sync_actors`, which always selects modular shader layers, including fixed creature sheets. |
| [shadow.gdshader](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/shadow.gdshader:1) | Legacy actor shadow path | Unshaded original shadow colour/alpha. Painted sprite shadow, not native shadow casting. Live modular shadow layers use the modular shader's shadow branch instead. |

Additional shaders: [tests/character_geometry_oracle.gdshader](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/tests/character_geometry_oracle.gdshader:1) is an independent constant receiver test material, not runtime. `tests/character_geometry_sampling_checks.gd` creates an integer-fetch variant of the production shader for differential sampling checks. [tools/unity_reference_view.gd:50](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/tools/unity_reference_view.gd:50) creates a flat blue canvas-item water reference shader. No other shader files, includes, inline shader definitions or saved material resources were found outside excluded copies/imports. The only production `StandardMaterial3D` creation is the offline diagnostic lamp marker at `main.gd:139`.

## Prioritized findings

### P1 — confirmed current policy problem: no readable indirect/ambient term

[play.gd:136](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/play.gd:136) disables ambient and [lighting.gd:130](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/presentation/lighting.gd:130) forces the material base-emission factor to zero. With no authored directional, fragments rejected by all source normals become exactly black. That was deliberately tested, but the latest user explicitly rejects the result. It is not an unavoidable Godot limitation.

Use a native `WorldEnvironment` ambient source for the requested readability. Existing receiving materials already supply ALBEDO; no new per-pixel ambient loop is required. Godot adds ambient separately from direct light and emission; choosing a constant ambient colour also avoids making ambient depend on these estimated surface-normal discontinuities. [Godot Environment](https://docs.godotengine.org/en/4.7/classes/class_environment.html), [Godot GLES3 renderer](https://github.com/godotengine/godot/blob/4.7-stable/drivers/gles3/shaders/scene.glsl#L2274-L2289).

### P1 — measured asset-quality issue: the remaining black patches largely precede runtime quantization

The corrected source45°/origin(64,96) registration fixes an actual client integration error. It does not certify the delivered estimated surfaces. [character_geometry_quantization.json](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/generated/character_geometry_quantization.json) compares exact current four-light values over 491 opaque source pixels: 80 of 81 byte-zero pixels are also exactly zero with original float NPZ normals/depth; none of 24 fallback pixels is black. Chest14 neighbouring pixels (63,67)/(63,68) have identical original RGB185, float depth differing only0.086, but float normals differing76.46° and irradiance0 versus1.77. They share the same observation winner; this is not a fusion winner boundary.

Native ambient addresses readability; it does not establish that these local normals are physically correct. Do not silently blur artwork, fabricate normals, or label byte precision as the root cause. Any source-field repair needs its own source-owned acceptance. The raw fields and original tint reference are retained in `.captures/character-geometry/raw-source-fields.png` and `.captures/emitter-placement/unlit-source-tint-close.png`.

### P2 — confirmed architectural duplication: torch lighting bypasses native source selection and shadows

[source_lighting.gdshaderinc:36](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/presentation/source_lighting.gdshaderinc:36) iterates **every** active disclosed light for **every** covered environment/modular fragment, including fragments behind later transparent draws. It has no per-mesh/per-cluster light list. Its output bypasses native light attenuation, native light colour, source shadows and native light culling. This is an identifiable scaling shape, not a measured claim that native lights will be faster on this workload.

Native Omni can replace this direct illumination while retaining the source receiver shaders. Do not run the same torch through both the custom loop and a native node: their contributions add. Backend radii remain authoritative gameplay data; Godot's spherical falloff is a presentation decision and does not reproduce the existing horizontal three-band curve exactly. Preserve that distinction explicitly rather than claiming a drop-in visual equivalence. [OmniLight3D](https://docs.godotengine.org/en/4.7/classes/class_omnilight3d.html).

### P2 — confirmed live exception: water ignores lighting and displayed pause

[water.gdshader:2](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/water.gdshader:2) is unshaded; lines36–42 use global TIME and write final visible colour. Adding ambient or native torches therefore cannot make it participate in the same surface-lighting model, and a paused/replayed scene can still animate ripples. The older grid water branch repeats that behavior at `grid.gdshader:89`. This is observable whenever a water source is selected through inherited `set_environment`, not proof that every current Crypt recording includes water.

Keep the authored ripple/colour graph, but drive its animation from the displayed clock if deterministic pause/replay is required. Decide explicitly whether water is intentionally emissive or a lit surface. Godot's global TIME continues while paused; native timing does not automatically inherit the SDK display clock. [Spatial shader TIME](https://docs.godotengine.org/en/4.7/tutorials/shaders/shader_reference/spatial_shader.html#global-built-ins).

### P2 — confirmed missing presentation distinction: atmospheric fog is not current visibility

[world.gd:14](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/presentation/world.gd:14) emits all disclosed/remembered tiles and objects. Only actor visibility and active fixture flames consult current senses. No shader receives a current-visible versus remembered state/mask. Thus ambient will also illuminate remembered terrain, and remembered geometry currently has no distinct FOW treatment. This is not a leak of undisclosed backend data—the SDK remains the source—but it is a presentation gap for tactical fog of war.

Native environment fog is suitable for atmosphere. It does not know the player's senses and cannot replace that disclosure distinction. Keep current visibility/memory presentation sourced from the existing subjective state, separately from atmospheric fog. The GLES3 renderer evaluates native fog using the receiving vertex after LIGHT_VERTEX substitution; this can provide source-height atmosphere without editing actual sprite vertices. [Godot GLES3 source](https://github.com/godotengine/godot/blob/4.7-stable/drivers/gles3/shaders/scene.glsl#L2122-L2196).

### P2 — migration gate: native lights and the existing large ground MultiMesh

[play.gd:363](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/play.gd:363) puts all flat base0 tiles of a material into one MultiMesh. Compatibility's default eight Omni lights apply per mesh, and a MultiMesh shares its selected light list. A naive native-light replacement can therefore omit relevant lights across a large hall even if a small actor/room test looks correct. The current 25-source test at `tests/lighting_render_checks.gd:135` puts24 sources far away; it does **not** prove correct native selection with more than eight overlapping lights on one mesh.

Validate a furnished hall with more than eight simultaneously relevant sources and camera movement, plus a light near a reconstructed receiver outside its thin billboard's unmodified AABB. Native culling starts from geometry bounds; LIGHT_VERTEX does not change those bounds. Forward+ offers clustered lighting but is not automatically a drop-in cure: cluster XY follows screen fragments while the reconstructed receiver can move laterally; validate these displaced receivers at light/cluster edges. [MultiMesh](https://docs.godotengine.org/en/4.7/classes/class_multimesh.html), [renderer light limits](https://docs.godotengine.org/en/4.7/tutorials/3d/lights_and_shadows.html#light-number-limits), [Forward+ cluster lookup](https://github.com/godotengine/godot/blob/4.7-stable/servers/rendering/renderer_rd/shaders/forward_clustered/scene_forward_clustered.glsl#L1423-L1430).

### P2 — confirmed conditional colour discrepancy: base-emission factor is not an ambient control

[source_lighting.gdshaderinc:28](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/presentation/source_lighting.gdshaderinc:28) computes `decode(albedo * base)` on Compatibility, but `linear_albedo * base` on Forward+/Mobile. For intermediate base values these are different energies. Existing live0 and offline1 avoid the discrepancy. Raising this factor to make the game readable would introduce an avoidable cross-renderer difference; use native ambient for that requirement.

The remaining colour choices are deliberate: environment/legacy colour textures use `source_color`, numeric maps do not; modular originals are sampled raw so authored encoded RGB×tint happens once before renderer-specific conversion. Changing modular to `source_color` without revisiting multiplication order would change original tint semantics. The present native tint/sampling evidence covers Compatibility, not a full Forward+ colour certificate. [Godot source-colour hints](https://docs.godotengine.org/en/4.7/tutorials/shaders/shader_reference/shading_language.html#using-source-color).

### P2 — known pipeline limitation: optical receivers are not opaque geometry

All world spatial shaders write ALPHA, disable depth testing/writes, and their nodes disable shadow casting (`main.gd:466`, `play.gd:382`, `grid_renderer.gd:55`). Sorting is semantic painter order through `sorting_offset`; source depth only supplies lighting receivers. Enabling native shadows, SSAO, SSR or switching renderer cannot make these quads into the missing solid world. Transparent materials also do not populate the ordinary depth/screen paths needed by several screen-space effects.

Preserve the current layered composition; replacing it with depth tests or alpha scissor would alter source transparency and interleaving. Native light/ambient adoption is separable from such a redesign. No actual-wall optical shadow claim should accompany the lighting change. [Godot transparency limitations](https://docs.godotengine.org/en/4.7/tutorials/3d/3d_rendering_limitations.html#transparency-sorting), [spatial shader transparency](https://docs.godotengine.org/en/4.7/tutorials/shaders/shader_reference/spatial_shader.html#light-built-ins).

### P3 — scaling issue, not a new measured blocker: translucent wall ownership still redraws continuously

[play.gd:903](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/play.gd:903) keeps the full-resolution ownership viewport updating every frame in Translucent mode. [environment.gdshader:107](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/environment.gdshader:107) can additionally fetch nine neighbouring IDs before discarding covered fragments. This serves the proven overlap policy, but remains a full additional raster pass while the scene is stationary. Existing comments document a failed UPDATE_ONCE attempt; removing continuous updates without reproducing that regression would be unsafe. Measure the mask viewport separately before changing it. Hidden/Solid disable its updates.

### P3 — defensive shader cleanup candidate: geometry fetch occurs before its guard

[environment.gdshader:129](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/environment.gdshader:129) fetches numeric geometry before checking `has_geometry` and packet bounds. Valid colour-only fallback does not use the result, but still executes that source-level fetch. Normal-region fetches also lack their own bounds check. No concrete currently registered source causing a visible out-of-bounds result was established. Move numeric access inside validated branches if touching this shader; do not introduce substitute normals or discard unsupported colour.

## What should remain custom, and what Godot can own

| Keep as source/game adapter | Prefer native Godot responsibility |
| --- | --- |
| Exact sprite frame/row, palette multiplication, original alpha and authored layer order | Ambient source, exposure/tonemapping, ordinary point/directional illumination |
| Environment RG16/oct versus modular affine/RGB decoders; masks; their distinct source camera transforms | Light node lifecycle keyed by the existing disclosed item IDs, with activation/position from displayed state |
| Source NORMAL and LIGHT_VERTEX values; they are not tangent-space NORMAL_MAP textures | Native receiving through those built-ins; existing490 checks already exercise point/directional receiving |
| Whole-member wall reveal, authored door partitions and proven translucent overlap policy | Native atmosphere fog, distinct from backend visibility/memory |
| Subjective visible/remembered/unknown presentation and canonical game elevation | Standard material only for genuinely simple unshaded marker/flame/shadow cases where it preserves the existing pixels |

Godot explicitly permits writable NORMAL and LIGHT_VERTEX without moving rasterized fragments. This is the appropriate native integration point for these assets; replacing source-aware receivers with arbitrary mesh physics is unnecessary. [Spatial shader built-ins](https://docs.godotengine.org/en/4.7/tutorials/shaders/shader_reference/spatial_shader.html#fragment-built-ins).

## Evidence boundaries and recommended finite acceptance

Already available: corrected490 native geometry checks across96 outfit/clip/facing compositions and four quarters/scale variants;4 actual Crypt CPU/material comparisons;36 exact nearest-versus-integer sampling comparisons at fractional zoom and final frame/row boundaries;117 tint,41 emitter and108 fixture checks. These prove the stated integrations, not complete physical geometry, arbitrary-catalog quality, Forward+ equivalence or large-map native-light scaling.

For the native-light/ambient comparison: use the same real Crypt and large-gallery recordings, identical camera/clock/outfits, and compare readable indirect light, isolated point/directional response, source extinguish without removing ambient, raised support/jump, original tint/alpha, all four views and overlapping8+ lights on the large ground mesh. Retain independent source-field diagnostics. Do not keep the old “all extinguished means exact black” assertion as product policy after the user's explicit ambient request; keep it only as a controlled zero-ambient physics fixture.

No runtime implementation, source artwork, backend state/rules or rendering process was changed by this audit. Performance benefits of native Omni versus the custom loop remain unmeasured until the coordinated comparison completes.


## Subsequent implemented disposition — live player repair

The inventory/findings above describe the pre-repair inspection. The live player
now uses native OmniLight3D sources plus its native WorldEnvironment ambient;
the custom radial fragment loop has been removed from production receivers.
Backend circular perception/radius rules remain authoritative and unchanged;
native spherical attenuation is explicitly optical presentation. Existing source
NORMAL/LIGHT_VERTEX adapters, original alpha/tint and door/wall ordering remain.
Numeric environment depth/normal sampling now checks the respective packet bounds
before access. Compatibility light capacity is explicitly bounded at 64 per
object and 256 renderable positional lights, not unlimited.

The revised native-light suite proves 24 actually relevant sources contributing
to one large MultiMesh (sample luminance 0.57647 with 24 versus 0.34510 with 8),
plus native spherical-height range, original wall normals/depth and energy changes.
Original modular outfit/swap/facing checks pass 394 assertions; native direct
receiver comparison covers 491 source pixels in actual Chest7/Chest14/Head15 with
zero pixel differences against independent CPU-reconstructed receivers lit by the
same native lights. The former custom-falloff test was removed rather than kept
as a second production model. Source-field discontinuities documented in the
quantization report remain facts about delivered input; this repair does not
claim to reauthor or certify the source geometry.

Live water now receives native lighting and explicit displayed time. The native
11-check proof covers original graph/mask/ripple, point/directional lighting,
pause, media backpressure, timestamp replay and remembered appearance. The older
compiled `grid.gdshader` is explicitly retained as an offline source-art reference;
its emissive water/global TIME branch is outside the live migration, not silently
counted as repaired.

Current/remembered styling now consumes only the displayed subjective grants,
with no unknown-map synthesis or actor/fixture disclosure expansion. The shader
keeps original alpha and hit masks. A newly introduced ground custom-data/color
interaction was caught by manually inspecting the actual scene: batched floors
were absent even though character light tests passed. Explicit white instance
colours corrected it. `generated/ground_visibility_checks.json` then proved all
four views and all-current/all-remembered/mixed visibility exactly match original
single draws (24 checks, no pixel mismatches). Negative-floor rendering/picking
and batching restoration are covered by `generated/scenery_render_checks.json`
(36 native checks), independently of source-geometry lighting tests.

The remaining atmospheric-fog recommendation and generic renderer/scale concerns
are not claims of implemented features. Final current performance and creation
costs belong to the root-run post-repair profile artifacts, not this review.
