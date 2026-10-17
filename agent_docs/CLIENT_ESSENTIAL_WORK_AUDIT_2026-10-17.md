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

Method: three read-only studies, then three adversarial verifications of
every claim against the code (lighting; secondary systems; actors, world,
media, draw order and VRAM). The verifications corrected several proposals
that would have broken the 2.5D look; §5 lists them.

### Measured state (Gallery, run `20261017T0420`)

| | Value |
|---|---:|
| GPU time per frame, measured viewports (main 0.24, light atlas 0.21, shadows 0.26; blood, spell and support passes not measured) | **~0.7 ms** |
| Render-thread CPU | 0.47 ms |
| Player script time, "idle" frame | **8.4 ms** |
| of which optional media work still running (inclusive phase timings, may nest: `optional_preparation` 1.29, `media_publication` 1.10, `media_optional_maintenance` 0.84, `media_optional_selection` 0.51) | ~1–4 ms |
| of which `draw_order` | 1.12 ms |
| Frame interval | 11.8 ms |
| Draw calls / render objects | 508 / 1,098 |
| Static painter entries | ~460 |
| Light atlas | 538 receivers, 20.9 Mpx |
| Video memory | 6.2 GB at 12.5 s (1,084 textures), **8.4 GB at 22.3 s (1,454 textures) and still rising** |

The frame is script bookkeeping. GPU time is under a millisecond across every
measured viewport (`gpu_ms` covers only the main viewport, so each SubViewport
is read separately). The "idle" frame is not idle: the optional preload is
still filling a 16 GiB budget.

Video memory follows **≈ 122 MiB + 5.57 MiB × resident textures** over the
whole run. Render targets do not show above that trend: VRAM is media.

## 1. Lighting: the 2D light atlas

**What it computes.** Screen-space 2D point lighting per *source texel*,
with native Canvas lights and no custom `light()`
(`canvas_environment.gdshaderinc:2-4`):
`out = S·A + Σ S·T·C·e·max(0, N·normalize((P,h) − (p,0)))`.

| Symbol | Meaning |
|---|---|
| `S` | sRGB-encoded source colour (white when storing irradiance). The capped output samples the colour without the `source_color` hint, so values are used as encoded. |
| `A` | Ambient **0.30 numerically in both HDR and LDR** (the code pre-encodes it so the engine conversion lands on 0.30, `native_light_atlas.gd:110,123-125`). Blood and effect pages use **0.18**. |
| `T` | World lights: 256² radial profile cookie, elliptical with the camera (`scale.y = abs(cam.z.y)`), centred on the projected **support** point (`lighting_2d.gd:78-104,361-378`). Spell lights: a 65-stop attenuation cookie, circular, centred on `P` (`native_source_lights.gd:120-145,203,216-217`). |
| `C`, `e` | World lights: torch colour or white, `e = 2.0 × energy × strength` (× flicker). Spell lights: `light_energy × energy_multiplier × strength`, with an optical colour override. |
| `P`, `h` | World lights: projected optical point (carried lift 2.5 steps including jump height, unregistered 1.0, fixture registered or mean height); `h = 56·2/PPU·ppu`, so it scales with zoom. Flicker also moves the optical height (`play.gd:1426-1432`). Spell lights: `h = (y − support_y)·abs(z.y)·ppu`, and the light is **off below its support** (`native_source_lights.gd:197-199`). |
| `N` | Environment: world normal × `world_to_canvas`, only when geometry is present, in packet, code > 0 and source normals are on, with ground join-mask flattening. Modular: `(n.x/scale_x, −n.y, n.z)`. Water: constant up. |
| `p` | Screen position of the receiving texel; receiver height 0 (`LIGHT_VERTEX = vec3(screen_px, 0)`). |

Also:
- **Directional lights** (`DirectionalLight2D`) have a live code path
  (`lighting_2d.gd:258-268,317-334,384-398`), although `world.json` lists none.
- **15 lights per receiver** is documented for Compatibility only; the app runs
  Forward+. Godot keeps the first lights in its own list order, not the
  nearest.
- **HDR light cap** (on by default): brightest-channel normalization of
  irradiance including ambient, a half-float intermediate, 8-bit quantize,
  sRGB decode. **Cap off:** per-channel clamp into RGBA8, then decode.
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
- blood lit pages, sampled per screen pixel, ambient 0.18
  (`blood_renderer.gd:79-85`; `blood_surface.gdshader:17`);
- legacy effect receiving, ambient 0.18, with specular
  (`native_effect_receiving.gd:145-160`);
- Studio swatches (`thumbnail_cache.gd:421-438`; `blood_preview.gd`);
- spell preparation gating and trace evidence, which read
  `native_preparation_ready` and `effect_was_submitted()`
  (`component_renderer.gd:153,411`; `native_source_lights.gd:57-61`).

**Essential work.** Evaluate the atlas formula inside each sprite's own
shader:
- a light table in a data texture: per light, world-space optical and support
  points, height rule, cookie index and span rule, colour, energy, kind
  (world, spell, directional); projected in the shader, so camera pans upload
  nothing;
- the cookie atlas (world profile and spell attenuation cookies);
- per pixel: snap to the source texel centre, compute its screen position from
  the quad's projection (`canvas_received.gdshaderinc:30-38` already does
  this), loop over the lights.

`shadow_composite.gdshader` shows the table pattern only; it evaluates cookie
× strength per screen pixel, with no N·L, height, colour, ambient or cap.

Per-instance data does not drop to zero: floors keep visibility and the join
mask per instance, and the texel-to-screen mapping needs the quad size per
entry (or screen-space derivatives).

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
  cap off: LDR clamp;
- `max(0, N·L)` (the old spatial `abs` applies to walls and doors only);
- Normals mode omits shadow-role and flame entries, and hides generated
  shadows;
- the 15-light cap (measure whether any Gallery receiver reaches it);
- the output responsibilities listed above move with the lighting:
  `LIGHT_VERTEX` for decals, body surfaces and hit material, wall mask,
  Compatibility inversion, depth-proxy addressing;
- door-leaf partition, selection masks and discards already live in
  `environment.gdshader:84-133`.

**Oracles.** All existing light oracles use native Canvas lighting as ground
truth, and already allow 1 RGB byte (`native_light_cap_checks.gd:201`,
`native_2d_source_checks.gd:285`):
- `native_atlas_publication_checks` + `compare_atlas_captures.py` (27
  captures; an A/B between two atlas scripts, reading atlas receipts);
- `native_light_cap_checks` (CPU cap oracle), `native_2d_source_checks`
  (reference canvas item lit by PointLight2D), `native_light_output_checks`,
  `native_demo_parity_checks`, light range, cap scene, floor lighting and
  cookie captures.

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
17 SubViewport creation sites.

| System | What it does now | What must be kept | Design |
|---|---|---|---|
| **Actor drop shadows** (`canvas_shadows.gd`) | Per actor: own `World3D` SubViewport, OmniLight3D with cube shadows (`shadow_blur` 1.5), 2,048² shadow atlas, ground plane, composite quad. Caster grids rebuild a **per-texel relief** from the depth packets (`shadow_caster.gdshader`, height scale 0.5, view-axis slide, feet anchored). Composite `0.839·blocked·c_d²·s_d/Σ c_i·s_i`. CPU dominant-light ranking samples cookie Images. Viewport resizes cost 1–6 ms. | The relief casters, the soft shadow test, per-actor painter slots (role "shadow" at the actor key), dominant light from cycle-mean energy and rank fields. | See L4: first remove the CPU costs and keep the look; a main-pass projection only with side-by-side proof. |
| **Legacy native effects** (`native_effect_preview.gd`, `native_effect_receiving.gd`) | Per occurrence: own `World3D`, 2–14 SubViewports; each output a lighting page duplicating every PointLight2D. | Off-screen composition: the palette is applied to the composite, and the fade to the whole effect. | Keep composition; light it with the shared light loop (ambient 0.18, specular) instead of duplicated light pages. |
| **Blood** (`blood_renderer.gd`) | Per stained tile: a 64² SubViewport, two mesh nodes, two materials, a painter entry. Two full-screen lit pages (ambient 0.18, per screen pixel). Droplets integrated in GDScript. | Stain lighting (ambient 0.18, per screen pixel), stain painter order, droplet painter buckets with back/front halves. | One field atlas for stain slots (no per-tile viewports); stains stay their own draws in painter order, lit by the shared loop with blood's ambient and per-pixel evaluation; droplets keep buckets and halves. |
| **Spell layers and depth support** (`native_effect_layer.gd`, `native_scene_support.gd`) | One full-screen SubViewport per finish profile (≤ 12) plus a support pass, all in the main `World3D`. Profiles already stop updating when idle (`native_effect_layer.gd:51`). | Decals project onto the painted main world (`cull_mask=1`, `native_factory_source.gd:153-156`). | Stay in the main world. Gate per-piece uniform writes; check cull masks so each profile draws only its layer. |
| **Wall fading mask** (`play.gd` `_sync_wall_mask`) | Full-screen SubViewport, one ColorRect per wall, every frame in translucent mode. Ids are draw-order indices among walls, so a reveal renumbers later walls. | "Only the front-most faded wall shows": ids must increase with painter order. A depth buffer or plain stencil is not equivalent for translucent surfaces. | Render on change; ids taken from the L3 ranks (monotone, no renumbering). |
| **Ground overlay** (`ground_overlay.gd`) | Mostly batched by style; raised tiles get a node each; route halves per tile. | Route halves per tile interleave with sprites. | Keep painter participation; batch only within groups the order oracle proves equivalent. |
| **Hit flashes and outlines** | A 256² own-world SubViewport per hit; a 2D SubViewport per outlined actor. | Hit material is post-light output work (moves with L1). | Shader effects on the sprite, designed in L7. |

## 3. Actors and the world/media pipeline

### Actors

**Essential.** A modular actor is 6–10 layers (up to 21). Each layer-clip is
a colour sheet plus **5 companions** (depth, normals for the selected
profile, support, normal_valid, solid-valid). All are 1920×1024: 15 frames ×
8 facing rows of 128² cells (`rig.facing_rows`). Colour, depth and normals
are RGBA8 (7.5 MiB each); the masks are grayscale.

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
change.

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
arrays or matrices), at most 16 per shader, and each instance reserves slots
in a global buffer (65,536 by default, ~4,096 instances; raisable with
`rendering/limits/global_shader_variables/buffer_size`). Colour-typed values
are linearized, so parity values go as `Vector4`.

Modular materials hold per-actor **arrays and samplers** (effect and flash
palettes, condition film, body surface ramps and textures) that change with
conditions. About 48 per-instance scalars (frame UV, tint, alpha, mirroring,
facing range, effect frames, ~25 condition scalars) fit in ~12 packed vec4.

**Design.**
- A per-sheet material (sheet, companions, optical constants), prebuilt when
  the bundle becomes resident.
- Per-instance values packed into ≤ 16 vec4 instance uniforms.
- Condition arrays and textures: per-actor material variants while a
  condition is active (exact), until a data texture is proven equivalent.
- Clock: keep the `Tracks` source time; wrap or clamp from `character_loops`;
  no AnimationTree for live actors. Fixture flames keep a continuous `t·fps`
  (they smoothstep energy and optical height between frames). The workshop
  destruction state machine keeps its tree.
- Clip change: switch to the sheet's prebuilt material plus `frame_uv`. The
  media plan prefetches the bundle (textures, pick data, worker-admitted
  descriptor, palette ranges, AABB) before the clip edge; the timeline knows
  the edge in advance, so there is no world cut and no hold.

### World preparation

**Essential.** For each new or changed row: textures, transform, uv rect,
per-identity visibility, painter position, material key. One row yields
several entries: the shadow pass, three door passes, hidden wall members.
Also essential and currently inside the step machine: blood world preparation,
the native spell receiver boundary, scenery visibility, light-source and
cookie resolution, wall geometry views, ground support, the blood index.

**Actual.** Each static sprite gets a worker-built ShaderMaterial (51
uniforms set one by one), a QuadMesh, a crop scan and an atlas packet, then a
scene-thread MeshInstance3D and atlas adoption. Each floor row gets an atlas
spec, receiver record, canvas item, projection packet and join mask. The step
machine adds construction lanes, atlas stages, one-item-per-iteration
membership/retirement/scenery loops, order collect/sort/publish/release,
cookie waits and identity proofs.

**Design.**
- Floors: per-texture MultiMesh with custom data, as today (when any
  negative elevation exists, floors are ordered individually, as today).
- Everything else: lightweight instances (RenderingServer instances, or
  nodes sharing mesh and material; measure both) with a shared material per
  (record, source role, shader variant) and ~3 vec4 of instance values (tint,
  visibility, highlight, wall opacity and mask id, door partition and frame
  depth, selection inversion, unlit).
- Visibility stays **per identity**: tiles by their cell, boundary objects by
  either incident cell, other objects only by server grants
  (`world.gd:444-525`). Instance value for objects, custom data for floors.
- The worker produces the instance list (transform, material key, values,
  painter rank); the main thread creates the instances in one frame. The
  ≤ 5 ms target is unproven: a spike measures it on the door first.

### Media and VRAM

**Measured.** VRAM ≈ 122 MiB + 5.57 MiB × resident textures. A layer-clip
(six 1920×1024 textures) costs ~28 MiB; one actor ~267 MiB per clip; the six
idle Gallery actors ~1.6 GiB. The **required** set alone is 524 paths,
≈ 2.9 GiB of VRAM. CPU Images add 2.4 GB of RAM. The corpus is ~59k PNGs,
5.9 GB on disk, outside the project (`source_data/media_root`).

**Why the current budget code cannot hold a consumer budget:**
- it counts CPU bytes plus a `w·h·4` GPU estimate (also for grayscale), not
  real GPU bytes, and excludes render targets;
- pinned demand (wanted + selected preload) is never evicted; with budget 0
  a route still loads everything required, and a small budget only disables
  prefetch, which brings holds back;
- eviction does not free VRAM while textures are still referenced: prepared
  bindings, shadow casters, `solid_masks`, wall-mask materials, cached quarter
  views and atlas group materials all keep them;
- LRU is touched only for actor colour sheets;
- eviction is per path, but one missing companion hides the layer.

`BUDGET_BYTES` (16 GiB) is test-only; the runtime reads
`source_data/encounter_cache_mib` (16384, overridden in Studio). Unit tests
and one budget-0 route test exist; in the Gallery, optional selection already
binds at 16 GiB (1,910 selected, 1,125 skipped) but nothing is ever evicted.

**Levers, all to be measured before choosing:**
- **Facing-row residency (lossless).** A layer shows one of 8 facing rows at a
  time; an idle actor needs 1/8 of each sheet. The timeline knows facing
  changes in advance, so rows can be made resident before they show.
- **Merged masks (lossless).** Pack the grayscale maps into the channels of
  one texture, after checking which channels each map actually uses.
- **Trim unused frame cells (lossless).**
- **GPU compression (lossy).** BC7 for colour, BC5 for normals. Changes
  pixels, so only with the user's consent after side-by-side captures; depth
  and masks stay lossless.

**Moving the media.** The levers above change the file layout, so the
practical form is an offline **prepack step**: it converts the referenced
subset into the runtime layout (per facing row, merged masks, trimmed cells,
optionally compressed) into a git-ignored cache that the worker loads
directly. Importing the raw corpus through the Godot importer is not
proposed: it would duplicate 5.9 GB into `.godot/imported` and saves VRAM
only with lossy compression.

**Design.** Budget in real GPU bytes by format, plus render targets, against
a < 4 GB GPU (≤ ~2.5 GiB total). Residency and eviction per **sheet bundle**
(or per facing row). Eviction drops every Texture2D reference. LRU touched for
every displayed path. Fixed-capacity Texture2DArray pools per size class are
an option (they give both the budget and per-instance texture selection).

**CPU Images.** Also used as the actor display gate, by surface sockets
(alpha tri-state, depth/support/solid), for the fixture-flame Texture2DArray,
and by environment picking (`hit_mask` plus RGBA ranges that exclude ground
shadow pixels). A precomputed per-(record, role) pick mask can replace them
for picking only.

### Draw order

**Every sprite shader turns depth off** (`depth_draw_never,
depth_test_disabled`, line 2 of the sprite shaders). Order is a CPU painter
sort: `grid_order.gd` keys compared by a GDScript loop, binary-search merges
into ~460 statics, per-frame keys for visible actor layers, full re-ranking on
reveals and rotations. The result is written as
`sorting_offset = rank·8 + forward·origin` (`play.gd:2967-2977`);
`render_priority` is unused.

**Per-pixel depth is not an option.** Each asset's depth is relative to its
own optical camera ("45 and 30 degree elevations", a "provisional optical
convention … never changes its geometry/Z/order",
`character_geometry.gd:162-163,181`). The door partition is an authored
painter depth, the wall mask enforces "front-most faded wall only", and
shadow entries are a role band: these are semantics, not depth workarounds.

The key (`grid_order.gd:4-21`), including details the first draft omitted:
- background floors first (`ground_background` is global), keyed by
  `row.layer` in slot 1 and 0 in slot 2;
- owner cell `round(pos + 0.489921)` after quarter rotation (biased);
  diagonal x+y, then x−y;
- height (`sort_height_steps` when present; a lerped float for moving actors);
- role, contact y, layer (`layer·10 + {0,1,2}`, flame 100, generated shadow −1);
- tall objects by `sort_position`;
- exact ties by id string (`play.gd:2964-2965`).

Participants: sprites, door passes, hidden wall members, flames, ground
overlay routes, blood stains and droplets, generated actor shadows.

Godot sorts transparent instances by priority, then depth, with an unstable
introsort: equal values draw in arbitrary order and can flicker.

### Timeline

Per frame `actor_samples()` runs twice (`play.gd:663`, `timeline.gd:630`)
and duplicates active tracks; `component_samples()` duplicates active
components; `presentation_state()` copies state and tiles while staged tiles
exist, sometimes inside per-sample loops. Measured `displayed_samples`:
~0.25 ms/frame.

## 4. Replacement plan

This replaces Stages 1–2 of
[the 16 October plan](CLIENT_STRUCTURE_AND_NATIVE_DATA_PLAN_2026-10-16.md)
for rendering and preparation. Its user decisions carry over: no legacy
runtime paths; no new Factory content before the gate; native data for spells
and conditions.

Rule for every step: **the picture does not change.** Each step is proven
against native-Canvas or current-code references before the old path is
deleted; any remaining difference is shown side by side to the user.

| # | Change | Deletes | Gate |
|---|---|---|---|
| L1 | **Per-pixel lighting for atlas receivers.** Light table + cookie atlas, evaluated in the sprite shaders with the atlas formula and every parity trap in §1. The atlas page's PointLight2D/DirectionalLight2D nodes go away; blood, effect-receiving and Studio pages keep theirs until L6/L7. The output responsibilities (decal `LIGHT_VERTEX`, body surfaces, hit material, wall mask, Compatibility inversion, depth-proxy addressing) move into the sprite shaders. Spell evidence (`effect_was_submitted`, `native_preparation_ready`) is reported from the light table. | ~4,000 lines (atlas, planner, receivers, output/receiving materials, atlas stages, global rebuilds); ~500 ported | Native-Canvas reference scenes kept as test oracles; ≤ 1 RGB byte, documented exceptions (15-light cap) shown to the user; A/B as two commits on the same journal, ignoring atlas-only receipt fields; live route and Studio gate. |
| L2 | **Shared materials, lightweight instances.** As in §3 World preparation. A reveal is a worker-built instance list applied in one frame. | Per-entry materials and uniform ledgers, construction lanes, slicing, membership/order/retire loops, identity proofs | Spike first: door instance creation measured on the main thread. Then: room on screen at the cue with **no pause**, ≤ ~5 ms main-thread work in the publishing frame; captures identical. |
| L3 | **Draw order: same key, no global per-frame work.** See notes. | Per-frame actor key merges, static re-ranking on reveals | Order oracle (exact), then captures |
| L4 | **Shadows: same look, no per-frame CPU.** Keep the per-actor relief casters and soft shadow test. Fixed viewport sizes (no resizes); dominant light ranked from the light table; re-render only when an input that changes the shadow changes (actor frame, position, light), established by test rather than assumed. A main-pass projection of the relief (coverage blend-once, softness reproduced) only if the measured cost still matters, with side-by-side proof. | CPU cookie sampling, resizes, redundant re-renders | Shadow oracles unchanged |
| L5 | **Actors.** As in §3 Actors. | AnimationTree for live actors, per-frame pose dictionaries, the SourceMaterial ledger, source-only world cuts | Actor captures; per-frame actor cost ≈ L instance-uniform writes + L transforms and offsets, plus condition writes for actors with active conditions; clip changes with no pause |
| L6 | **Blood.** Field atlas; stains as their own ordered draws lit by the shared loop (ambient 0.18, per screen pixel); droplets keep buckets and halves. | Per-tile viewports, lit pages | Blood oracles (Pygame reference within .008) |
| L7 | **Effects.** Legacy effects keep off-screen composition, lit by the shared loop (no duplicated light pages). Spells stay in the main world; per-piece writes gated. Hit flashes and outlines as sprite shader effects. | Duplicated light pages, per-hit viewports | Spell/effect captures |
| L8 | **Media and VRAM.** Real-format GPU budget for a < 4 GB GPU; bundle residency and eviction that drops every reference; levers from §3 measured (lossless first); prepack step if the layout changes. | Role/family/selection accounting replaced by a budgeted bundle LRU | Holds stay 0 **with the consumer budget**; VRAM breakdown reported per route |

**L3 notes.** The user's caution (17 October): it is very easy to render
assets out of order and break the perspective.

- **Keep the key and the comparator exactly.** No scalar encoding: the key
  needs ~30–55 bits, `sorting_offset` is float32 (~22 ordered bits).
- **Statics:** the worker sorts them on world changes and assigns **gapped
  ranks**. A reveal inserts new statics between neighbours by the same
  comparator, with no renumbering. Renumbering happens on the worker only
  when a gap runs out or on a global re-key (quarter change, `ground_background`
  flip).
- **Actors per frame:** a binary search with the same comparator among the
  statics (~9 comparisons per actor), offset placed between the neighbours.
  Values are unique (ties broken by id, as today), because the engine sort is
  unstable.
- **Precision:** the gap size is chosen so `rank·8` stays inside float32's
  exact range together with the fractional actor slots; the oracle checks it.
- **Wall mask ids** come from the ranks, so they stay monotone in painter
  order without renumbering.
- **Order oracle** (before switching): the final `sorting_offset` order must
  equal today's full key sort exactly, for every Gallery and Studio scene in
  all four quarters, plus negative-elevation maps, mid-move actors (fractional
  position and height), passage and lift, exact actor/static ties, door
  three-pass entries, hidden wall members, `sort_position` objects, flames,
  overlay routes, blood and generated shadows.
- **Payoff:** ~1.1 ms/frame today plus the reveal re-rank.
- **Instancing constraint:** transparent sprites in one MultiMesh draw as one
  object, so only background floors stay MultiMesh.

**Steady target.** Idle-frame script ≤ 2 ms once optional media work has
settled; animating frames dominated by GPU work; VRAM within the consumer
budget on every route.

**Reveal target.** The room appears at the door cue with no pause.

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
| Zero-tolerance gate | Oracles allow 1 byte | ≤ 1 byte, documented exceptions |
| ~5,000 lines deleted | ~4,000 deleted, ~500 ported | Corrected |
| One exact float scalar per sprite | ~30–55 bits needed; unstable engine sort | Gapped ranks + same comparator |
| Write `DEPTH` from depth packets | Per-asset optical cameras | Removed |
| `render_priority` orders painters | `sorting_offset = rank·8 + forward·origin` | Corrected |
| Per-cell sight texture | Visibility is per identity, by server grant | Instance value |
| One material per texture with instance uniforms | 16-slot limit, no arrays/textures/matrices | Per (record, role, shader); per-sheet for actors |
| `floor(t·fps) mod n` | Clamp for non-looping clips; source time from Tracks | Wrap or clamp from `character_loops` |
| Clip change = texture swap | Needs the six-texture bundle, pick data, descriptor | Bundle prefetch |
| 6.2 GB from textures and render targets | Grows to 8.4 GB; render targets negligible | Media residency is the VRAM problem |
| Budget logic never exercised | Tests exist; nothing is ever evicted in routes | Eviction must drop every reference |
