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
- what a GPU-first design would do instead.

Method: three read-only studies, with the key claims spot-checked in the
code. Live counts come from the Gallery route.

### Measured state (idle frame, Gallery, run `20261017T0420`)

| | Value |
|---|---:|
| GPU time per frame | **0.24 ms** |
| Render-thread CPU | 0.47 ms |
| Player script time | **8.4 ms** |
| Frame interval | 11.8 ms |
| Draw calls / render objects | 508 / 1,098 |
| Resident textures | 1,304 |
| Video memory | **6.2 GB** |
| Light atlas | 538 receivers, 20.9 Mpx |

The GPU is idle. The frame is script bookkeeping.

## 1. Lighting: the 2D light atlas

**What it computes.** Screen-space 2D point lighting per *source texel*:
`out = S·A + Σ S·T·C·e·max(0, N·normalize((P,h) − (p,0)))`.

| Symbol | Meaning |
|---|---|
| `S` | sRGB-encoded source colour (or white when storing irradiance) |
| `A` | Ambient (0.30) |
| `T` | Radial cookie gradient, 256², elliptical with the camera |
| `C`, `e` | Light colour and energy (2.0 × strength, × flicker if enabled) |
| `N` | Canvas-space normal from geometry/normal maps |
| `P`, `h` | Light screen position and fixed calibrated height |
| `p` | Screen position of the receiving texel; receiver height 0 |

At most 15 lights per receiver. Optionally an HDR "light cap": brightest-channel
normalization of irradiance, then 8-bit quantization and sRGB decode.

**No 2D shadows or occluders** (`shadow_enabled=false`,
`lighting_2d.gd:231,262`; `native_source_lights.gd:41`). Light sources are
disclosed world emitters (33 Gallery wall torches plus carried torches),
spell lights (Factory OmniLights mirrored as PointLight2D) and optional
fixture flicker.

**How.** Every placed instance (each floor tile, wall, prop, actor layer,
flame) gets a cell in an 8,192 × up-to-8,192 SubViewport. A CanvasItem
redraws the instance there at its real screen transform (so 2D lights cull
and shade correctly), with its own group material. The 3D output material of
the instance then samples its cell. The atlas re-renders every frame.

**Per-instance CPU that exists only for the atlas:**
- classification and crop scans;
- an output material per entry;
- spec records and support-owner maps;
- shelf packing, and region rewrites when the atlas grows;
- group materials per (source material, visibility, water id, join mask);
- one canvas item per static receiver and a Sprite2D per dynamic one;
- projection packets and floor addresses;
- receiver records, culling of all receivers on any camera change, and
  restyling on visibility changes.

Per frame:
- dynamic receivers are re-projected and re-culled;
- material sync takes about 1.5 ms while moving;
- PointLight2D property writes per light.

A cap toggle, Normals toggle, rotation or window growth triggers a full
atlas rebuild.

**Size:** about 4,500 production lines exist only for it
(`native_light_atlas.gd` 1,677, `native_light_delta.gd` 1,703, the atlas
stages of `world_preparation.gd`, canvas draw/batch, atlas shaders, global
atlas code in `play.gd`). 58 test files reference it.

**Essential work.** Evaluate the same formula in the sprite's own 3D shader:
- per light, a ~15-float record (screen position, cookie centre/span,
  radius, height, colour, energy, cookie index) in a small data texture plus
  a cookie atlas;
- per pixel, a loop over the lights.

`shadow_composite.gdshader` already does exactly this (a `source_data`
texture plus `cookie_atlas` in a spatial shader). Per-instance CPU work
becomes zero: instances only need their transform.

**Parity traps to reproduce deliberately:**
- lighting is applied to the sRGB-encoded albedo, not in linear space;
- cap semantics: brightest-channel normalization including ambient, a
  half-float intermediate, an 8-bit quantize before decode;
- ambient is converted to linear in HDR but light colours are not;
- the light is evaluated once per *source texel* at its screen centre, not
  per screen pixel (snap to the texel centre);
- the 15-lights-per-receiver cap (sum all lights instead? record the
  difference);
- `max(0, N·L)` in the atlas versus `abs(N·L)` in the old spatial path;
- door-leaf partition, selection masks and alpha discards move from the
  receiver to the output shader;
- unlit roles (shadow role, flames, Normals debug) stay unlit.

Pixel oracles exist:
- `native_atlas_publication_checks` plus `compare_atlas_captures.py`: A/B
  final RGBA, zero tolerance, 24 views;
- `native_light_cap_checks`: CPU scalar cap oracle;
- `native_2d_source_checks`: independent reference shader;
- `native_light_output_checks`;
- `native_demo_parity_checks`;
- the light range, cap scene, floor lighting and cookie captures.

**Related blocker for instancing.** Every non-floor entry also owns its own
MeshInstance3D, QuadMesh and source ShaderMaterial (`sprite_sources.gd`
104–117). Painter order is per-entry `render_priority`. Removing the atlas is
necessary but not sufficient: entries of one texture must also share one
material (or one MultiMesh) for the reveal to become a transform upload.

## 2. Secondary rendering systems

The same anti-pattern appears in every one: per-instance SubViewports, nodes
or materials, re-rendered every frame or on every camera move, plus
per-frame GDScript loops doing shader work.

| Rank | System | What it does now | Essential work / GPU-first design |
|---:|---|---|---|
| 1 | **Actor drop shadows** (`canvas_shadows.gd`) | Per actor: its own `World3D` SubViewport, an OmniLight3D with cube shadows, a 2,048² positional shadow atlas (~8 MB), a ground plane, a composite quad. One caster mesh per layer with `cell−1` subdivisions (a 128² cell is 32,768 triangles, ×6 cube passes). Re-rendered on any camera pan or animation frame. CPU dominant-light ranking samples cookie Images per source per actor. Viewport resizes cost 1–6 ms. | Planar projection of each layer from the dominant light, in one pass in the main world: vertex displacement `P' = L + (P−L)·(g−L.y)/(P.y−L.y)`. Dominant light picked in the shader from the existing `source_data`/`cookie_atlas`. Stencil or a shared R8 mask so overlapping layers don't double-darken. World-space, so camera pans cost nothing. |
| 2 | **Legacy native effects** (condition auras etc., `native_effect_preview.gd`, `native_effect_receiving.gd`) | Per occurrence: its own `World3D`, 2–14 SubViewports (colour MSAA 2×, palette, normal/material/depth, specular, output). Each output is a lighting page duplicating every PointLight2D. All set UPDATE_ONCE every frame. | Draw the effect in the main pass with its material; light it with the shared per-pixel light loop. |
| 3 | **Blood** (`blood_renderer.gd`) | Per stained tile: a 64² SubViewport, two MultiMesh/mesh nodes, two materials, a painter entry with a per-frame sort key. Two full-screen lit "pages" (each duplicating all lights) re-render every frame while any blood is visible. Droplets integrated in GDScript per frame. Field rebuilds use per-instance writes after `instance_count` changes. | One 2,048² field atlas (1,024 slots), redrawn only for changed slots. The stain sampled inside the terrain shader through a tile→slot index texture (no nodes; inherits floor order). Lit by the shared light loop (no pages). Droplets evaluated in the vertex shader from age and initial state. |
| 4 | **Spell layers and depth support** (`native_effect_layer.gd`, `native_scene_support.gd`) | One full-screen SubViewport per finish profile (≤ 12) plus a support pass, all *sharing the main World3D*, so each culls the whole world every frame. A depth proxy node per actor layer. Unconditional uniform writes per floor and per layer each frame (proxy writes now gated, `d737883`). | Spells and their depth proxies in their own World3D. The support pass renders only on change. Per-piece layer/uniform writes gated. One post-draw callback. |
| 5 | **Wall fading mask** (`play.gd` `_sync_wall_mask`) | Full-screen SubViewport, one ColorRect + ShaderMaterial per wall, UPDATE_ALWAYS every frame in translucent mode. Mask ids are draw-order indices, so revealing a wall renumbers every later one. | Render on change. One MultiMesh2D with id/rect in custom data. Stable ids (or stencil blend-once in the main pass). |
| 6 | **Ground overlay** (`ground_overlay.gd`) | Mostly batched (flat cells per style). Raised tiles get one node each, or every tile when negative elevations exist. Each route half gets its own material. | Grid lines procedurally in the terrain shader. Marks from a per-tile state texture. Routes as one line mesh. |
| 7 | **Hit flashes and outlines** | A 256² own-world SubViewport per hit occurrence; a 2D SubViewport per outlined actor, re-rendered per animation frame. | Shader effects on the sprite itself. |

There are 16 runtime SubViewport kinds: global, per actor, per profile, per
tile, per effect half, per quarter view. Every node these systems add to the
painter list also gets an `Order.key` rebuilt every frame. Static ranks are
draw indices, so any reveal renumbers every static entry after the insertion
point.

## 3. Actors and the world/media pipeline

### Actors

**Essential.** A modular actor is 6–10 layers (up to 21). Each layer has one
sheet per clip plus 4 companion maps, all resident. Per frame it needs: the
frame index `floor(t·fps) mod n`, facing, position, one UV per layer, and a
sort key.

**Actual, per actor with L layers.** About 35 nodes for L = 8 and 3L+2
materials:
- L MeshInstance3D, each with its own QuadMesh and its own ShaderMaterial
  (~72 uniforms) plus a per-entry copy of every uniform name;
- L atlas receivers, receiving materials and output materials;
- a Playback node, AnimationPlayer and AnimationTree;
- the shadow viewport set (§2), with L casters.

Per frame:
- `Characters.rest_sample`, condition pose/material/parameter dictionaries
  (~25 keys, deep-compared) and a 20-element pose key;
- an **AnimationTree seek with a string-built property name only to compute
  `fposmod(t, length)`** (`animation/graphs.gd:197-215`);
- on every animation frame, per layer: binding values through the
  `SourceMaterial` change ledger, a geometry rebind and bounds updates;
- atlas restyle, reprojection and material copy;
- a shadow re-render.

**A clip change is treated as a world boundary.** It needs a worker
derivation, the WorldPreparation step machine and publication proofs
(`compiler.gd:546-616`, `timeline.gd:388-394`). The actual binding is ~30
lines of math.

**Design.**
- One material per shader variant/sheet, with `instance uniform` frame UV,
  tint, alpha, visibility and condition scalars.
- Clock `int(t·fps)`, with no AnimationTree.
- A clip change swaps textures when resident; the timeline gates only on
  residency.
- Per frame per actor: L uniform writes plus one transform.

### World preparation

**Essential.** For each new or changed row: texture, transform, uv rect,
visibility, sort key, grouped by texture. For the door that is ~1,150 × ~20
floats into ~24 buffers, plus uploading textures not yet resident. Row
derivation is real work and already runs on a worker.

**Actual.** Each static sprite gets a worker-built ShaderMaterial (~50
uniforms set one by one), a QuadMesh, a crop scan and an atlas packet, then a
scene-thread MeshInstance3D and atlas adoption. Each floor row gets an atlas
spec, a receiver record, a canvas item, a projection packet and a join mask.

The step machine runs:
- construction lanes;
- atlas stages;
- membership, retirement and scenery loops of one item per iteration;
- order collect, worker sort, publish and release (popping one record per
  iteration to spread Dictionary frees);
- cookie waits;
- identity proofs.

Only the derivation and a ~30-line publication core are essential; the rest
serves the atlas or the 2 ms slicing.

**Design.** The worker turns rows into per-texture packed buffers
(transform + custom data). The main thread assigns the buffers in one frame,
with an estimated < 5 ms of main-thread work. Sight/memory greying becomes a
per-cell visibility texture sampled by world position, instead of per-entry
uniforms.

### Media

**Essential.** Per received group:
- compute the texture paths (worker);
- load them in the background;
- gate the timeline on that set being resident;
- prefetch likely outfits and clips.

The corpus (~59k PNGs, 3.7 GiB) justifies streaming.

**Actual.** About 2,300–2,600 lines are residency/budget/role accounting:
- multi-consumer role counts;
- family stepping of 32 paths per frame;
- a byte-budget selection worker;
- pending tiers;
- CPU release and LRU prune;
- per-frame due/demand/priority rebuilds.

`BUDGET_BYTES` and `encounter_cache_mib` are both **16 GiB**
(`media_warmup.gd:13`, `project.godot:34`), so selection and pruning never
bind. CPU `Image`s are kept for picking and atlas crops; a 1-bit alpha mask
is enough for picking.

**Design.** Godot-imported textures with `ResourceLoader.load_threaded_request`
(no runtime PNG decode). A per-group path set, a `has_all` readiness check, a
simple LRU only if memory requires it. About 400–600 lines.

### Draw order

**Every sprite shader turns depth off** (`depth_draw_never,
depth_test_disabled`, `modular.gdshader:3`, `environment.gdshader:8`). All
ordering therefore depends on a CPU painter sort:
- 7-element lexicographic keys compared by a GDScript loop;
- per-frame keys and `sorting_offset` writes for every visible actor layer;
- binary-search merges into ~540 static entries;
- full static re-ranking on reveals and rotations.

Several workarounds exist because there is no depth buffer: the door-leaf
partition passes, the translucent-wall coverage mask viewport, and the
separate shadow entries.

**Design.** The content already ships per-pixel depth packets. Write `DEPTH`
from them (or offset quads along the view axis by their key) and enable the
depth test with alpha scissor. Only truly translucent pixels (shadows, glow,
faded walls) need ordering. Picking sorts only the candidates under the
cursor.

### Timeline

Per frame:
- `actor_samples()` is computed twice and duplicates every track;
- `component_samples()` duplicates every component;
- `presentation_state()` copies the state and the whole tiles dictionary on
  each of its 4–10 calls per frame while staged tiles exist.

### Machinery size

Of ~33.4k presentation lines, about **8,500–9,500 (25–30%)** exist only for:

| Machinery | Lines |
|---|---:|
| The lighting atlas | 5,000–5,500 (+700 for the per-actor shadow viewports) |
| 2 ms slicing and the multi-frame preparation pipeline | 1,200–1,500 |
| Residency/budget/role accounting | 2,300–2,600 |

## 4. Replacement plan

This replaces Stages 1–2 of
[the 16 October plan](CLIENT_STRUCTURE_AND_NATIVE_DATA_PLAN_2026-10-16.md)
for rendering and preparation. Its user decisions carry over:
- no legacy runtime paths;
- no new Factory content before the gate;
- native data for spells and conditions.

Order follows the size of the gap and the dependencies: the light table
feeds shadows, blood and effects.

| # | Change | Deletes | Gate |
|---|---|---|---|
| L1 | **Per-pixel lighting.** A light table (data texture + cookie atlas, like `shadow_composite.gdshader`), evaluated in the sprite shaders with the atlas formula (sRGB-space multiply, cap, texel-centre snap, ambient). PointLight2D nodes go away. | The light atlas, planner, receivers, output/receiving materials, atlas stages, global rebuilds (~5,000 lines) | Atlas pixel oracles (`compare_atlas_captures.py`, cap oracle, 2D source reference). Every remaining difference (e.g. the 15-light cap) captured side by side for the user. |
| L2 | **Shared materials and instancing.** One material per texture/shader variant with instance uniforms. Floors (background layer) as per-texture MultiMesh, as today. Props, walls and doors become separate lightweight instances that share one material per texture, because each must keep its own position in the painter order (see L3). Sight greying via a per-cell visibility texture. A reveal is per-texture data built on the worker and applied in one frame. | Per-entry materials and uniform ledgers, construction lanes, slicing, membership/order/retire loops, identity proofs (~1,500 lines) | Door: room on screen at the cue with **no pause**, ≤ ~5 ms main-thread work in the publishing frame. Studio and live captures identical. |
| L3 | **Draw order without the global CPU sort, same semantics.** See the L3 notes below. | Global ranks, binary-search merges, per-frame rank writes, static re-ranking on reveals | Order oracle (below), then captures |
| L4 | **Shadows as a planar projection pass** in the main world, dominant light picked in the shader | Per-actor World3D, omni cube shadows, caster grids (~700 lines) | Shadow oracles, re-qualified against the new pass |
| L5 | **Actors.** Shared materials, per-layer instance uniforms, integer clock (no AnimationTree), clip change = texture swap when resident (no world cut) | Per-frame pose dictionaries, the SourceMaterial ledger, source-only world cuts | Actor captures; per-frame actor script cost ≈ L uniform writes |
| L6 | **Blood.** Field atlas plus terrain-shader lookup; droplets in the vertex shader | Per-tile viewports, lit pages | Blood oracles (Pygame reference within .008) |
| L7 | **Effects.** Legacy effects, hit flashes and outlines as main-pass shader effects. Spells in their own World3D with an on-change support pass. | 2–14 viewports per effect, per-hit viewports | Spell/effect captures |
| L8 | **Media.** Imported textures with threaded loading, path-set readiness | Residency/budget/role accounting (~2,000 lines) | Holds stay 0; memory reported |

**L3 notes: draw order is the highest-risk step (user caution, 17 October).**
The game is 2.5D: pre-rendered sprites with depth relative to their own
render camera. Order comes from a grid painter key (`grid_order.gd`):
background floor first, then the owner cell's diagonal x+y, then x−y, then
height, role, contact y and layer. Tall objects are ordered by their owner
cell (`sort_position`). Per-pixel depth would change these semantics and can
easily put assets out of order and break the perspective.

- **L3a (planned).** Keep exactly this key. Compute it locally per sprite as
  one scalar that sorts identically, and use that as the sprite's draw order
  (`sorting_offset`, or a constant per-sprite depth). Static sprites compute
  it once at creation, actors when they move. No global rank, merge or
  re-rank.
  - Before switching, prove equivalence with an **order oracle**: for every
    Gallery and Studio scene and all four quarters, the scalar order must
    equal today's key order exactly. Ties and the known int/float `0`/`0.0`
    issue must be resolved explicitly.
  - Then compare captures of walls, doors, tall props, raised tiles and
    actors behind and in front of props.
- **L3b (not planned).** Per-pixel depth only if a specific visual problem
  needs it, and only with the same oracle and captures.
- **Instancing constraint.** Transparent sprites in one MultiMesh draw as one
  object, so props of one texture cannot be one MultiMesh while actors move
  between them. Only the background floor stays instanced that way.

**Steady target.** Idle-frame script ≤ 2 ms, and animating frames dominated
by GPU work.

**Reveal target.** The room appears at the door cue with no pause.

**Today's work.** It stays in history. The atlas-specific changes (planner
groups, support capture, worker group materials) disappear with L1. The
general fixes stay valid: GPU readback avoidance, shader warm-up, protocol
parse, blood/support skips, light-plane sizing.
