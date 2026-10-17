# Client essential-work audit, 17 October 2026

## Why this audit exists

The 16 October structure plan, its review and a day of work all optimized
*inside* the existing rendering design. None asked what the content requires.
The user put it directly:

- A door reveal adds **24 distinct colour textures**; everything else is
  instances. The floor is one texture at 875 positions.
- "Character opens door, 10 ms later there is the room."
- "You are doing like 2 matrix multiplications in 300 doing idiotic for
  loops."

This audit compares, per system:
- what the content requires (the essential work);
- what the code does per instance and per frame;
- what a GPU-first design would do instead, **without changing the picture**.

Three studies, three adversarial code verifications and three plan reviews
(correctness, anti-slop, data-oriented) produced it; §5 records what they
changed.

### Measured state (Gallery, run `20261017T042011.916389Z`)

Source: `generated/profiles/2026-10-17T06-20-40-gallery-live-spells.json`
and `.runtime/player-runs/20261017T042011.916389Z/`.

| | Value |
|---|---:|
| GPU time per frame, measured viewports (main 0.24, light atlas 0.21, shadows 0.26; blood, spell and support passes not measured) | **~0.7 ms** |
| Render-thread CPU | 0.47 ms |
| Player script time, "idle" frame | **8.4 ms** |
| of which media work, exclusive (`optional_preparation` 1.29 + `media_publication` 1.10; `media_optional_maintenance` and `media_optional_selection` run inside `_warm_media`, `play.gd:2514-2546`, which runs inside both) | ~2.4 ms |
| of which `draw_order` | 1.12 ms |
| of which displayed samples (timeline) | ~0.25 ms |
| unattributed script time | **~4.5 ms** |
| Frame interval | 11.8 ms (~85 Hz) |
| Static painter entries | ~460 |
| Light atlas | 538 receivers, 20.9 Mpx |

The frame is script bookkeeping. GPU time is under a millisecond across every
measured viewport (`gpu_ms` covers only the main viewport, so each SubViewport
is read separately). The "idle" frame is not idle: the optional preload is
still filling a 16 GiB budget.

The ~4.5 ms of unattributed script time is attributed at the start of L1 with
exclusive phase timings, each phase tagged with the L step that removes it.

VRAM is reported by format in §3 Media. The run directory has no
`video_memory_mib` samples (`frame_profile.gd:29` emits that field), so the
profile's figures (6,241 MiB at 12.5 s with 1,084 textures, 8,383 MiB at
22.3 s with 1,454 textures, still rising) are re-measured before L8 uses them.

## 1. Lighting: the 2D light atlas

**What it computes.** Screen-space 2D point lighting per *source texel*,
with native Canvas lights and no custom `light()`
(`canvas_environment.gdshaderinc:2-4`). Per light, as Godot 4.7.2's
`canvas.glsl` evaluates it (light `color[3] *= energy`, `light_blend_compute`
ADD):

`light = T.rgb · C.rgb · (C.a·e) · max(0, N·normalize((P,h) − (p,0))) · S`,
added to the colour weighted by `T.a`; before the lights the colour is `S·A`.

| Symbol | Meaning |
|---|---|
| `S` | sRGB-encoded source colour (white when storing irradiance). The capped output samples the colour without the `source_color` hint, so values are used as encoded. |
| `A` | Ambient **0.30 numerically in both HDR and LDR**: `canvas.glsl` applies `srgb_to_linear` to the modulate only under HDR, and the code pre-encodes it (`native_light_atlas.gd:110,123-125`). Light colours and cookies are unconverted. Blood and effect pages use **0.18**. |
| `T` | Cookie, read with the **receiver's NEAREST sampler** (the sampler belongs to the per-batch texture set; receivers are nearest, `canvas_draw.gd:20`, `native_light_atlas.gd:104,870`; the lights' `texture_filter=LINEAR` has no effect), hard zero outside `[0,1)`. World lights: 256² cubic radial profile, elliptical with the camera (`scale.y = abs(cam.z.y)`), centred on the projected **support** point (`lighting_2d.gd:78-104,361-378`). Spell lights: a 65-stop attenuation cookie, circular, centred on `P` (`native_source_lights.gd:120-145,203,216-217`). |
| `C`, `e` | World lights: torch colour or white, `e = 2.0 × energy × strength` (× flicker). Spell lights: `light_energy × energy_multiplier × strength`, with an optical colour override. |
| `P`, `h` | World lights: projected optical point (carried lift 2.5 steps including jump height, unregistered 1.0, fixture registered or mean height); `h = 56·2/PPU·ppu`, so it scales with zoom. Flicker also moves the optical height (`play.gd:1426-1432`). Spell lights: `h = (y − support_y)·abs(z.y)·ppu`, and the light is **off below its support** (`native_source_lights.gd:197-199`). |
| `N` | Environment: world normal × `world_to_canvas`, only when geometry is present, in packet, code > 0 and source normals are on, with ground join-mask flattening. Modular: `(n.x/scale_x, −n.y, n.z)`. Water: constant up. |
| `p` | Screen position of the receiving texel; receiver height 0 (`LIGHT_VERTEX = vec3(screen_px, 0)`). |

Also:
- **Directional lights** (`DirectionalLight2D`) have a live code path
  (`lighting_2d.gd:258-268,317-334,384-398`), although `world.json` lists none.
  Engine formula: `light_vec = normalize(mix(vec3(dir,0), vec3(0,0,1), height))`,
  no cookie, height 0..1; not counted in the per-item cap.
- **Per-item light cap, Forward+.** `MAX_LIGHTS_PER_ITEM = 16`
  (`renderer_canvas_render_rd.h`); lights are collected until 15, in list
  order, selected by `light_mask & item_mask`, z range and
  `item->global_rect_cache.intersects(light->rect_cache)`.
- **HDR light cap** (on by default): brightest-channel normalization of
  irradiance including ambient, a half-float intermediate, 8-bit quantize,
  sRGB decode. **Cap off:** per-channel clamp into RGBA8, then decode.
- **Unshaded receivers.** Flames (`canvas_fixture_flame.gdshader:2`) and
  shadow-role entries (`canvas_environment_unshaded.gdshader:2`) are
  `unshaded`: `canvas.glsl` skips the modulate and every light. Shadow passes
  are black through `source_unlit`/`shadow` (`environment_source.gd:57`).
- **No 2D shadows or occluders** anywhere (`shadow_enabled=false`,
  `lighting_2d.gd:231,262`; `native_source_lights.gd:41`).

**How.** Every placed instance (each floor tile, wall, prop, actor layer,
flame) gets a cell in an 8,192 × up-to-8,192 SubViewport. A canvas item
redraws the instance there at its real screen transform, with a group
material shared by (source material, visibility, water receiver, join mask).
The 3D output material of the instance then samples its cell. The atlas
re-renders every frame. A cap toggle, Normals toggle, rotation or window
growth rebuilds it.

**Per-instance CPU that exists only for the atlas:** classification and crop
scans; an output material per entry; spec records and support-owner maps;
shelf packing and region rewrites; group materials; a canvas item or Sprite2D
per receiver; projection packets and floor addresses; receiver records,
culling on every camera change, restyling on visibility changes. Per frame:
dynamic reprojection, ~1.5 ms material sync while moving, PointLight2D writes.

**The output material does more than lighting.** It also carries:
- decal receiver coordinates through `LIGHT_VERTEX`
  (`canvas_received.gdshaderinc:135-140`; `native_scene_support.gd:278-282,305-312`);
  decals read `light_vertex` even when unshaded;
- post-light body surfaces and native hit/body material (`:116-132`);
- the faded-wall mask test (`:80-95`);
- the Compatibility transfer inversion (`:42-58,133`);
- the texel addressing used by the actor depth proxies
  (`native_scene_support.gd:335-345,358`).

**The sprite shaders' own lighting is a different, 3D model.** Lambert/π in
linear space, with the light position taken from reconstructed source depth
(`environment.gdshader:142-171`; `modular.gdshader:77`). That path must not
be the template: the atlas lights each sprite as a **flat painted plane**,
and that plane is what gives the calibrated 2.5D look.

**Consumers of PointLight2D outside the atlas:**
- blood lit pages, sampled per screen pixel, ambient 0.18, always HDR
  (`blood_renderer.gd:79-85`; `blood_surface.gdshader:17`);
- native-source effect receiving, ambient 0.18, always HDR, with specular
  (`native_effect_receiving.gd:145-160`);
- Studio swatches (`thumbnail_cache.gd:421-438`; `blood_preview.gd`);
- spell preparation gating and trace evidence, which read
  `native_preparation_ready` and `effect_was_submitted()`
  (`component_renderer.gd:153,411`; `native_source_lights.gd:57-61`).

**Essential work.** Evaluate the same formula inside each sprite's own
shader:
- **Light table**, rebuilt each frame on the main thread from the existing
  `_canvas_sources` (the exact values the PointLight2D pages receive today,
  in screen pixels; N is small, so no worker and no dirty tracking). Rows of
  RGBA32F texels: light position and height, cookie centre and span, colour ×
  energy, cookie layer, kind (point; directional as kind 2). A CPU copy of the
  rows serves L4 dominant-light ranking and spell evidence.
- **Cookies** as layers of one `Texture2DArray`, filled from the retained
  GradientTexture2D images (the shadow code already retains them,
  `canvas_shadows.gd:226-245`), sampled nearest.
- Per pixel: snap to the source texel centre, compute its screen position from
  the quad's projection (`canvas_received.gdshaderinc:30-40` already does
  this), loop over the lights.

`shadow_composite.gdshader` shows the table pattern only; it evaluates cookie
× strength per screen pixel, with no N·L, height, colour, ambient or cap.

Per-instance data does not drop to zero: floors keep visibility and the join
mask per instance. The quad size used for the texel-to-screen mapping is a per
record constant (`source_quad_size`), not instance data.

**Parity traps to reproduce deliberately:**
- `render_mode unshaded`; otherwise the main WorldEnvironment ambient (0.18)
  is added on top;
- the receiver is the painted plane at height 0, never reconstructed depth;
- the multiply happens on the sRGB-encoded colour;
- the highlight is applied **before** lighting (`source_colour_environment.gdshaderinc:13`);
- water sheen per texel, not per screen pixel;
- modular layers snap to the **cell grid** (`entry.cell`), not the sheet
  texel grid;
- join-mask normal flattening for floors;
- cap on: brightest-channel, half float, 8-bit quantize, decode;
  cap off: LDR clamp; per consumer (atlas: HDR only with the cap; blood and
  effect pages: always HDR);
- cookies nearest, zero outside `[0,1)`, energy in `C.a·e`, cookie alpha as
  the blend weight;
- `max(0, N·L)` (the old spatial `abs` applies to walls and doors only);
- flames and shadow-role entries: no ambient, no lights;
- Normals mode omits shadow-role and flame entries, and hides generated
  shadows;
- the per-item cap of 15 lights (measure how many Gallery receivers reach it;
  per-instance light lists in ivec4 instance uniforms only if any does);
- the output responsibilities listed above move with the lighting:
  `LIGHT_VERTEX` for decals, body surfaces and hit material, wall mask,
  Compatibility inversion, depth-proxy addressing;
- door-leaf partition, selection masks and discards already live in
  `environment.gdshader:84-133`.

**Existing oracles.** All use native Canvas lighting as ground truth:
- `native_atlas_publication_checks` + `compare_atlas_captures.py` (27
  captures): an A/B that swaps atlas scripts (`--reference-atlas`), reads atlas
  receipts (`native_atlas_publication_checks.gd:56,58,179`) and passes only at
  zero byte error (`compare_atlas_captures.py:46`);
- `native_2d_source_checks` (reference canvas item lit by PointLight2D):
  exact on the GPU, ≤ 1 byte only for its CPU-rounding oracle (`:214-226`);
- `native_light_cap_checks` (CPU cap oracle; its actual side is atlas code,
  `:233,244`), `native_light_output_checks`, `native_demo_parity_checks`,
  light range, cap scene, floor lighting and cookie captures.

None of them can compare against a build without the atlas as is; L1's
harness (§4) replaces that role.

**Size.** About **4,000** lines can be deleted (`native_light_atlas` +
`native_light_delta` 3,380, canvas draw/batch 96, receiver shaders ~315, the
atlas stages of `world_preparation.gd` and `play.gd`). About **500** must be
ported (output logic, receiver-kind rules, normal rules). The light model
(`lighting_2d.gd`, `native_source_lights.gd`), the `source_colour_*`
includes (also used by blood and Studio), `ground_receiving.gd`, the cookie
preparation and the shadow cookie atlas stay.

## 2. Secondary rendering systems

The same anti-pattern appears in most of them: per-instance SubViewports,
nodes or materials, plus per-frame GDScript loops doing shader work. But each
also encodes **order or look semantics** that a merge would break. There are
17 runtime SubViewport creation sites (Studio and tests excluded).

| System | What it does now | What must be kept | Design (step) |
|---|---|---|---|
| **Actor drop shadows** (`canvas_shadows.gd`) | Per actor: own `World3D` SubViewport, OmniLight3D with cube shadows (`shadow_blur` 1.5), 2,048² positional shadow atlas (`:15,522`), ground plane, composite quad. Caster grids rebuild a **per-texel relief** from the depth packets (`shadow_caster.gdshader`, height scale 0.5, view-axis slide, feet anchored). Composite `0.839·blocked·c_d²·s_d/Σ c_i·s_i`. CPU dominant-light ranking reads cookie Images (`:324-343`). Every frame, 4 `set_shader_parameter` calls and a deep key compare per actor (`:136-142`); a `frame_uv` write and a re-render per animation frame (`:600-603,647`). Viewport resizes cost 1–6 ms. All shadow passes together: 0.26 ms GPU. | The relief casters, the soft shadow test, per-actor painter slots (role "shadow" at the actor key), dominant light from cycle-mean energy and rank fields, with the bilinear cookie score (max channel × alpha) and the strict-`>` tie rule in source order. | L4 |
| **Native-source effects** (`native_effect_preview.gd`, the live presenter used by `component_renderer.gd`; `native_effect_receiving.gd`) | Per occurrence: own `World3D`, 2–14 SubViewports; each output a lighting page duplicating every PointLight2D. | Off-screen composition: the palette is applied to the composite, and the fade to the whole effect. | L7: one composite target per active occurrence, lit by the shared loop (ambient 0.18, always HDR, specular). |
| **Blood** (`blood_renderer.gd`) | Per stained tile: a 64² SubViewport, two mesh nodes, two materials, a painter entry. Two full-screen HDR lit pages (ambient 0.18, per screen pixel). Droplets integrated in GDScript, with `GridOrder.key` per particle per frame (`:484-487`). | Stain lighting (ambient 0.18, per screen pixel, HDR), stain painter order, droplet painter buckets with back/front halves. | L6: one field atlas for stain slots; stains stay their own ordered draws lit by the shared loop; droplets keep buckets and halves. |
| **Spell layers and depth support** (`native_effect_layer.gd`, `native_scene_support.gd`) | Up to 12 full-screen 3D SubViewports (one per finish profile) plus a support pass, all in the main `World3D`. They stop updating when idle (`native_effect_layer.gd:51`) but keep their render targets. | Decals project onto the painted main world (`cull_mask=1`, `native_factory_source.gd:153-156`). | L7: stay in the main world; render targets shared between profiles that are not active together, their VRAM listed; per-piece uniform writes gated; cull masks checked. |
| **Wall fading mask** (`play.gd` `_sync_wall_mask`) | Full-screen SubViewport, one ColorRect per wall, `UPDATE_ALWAYS` in translucent mode (`play.gd:3047-3048`: `UPDATE_ONCE` left the first mask stale in the Compatibility regression). Ids are 24-bit draw-order indices among walls. | "Only the front-most faded wall shows": ids must increase with painter order. A depth buffer or plain stencil is not equivalent for translucent surfaces. | L1: ids = static rank + 1; render on change, with the stale-mask regression as its test. Dozens of walls: no further redesign. |
| **Ground overlay** (`ground_overlay.gd`) | Mostly batched by style; raised tiles get a node each; a ShaderMaterial per route half (`:496-511`); `sync` every frame (`play.gd:2836-2838`). | Route halves per tile interleave with sprites. | L3: routes are static participants re-keyed only when the route changes; one shared material with `line_from`, `line_to` and colour as instance uniforms; in the order oracle's scope. |
| **Hit flashes and outlines** | A 256² own-world SubViewport per hit; a 2D SubViewport per outlined actor. | Hit material is post-light output work (moves with L1). | L7: shader effects on the sprite. |

## 3. Actors and the world/media pipeline

### Actors

**Essential.** A modular actor is 6–10 layers (up to 21). Each layer-clip is
a colour sheet plus **5 companions** (depth, normals for the selected
profile, support, normal_valid, solid-valid). All are 1920×1024: 15 frames ×
8 facing rows of 128² cells (`rig.facing_rows`). Colour, depth and normals
are RGBA8 PNGs (7.5 MiB each in VRAM); the masks are L8 (1.875 MiB each),
uploaded without conversion (`media_warmup.gd:1200`).

Per frame per layer: frame = wrap or clamp of `int(source_seconds·fps)`, where
the source time comes from `Tracks.samples` (time keys, holding pose),
terminal or condition-pose clocks, or effect-layer clocks; plus facing row,
position and painter position. Non-looping clips hold the last frame
(`play.gd:2706`).

**Actual, per actor with L layers.** About 35 nodes for L = 8 and 3L+2
materials: L MeshInstance3D with own QuadMesh and ShaderMaterial (72
uniforms) plus a per-entry uniform-name copy; L atlas receivers and output
materials; Playback, AnimationPlayer and AnimationTree; the shadow viewport
set with L casters.

Per frame: `Characters.rest_sample`, condition dictionaries (deep-compared), a
20-element pose key; an **AnimationTree seek with a string-built property
name** whose result is only the wrapped or clamped time (`graphs.gd:197-215`;
no blending, events or root motion in live play); per layer `frame_uv`,
palette, condition apply, bounds and transform; atlas restyle and copy; a
shadow re-render. The geometry rebind runs only when clip, profile or scale
change. `actor_samples()` runs twice per frame (§3 Timeline).

**A clip change is treated as a world boundary** (`compiler.gd:546-616`,
`timeline.gd:388-394`). The binding math is ~30 lines
(`character_geometry.gd:67-94`), but the cut also exists because:
- clip descriptor Resources may be loaded only on workers; sampling must
  never call ResourceLoader (`body_sources.gd:47-113`);
- the full sheet bundle must be resident before the clip edge, or the layer
  is hidden and a media error raised (`play.gd:2724-2743`). The bundle is six
  textures, the CPU Image, and the solid optical mask used by spell depth
  support;
- per-sheet operands (depth range, optical origin, elevation, cell, ground
  pixels) and the AABB expansion.

**Instance uniforms have limits.** Scalars and vectors only (no textures,
arrays or matrices), at most 16 per shader. Each instance reserves as many
slots of a global buffer (65,536 by default) as its shader declares; at 3–6
slots that is ~10–20k instances, raisable with
`rendering/limits/global_shader_variables/buffer_size`. Colour-typed values
are linearized, so parity values go as `Vector4`.

Modular materials hold per-actor **arrays and samplers** (effect and flash
palettes, condition film, body surface ramps and textures) that change with
conditions. Palettes are raw `uniform vec3 x[32]` with no colour hint
(`character_material.gdshaderinc:6,19,31`), so an RGBA32F row returns the
same floats. The ~25 condition scalars belong to the actor, not the layer.

**Design (L5).**
- **Cell map.** Modular layers sample through a cell map: instance uniforms
  `cell_map` (packed offset, page layer) and `cell_box` (box in the cell).
  Until L8 the map is the identity over today's sheets; after L8 it points into
  packed pages. The shader does not change at L8. The cell texel is derived
  as today (`floor(sheet_uv·sheet_size) − cell origin`), not `floor(UV·128)`.
- **Per-sheet optics** (depth range, optical origin, elevation, cell, ground
  pixels) as 2 vec4 instance uniforms, written at a clip change.
- **Actor table.** Per-actor values (condition scalars, flash values, palette
  row and count) in one RGBA32F row per actor (`global uniform`); layers carry
  `actor_slot`. Palettes are rows of an RGBA32F palette table. Material
  variants remain only for the condition samplers (`effect_noise`,
  `flash_noise`, `condition_film`), and only while a condition is active.
- **Clock.** Keep the `Tracks` source time; wrap or clamp from
  `character_loops`; no AnimationTree for live actors. Fixture flames keep a
  continuous `t·fps` (they smoothstep energy and optical height between
  frames). The workshop destruction state machine keeps its tree.
- **Sampling once.** `actor_samples()` runs once per frame and writes the
  actor table.
- **Clip change** = instance writes. The bundle (textures, pick data,
  worker-admitted descriptor, palette ranges, AABB) is resident beforehand:
  residency = displayed bundles + bundles scheduled within look-ahead `H`
  (measured worst decode + upload of a bundle plus one frame) + the reactive
  clips (TakeDamage, Die, …) of every visible actor (the run demanded 15
  TakeDamage and 15 Die sheets). No world cut, no hold.

### World preparation

**Essential.** For each new or changed row: textures, transform, uv rect,
per-identity visibility, painter position, material key. One row yields
several entries: the shadow pass, three door passes, hidden wall members. The
door reveal is 1,003 placements and 1,156 entries
(`REVEAL_LATENCY_DECOMPOSITION_2026-10-16.md:65`); its packet arrives about
240 ms before the cue (`CLIENT_STRUCTURE_PROGRESS_2026-10-17.md:490`). Also
essential and currently inside the step machine: blood world preparation, the
native spell receiver boundary, scenery visibility, light-source and cookie
resolution, wall geometry views, ground support, the blood index.

**Actual.** Each static sprite gets a worker-built ShaderMaterial (51
uniforms set one by one), a QuadMesh, a crop scan and an atlas packet, then a
scene-thread MeshInstance3D and atlas adoption. Each floor row gets an atlas
spec, receiver record, canvas item, projection packet and join mask. The step
machine adds construction lanes, atlas stages, one-item-per-iteration
membership/retirement/scenery loops, order collect/sort/publish/release,
cookie waits and identity proofs. Entries are Dictionaries with 79 distinct
fields across `play.gd` and `presentation/*.gd`; order, wall mask and picking
walk them and read `entry.node.*` (`play.gd:2853-2931,2969,3000-3029,3632`).

**Prior art.** `grid_renderer.gd` and `tools/compile_grid.gd` (workshop
exploration path, `main.gd:217-220`) already render statics as data: a
per-record RGBAF table (`compile_grid.gd:170`), a per-instance RGBAF table
(`:137`), an R8 per-row state texture (`grid_renderer.gd:13`;
`grid.gdshader:36-38`), Texture2DArray pages, packed keys searched with
`Order.insertion` (`grid_renderer.gd:90`), and painter-sorted MultiMesh blocks
split at actor insertions. L1 reuses its state texture and packed keys.

**Design (L1, static renderer pass).**
- **Floors:** background floors only (height 0, terrain role, no negative
  elevation on the map; `terrain_batches.gd:21,30`) stay per-texture
  MultiMesh, drawn in buffer order. Custom data = (identity slot, join mask,
  0, 0), so sight changes never rewrite the buffer. All other floors are
  individual instances.
- **Everything else:** one RenderingServer instance per entry (no nodes):
  `instance_create2` with the record's mesh, transform, material override,
  custom AABB, `instance_set_pivot_data(rid, offset, false)`, instance
  uniforms. One QuadMesh per record, shared by its instances (the shaders read
  `mat3(MODEL_MATRIX)` and `source_quad_size`).
- **Material key:** (record, source role, shader variant, quarter, row
  orientation for object-local geometry). `local_to_world` carries no
  translation (the shader cancels it with the instance origin,
  `environment.gdshader:147`); `local_normal_to_world` depends on the
  orientation (`environment_source.gd:78-90`). Selection inversion, unlit and
  door partition follow from the source role (`environment_source.gd:42-47,55-57`)
  and are material constants.
- **Instance values:** `inst_tint` (Vector4), `inst_a` = (wall opacity,
  wall-mask id, door frame depth, flags), `identity`.
- **Identity table:** one byte per identity in an R8 global texture (bit 0
  visible now, bit 1 highlighted). Every entry of an identity carries the same
  slot, set once. Visibility stays **per identity**: tiles by their cell,
  boundary objects by either incident cell, other objects only by server
  grants (`world.gd:444-525`). A sight change is byte writes and one upload;
  hover is one global (the hovered identity).
- **Reveal:** the worker builds the instance list (packed added slots,
  removed slots, change triples, new order). The main thread creates the
  instances **hidden** during the packet→cue window, inside the per-frame
  allowance; they include the join-mask updates of floors already shown
  (`ground_receiving.gd:19-27`). At the cue only the identity texture changes
  (one upload).

### Media and VRAM

**By format.** A layer-clip is 3 × 7.5 MiB (RGBA8 colour, depth, normals) +
3 × 1.875 MiB (L8 masks) = **28.1 MiB**; an actor with L layers costs
28.1·L MiB per clip (225 MiB at L = 8). Texture sharing already works
(textures are keyed by path, `play.gd:2478`); the run's traces name 22
distinct modular Idle colour sheets in 19 layer folders, so the Gallery's
idle actors share some layers (`NakedBody`). CPU Images add 2.4 GB of RAM.
The corpus is ~59k PNGs, 5.9 GB on disk, outside the project
(`source_data/media_root`).

**Render targets**, from code (bytes to be measured):
- light atlas 8192 × H, RGBA16F when capped: ≈ 159 MiB at 20.9 Mpx
  (`native_light_atlas.gd:101,134`); RGBA8 with the cap off;
- per actor a 2048² positional shadow atlas (`canvas_shadows.gd:15,522`) plus
  its shadow viewport;
- two full-screen HDR blood pages and a 64² viewport per stained tile;
- up to 12 full-screen 3D spell-profile viewports plus the support pass;
- the full-screen wall mask;
- 2–14 viewports per effect occurrence;
- the main viewport.

The profile's linear fit (VRAM ≈ 122 MiB + 5.57 MiB per resident texture) is
a cross-check only: its intercept is below the light atlas alone.

**Why the current budget code cannot hold a consumer budget:**
- it counts CPU bytes plus a `w·h·4` GPU estimate (also for grayscale), not
  real GPU bytes, and excludes render targets;
- pinned demand (wanted + selected preload) is never evicted; with budget 0
  a route still loads everything required, and a small budget only disables
  prefetch, which brings holds back;
- eviction does not free VRAM while textures are still referenced: prepared
  bindings, shadow casters, `solid_masks`, wall-mask materials, cached quarter
  views and atlas group materials all keep them;
- LRU is touched only for actor colour sheets, by path, every frame
  (`media_warmup.gd:1451-1453`);
- eviction is per path, but one missing companion hides the layer.

`BUDGET_BYTES` (16 GiB) is test-only; the runtime reads
`source_data/encounter_cache_mib` (16384, overridden in Studio). Unit tests
and one budget-0 route test exist; in the Gallery, optional selection already
binds at 16 GiB (1,910 selected, 1,125 skipped) but nothing is ever evicted.

**All 8 facing rows stay resident** (user, 17 October): many animations
change facing dynamically, and camera rotation uses the other views. A sheet
bundle is the smallest residency unit.

**The sheets are almost empty.** Colour alpha of all 132 modular layers,
clips Idle, Walk and Attack1 (387 sheets, `tools/sheet_coverage.py`):

| | Visible pixels | Per-cell tight boxes | Cells with pixels |
|---|---:|---:|---:|
| One layer (mean) | 0.6% | **2.0%** | 91% |
| Body (`NakedBody`) | 1.6% | 5.8% | 100% |

Depth and normals share the colour footprint (checked on Chest1/Idle). About
98% of the VRAM spent on modular layers holds transparent texels; every cell
is used, so the waste is inside the cells.

**Crop and pack (L8, lossless).**
- **Box** = colour alpha > 0 per cell. Every reader checks colour alpha
  before reading a companion (`modular.gdshader:32`, `canvas_modular.gdshader:36`,
  `shadow_caster.gdshader:25,51`, `native_scene_support.gdshader:29`,
  `surface_sockets.gd:48-49`). Widened only where a measured consumer reads
  outside it. No padding: every sheet sampler is `filter_nearest`, and a box
  test plus `texelFetch` returns transparent outside.
- **Pages:** one `Texture2DArray` per companion format with identical layer
  indices; small fixed layers (e.g. 256², from the histogram of packed bundle
  areas). Each bundle owns its own k layers; no layer is shared, so there is
  no runtime packing, no fragmentation and no sub-rectangle upload (Godot
  scripts only replace whole layers). Load = k `update_layer` calls per
  format; evict = return the k layers to a free list.
- **Cell table:** per bundle, 120 cells × (`cell_map`, `cell_box`); the
  instance uniforms of L5.
- **Consumers** that must use the same mapping (one `packed_texel` function in
  GDShader and GDScript): `modular.gdshader` (including `:69`), the shadow
  caster's clamped neighbour taps (`shadow_caster.gdshader:19-26`),
  `native_scene_vertex.gdshaderinc:36-39`, `native_scene_support.gdshader:26-28`,
  body-surface `normal_uv` (`canvas_received.gdshaderinc:118`), actor picking
  (`play.gd:3797-3800`), surface sockets (`surface_sockets.gd:31,48,90-92`),
  condition-outline regions (`condition_outline.gd:72-74`), Studio thumbnails
  (`thumbnail_cache.gd:309-316`), and palette ranges, which read the original
  file (`palette.gd:59-75`) and are precomputed by the prepack.
- **Ratio:** ~25–35× less VRAM for an 8-layer actor including packing loss
  (`NakedBody`, in every actor, gains ~17×); the prepack reports the measured
  ratio per bundle. Fewer texels to decode and upload by the same factor;
  disk bytes shrink less, because PNG already compresses empty texels.
- **Prepack step** ("moving the media"): converts the referenced media into
  pages, cell tables, pick bits and palette ranges in a git-ignored cache that
  the worker loads directly. Importing the raw corpus through the Godot
  importer is not proposed: it would duplicate 5.9 GB into `.godot/imported`
  and keep the empty texels.
- Rejected: baking an actor's layers into one sheet, because it changes
  per-layer tint, conditions, edge lighting, shadow relief and layer order.
  Lossy GPU compression is not needed unless the packed set is measured over
  budget.

**Residency (L8).** Bundles have integer ids from the prepack manifest. The
pages are the budget. Demand = bundle ids displayed now or within the L5
look-ahead, recomputed when the timeline changes, not per frame; the LRU stamp
is the last time a bundle was in demand; eviction is a linear scan among
undemanded bundles when the free list is short. Modular media hold no
`Texture2D` references, so "drop every reference" holds by construction.
Environment records (varied sizes) keep per-record textures with real bytes
and a live-instance refcount from the static table, freed at 0.

**Budget.** The user's requirement is "less than 4 GB". Our derived target is
**2.5 GiB for textures plus render targets** (a 4 GB card minus ~1.5 GiB for
compositor, driver and engine). If the resident set exceeds it, the route
fails the gate; it never holds.

**CPU Images** are dropped after upload except pick bits and compact socket
samples (both from the prepack, in the packed layout). The display gate is
bundle residency.

### Draw order

**Every sprite shader turns depth off** (`depth_draw_never,
depth_test_disabled`, line 2 of the sprite shaders). Order is a CPU painter
sort: `grid_order.gd` keys compared by a GDScript loop, binary-search merges
into ~460 statics, per-frame keys for visible actor layers, full re-ranking on
reveals and rotations. Statics already get dense ranks (`play.gd:2907`) and
actors fractional ranks between them (`:2912-2919`). The result is written as
`sorting_offset = rank·8 + forward·origin` (`play.gd:2967-2977`).
`render_priority` is unused by world sprites; markers and labels set 127
(`main.gd:111`, `component_renderer.gd:283`) and Studio's blood preview uses
it (`blood_preview.gd:34`).

**What the engine sorts.** For an orthographic camera Godot sorts alpha
instances by priority, then by depth `near_plane.distance_to(origin) −
sorting_offset` (`render_forward_clustered.cpp`, `_fill_render_list`; origin
because every participant sets `sorting_use_aabb_center=false`). The
`forward·origin` term cancels the distance, leaving `−rank·8` plus float32
rounding. The sort is an unstable introsort: equal values draw in arbitrary
order and can flicker.

**Per-pixel depth is not an option.** Each asset's depth is relative to its
own optical camera ("45 and 30 degree elevations", a "provisional optical
convention … never changes its geometry/Z/order",
`character_geometry.gd:162-163,181`). The door partition is an authored
painter depth, the wall mask enforces "front-most faded wall only", and
shadow entries are a role band: these are semantics, not depth workarounds.

The key (`grid_order.gd:4-21`):
- background floors first (`ground_background` is global), keyed by
  `row.layer` in slot 1 and 0 in slot 2;
- owner cell `round(pos + 0.489921)` after quarter rotation (biased);
  diagonal x+y, then x−y;
- height (`sort_height_steps` when present; a lerped float for moving actors);
- role, contact y, layer (`layer·10 + {0,1,2}`, flame 100, generated shadow −1);
- tall objects by `sort_position`;
- exact ties by id string (`play.gd:2964-2965`).

The key needs ~30–55 bits; float32 has a 24-bit significand, so it cannot be
one scalar. Participants: sprites, door passes, hidden wall members, flames,
ground overlay routes, blood stains and droplets, generated actor shadows.

**Where the cost is.** Per frame: `ground_overlay.sync` (`play.gd:2836-2838`),
an `Order.key` Array per visible actor layer (`:2887`), `filter` +
`sort_custom` (`:2895-2896`), a Dictionary-comparator binary search
(`:2943`), and `_apply_draw_rank` reading `node.global_position` per entry
(`:2969`). On a reveal: a main-thread `sort_custom(_entry_before)`
(`:2863-2864`) and the per-entry rank walk. Not the number of offsets written.

### Timeline

Per frame `actor_samples()` runs twice (`play.gd:663`, `timeline.gd:630`)
and duplicates active tracks; `component_samples()` duplicates active
components; `presentation_state()` copies state and tiles while staged tiles
exist, sometimes inside per-sample loops. Measured `displayed_samples`:
~0.25 ms/frame. L5 samples once per frame.

## 4. Replacement plan

This replaces Stages 1–2 of
[the 16 October plan](CLIENT_STRUCTURE_AND_NATIVE_DATA_PLAN_2026-10-16.md)
for rendering and preparation. Its user decisions carry over: no legacy
runtime paths; no new Factory content before the gate; native data for spells
and conditions.

**Rules for every step.**
- **The picture does not change.** Each step is proven against native-Canvas
  or current-code references before the old path is deleted; any remaining
  difference is shown side by side to the user.
- **Data model.** Per-instance state is packed arrays indexed by integer
  slots, owned by the one script that runs the step (statics and order: the
  static renderer; lights: `lighting_2d.gd`; residency: the media script). No
  per-instance Dictionary, Node, Mesh, Material or RefCounted; no Manager,
  Registry or Handle classes. Cross-step references are integer slots or ids.
  String-keyed Dictionaries only at world-change or catalog-load time.
- **Room-wide values are `global uniform`s** set with
  `RenderingServer.global_shader_parameter_set`: the light table, light count
  and cookie array; ambient and cap mode; Normals and source-depth toggles;
  wall mode and the wall-mask texture; water time; the hovered identity and
  the identity table. A toggle is one global write, never a material walk or a
  rebuild.
- **Priority (user, 17 October): speed first.** L1–L7 are judged on frame
  time and pauses only. VRAM is L8, after them; nothing in L1–L7 is gated on
  it.

**One static pass instead of three steps** (decision, 17 October, after the
user asked whether doing everything in the same pass makes a proper system).
Lighting, instances and static order touch the same entries, materials and
shaders; changing them in three passes would rewrite each twice. The former
L1 (lighting), L2 (instances and materials) and the static half of L3 (static
ranks) are therefore one pass, L1 below. L2 no longer exists as a separate
step; L3 keeps only the moving participants.

| # | Change | Deletes | Gate |
|---|---|---|---|
| L1 | **Static renderer pass.** Static sprites (floors, walls, props, doors, water, flames) move in one go to the final data model: shaders lit from the light table (§1), shared materials per record, RenderingServer instances, the identity texture, dense static ranks from a worker sort with the same comparator, wall-mask ids from those ranks (§3 World preparation and Draw order). The room is built in the background during the packet→cue window and shown at the cue by an identity-texture flip. Actors get the new lit modular shader on their existing nodes in the same pass, so the atlas is deleted entirely; their data model stays for L5, and they keep today's per-frame insertion against the new static ranks. The output responsibilities move into the sprite shaders; spell evidence comes from the light table's CPU copy; the sprite shaders gain the identity cell map of L5. Blood, effect-receiving and Studio pages keep their PointLight2D until L6/L7. | The light atlas, planner, receivers, output/receiving materials and atlas stages (~4,000 lines; ~500 ported); per-entry nodes, meshes, materials and uniform ledgers for statics; construction lanes, slicing, membership/order/retire loops, identity proofs; main-thread static sorts and re-ranking on reveals; per-frame wall-mask renders | See L1 notes |
| L3 | **Moving participants** (§3 Draw order): one flat list for actor layers, generated shadows, droplet halves and overlay routes; per-actor key prefix recomputed only on change; one binary search per actor against the static ranks. | Per-frame overlay sync, per-layer Array keys, filter/sort per frame | Engine-key order oracle (exact) over moving participants, then captures; `draw_order` ≤ 0.1 ms on idle frames |
| L4 | **Shadows: same look, no idle CPU.** Keep the per-actor relief casters and soft shadow test. Fixed viewport sizes (no resizes); dominant light ranked from the table's CPU copy with today's bilinear score and tie rule; re-render only when actor frame, position or light changes. | CPU cookie readback, resizes, per-frame parameter writes and key compares | Shadow oracles unchanged; idle actor: 0 shadow writes; animating: 1 write + 1 render per changed frame. Switch to a main-pass projection of the relief if shadow GPU > 1 ms or shadow VRAM > 64 MiB at 20 actors. |
| L5 | **Actors** (§3 Actors): RenderingServer instances on the L1 model, cell map, per-sheet optics, actor and palette tables, integer clock, sampling once, bundle residency with look-ahead. | Actor nodes and per-layer materials, AnimationTree for live actors, per-frame pose dictionaries, the SourceMaterial ledger, source-only world cuts, the second `actor_samples()` | Actor captures; ≤ 1 write per layer per changed frame, 0 for unchanged actors; six-actor actor work ≤ 0.3 ms; clip changes with no pause |
| L6 | **Blood.** Field atlas; stains as their own ordered draws lit by the shared loop (ambient 0.18, per screen pixel, always HDR); droplets keep buckets and halves. | Per-tile viewports, lit pages | Blood oracles (Pygame reference within .008) |
| L7 | **Effects.** Native-source effects: one composite target per active occurrence, lit by the shared loop (ambient 0.18, always HDR, specular). Spells stay in the main world, profile render targets shared and listed, per-piece writes gated. Hit flashes and outlines as sprite shader effects. | Duplicated light pages, per-occurrence viewport sets, per-hit viewports | Spell/effect captures |
| L8 | **Media and VRAM** (§3 Media): prepack crop-and-pack into per-bundle page layers, integer bundle ids, demand from the timeline window, real-format budget including render targets. | Role/family/selection accounting, per-path LRU touches, CPU Images | 0 holds and measured `video_memory_mib` ≤ 3.0 GiB at the 2.5 GiB budget on the Gallery, door, movement and Fireball routes; resident set reported per route; over budget fails, never holds |

**L1 notes.**
- **Stage 1: light math in isolation.** The table loop is validated against
  native PointLight2D before any pipeline change: reference scenes with a
  canvas item lit by PointLight2D (as `native_2d_source_checks` does), and an
  in-frame comparison of table irradiance with the atlas's irradiance in the
  output shader (a global `light_from_table` toggle, same frame). RGB ≤ 1
  byte (float operation order), alpha exact or ≤ 1. Two named exception
  classes are reported, not hidden: texel choice through atlas-address
  rounding (`source_atlas_uv.gdshaderinc:1-7`) at isolated pixels, and
  nearest-cookie boundary flips.
- **Stage 2: both pipelines in one build.** The old pipeline (atlas, nodes,
  per-entry materials, main-thread order) and the static renderer pass coexist
  behind one switch until parity: same journal, same frame, byte compare, on
  the Gallery, door, movement and Fireball routes in all four quarters, wall
  modes, cap on/off and Normals. Then the old path is deleted and those
  captures become the reference for later steps.
- **Light cap.** Count how many Gallery receivers reach 15 lights. If none,
  the loop sums all lights; otherwise per-instance light lists reproduce it.
- **GPU gate.** Main-pass GPU measured with the route's light count N and the
  maximum lights reaching one texel M. Screen-tile light lists only if more
  than ~16 lights can reach a pixel.
- **Order oracle (static half).** As in the L3 notes, over every static
  participant, before the old order path is deleted.
- **Door gate ("no pause").** Spike first: create the door's instances on the
  main thread, measured. Then: from packet to cue + 10 frames, no frame
  interval above one refresh period; reveal work in the cue frame ≤ 0.5 ms;
  the room visible in the first frame whose display time ≥ the cue; captures
  identical.
- **Oracle ports.** The existing light oracles' "actual" side is re-pointed
  at the sprite shaders; native-Canvas reference scenes stay as test oracles.

**L3 notes (order, both halves).** The user's caution (17 October): it is
very easy to render assets out of order and break the perspective.
- **Keep the key and the comparator exactly**, with the id tie-break.
- **Statics (L1):** on every world change, quarter change or
  `ground_background` flip, the worker sorts the static participants (packed
  keys, same comparator) and assigns **dense ranks** 0..n−1. The publish frame
  writes every static's offset (`instance_set_pivot_data`, n ≈ 460, measured
  in the L1 door spike). Wall mask ids = rank + 1 (24 bits fit); the mask
  re-renders on reveals and wall-mode changes.
- **Moving participants (L3)** (actor layers, generated shadows, droplet
  halves, overlay routes) are one flat list. An actor's key prefix (slots 0–5)
  is recomputed only when its position, height or quarter changes; one binary
  search per actor with key-then-id comparison (`grid_order.insertion` gains
  the id tie-break); its layers share that insertion unless a static key falls
  between its first and last layer. Entries landing in the same gap are sorted
  among themselves with the full comparator. Rank = ins − 1 + (j+1)/(m+1), as
  today (`play.gd:2917`). Idle actors cost nothing. Until L3, actors keep
  today's insertion against the L1 ranks.
- **Engine-key oracle** (before each switch): evaluate, in float32 as the
  engine does, `near_plane.distance_to(origin) − f32(rank·8 + forward·origin)`
  per participant; it must be strictly decreasing in today's key+id order, for
  every Gallery and Studio scene (including Studio's `render_priority`) in all
  four quarters, plus negative-elevation maps, mid-move actors (fractional
  position and height), passage and lift, exact actor/static ties, door
  three-pass entries, hidden wall members, `sort_position` objects, flames,
  overlay routes, blood and generated shadows. Bounds: `|sorting_offset| ≤
  2^20` (one float32 step is 0.125 there) and adjacent offsets at least 1.0
  apart; with dense ranks n ≤ 4,096 and actor spacing 8/(m+1) ≥ 0.125 for
  m ≤ 63.
- **Instancing:** a transparent MultiMesh sorts as one object and draws its
  instances in buffer order, so a painter-sorted buffer is order-exact
  (background floors rely on this). Other statics stay single instances:
  reveals stream records of varied sizes, a moving participant inside a block
  would split it, and draw submission is not the cost (render thread 0.47 ms,
  main GPU 0.24 ms).

**Steady targets.** Idle script ≤ 2 ms including media work; main-thread
media ≤ 0.5 ms per frame always; animating script with six actors ≤ 3 ms.

**Reveal target.** As the L1 door gate: no frame interval above one refresh
from packet to cue + 10 frames, the room visible at the cue.

**Open user decisions.**
- The workshop exploration path (`grid_renderer.gd`, `tools/compile_grid.gd`,
  `main.gd`): keep or delete under "no legacy runtime paths".
- The directional light path: keep (table kind 2) or delete with the atlas;
  `world.json` has none today.
- Lossy GPU compression: not planned; only if the packed set is measured over
  budget.

**Earlier work.** It stays in history. The atlas-specific changes (planner
groups, support capture, worker group materials) disappear with L1. The
general fixes stay valid: GPU readback avoidance, shader warm-up, protocol
parse, blood/support skips, light-plane sizing.

## 5. Verification record (17 October)

Corrections from the three adversarial verifications, all spot-checked in
code:

| First draft said | Code shows | Effect on the plan |
|---|---|---|
| Shadows as flat planar projections | Per-texel relief casters (`shadow_caster.gdshader`) | L4 keeps the relief and the soft test |
| Spells in their own World3D | Decals project onto the main world (`cull_mask=1`) | Spells stay in the main world |
| Blood stains inside the terrain shader | Ambient 0.18, per-screen-pixel lighting, own painter order | Stains stay their own draws |
| Merge droplets, routes, shadows into single draws | Per-cell and back/front halves interleave with sprites | Kept split |
| L1 removes all PointLight2D | Blood, effects, Studio and spell evidence use them | L1 removes only the atlas page lights |
| The output material only lights | Decals, body/hit material, wall mask, depth proxies | Ported in L1 |
| Use the sprite shaders' lighting | It is a 3D Lambert/π model from reconstructed depth | Flat painted plane only |
| One light parameter set | World, spell and directional lights differ | Light table has kinds |
| Zero-tolerance gate | GPU oracles are exact; 1 byte only for CPU rounding | ≤ 1 byte, a new decision, with named exceptions |
| ~5,000 lines deleted | ~4,000 deleted, ~500 ported | Corrected |
| One exact float scalar per sprite | ~30–55 bits needed; unstable engine sort | Ranks + same comparator |
| Write `DEPTH` from depth packets | Per-asset optical cameras | Removed |
| `render_priority` orders painters | `sorting_offset = rank·8 + forward·origin` | Corrected |
| Per-cell sight texture | Visibility is per identity, by server grant | Identity table |
| One material per texture with instance uniforms | 16-slot limit, no arrays/textures/matrices | Per (record, role, shader, quarter, orientation); cell map and tables for actors |
| `floor(t·fps) mod n` | Clamp for non-looping clips; source time from Tracks | Wrap or clamp from `character_loops` |
| Clip change = texture swap | Needs the six-texture bundle, pick data, descriptor | Bundle residency with look-ahead |
| 6.2 GB from textures and render targets | Grows to 8.4 GB while the preload fills | Media residency is the VRAM problem |
| Budget logic never exercised | Tests exist; nothing is ever evicted in routes | Eviction by structure (page layers) |

Plan reviews (same day), all "approve with changes":

| Review | Main corrections applied |
|---|---|
| Correctness (engine 4.7.2 sources) | Oracle on the engine sort key, not `sorting_offset`; cookies nearest with the native energy/alpha rule; flames and shadow roles unshaded; Forward+ cap of 15 lights per item; harness work listed with exception classes; per-bundle page layers instead of shared pages; consumer list for packed sheets; colour-alpha box, no padding. |
| Anti-slop | VRAM by format with render targets listed; regression as cross-check only; exclusive media time and unattributed script time; numeric steady targets; reveal gate on the packet→cue window with a cue-frame visibility flip; L4 thresholds; L1 citations fixed; L5 gate numeric; orphan analysis assigned to steps; "legacy" renamed. |
| Data-oriented | Packed-array data model rule; global uniforms for room-wide values; RenderingServer instances with per-record meshes and a complete material key; identity table; dense ranks; one moving-participant path; actor and palette tables; integer bundle residency driven by the timeline window; `grid_renderer` cited as prior art. |

After the reviews, L1, L2 and the static half of L3 were merged into one static
renderer pass (§4), verified with both pipelines in one build behind a switch.
