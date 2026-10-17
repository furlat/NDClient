# L8 phase 1: sheet prepack and its oracle (18 October 2026)

Offline only. Nothing at runtime loads the bundles yet.

## How a modular sheet is read today

All sheet samplers are `filter_nearest, repeat_disable`. Textures are created
from decoded PNGs (`media_warmup.gd:1205`) without mipmaps, so there is no
filtering and no mip level to keep. Colour, depth and normals decode as RGBA8;
support, normal_valid and solid-valid decode as L8.

- **Texel address.** `frame_uv = (frame·cw/W, row·ch/H, cw/W, ch/H)`
  (`actor_construction.gd:113`). Shaders snap UV to the cell texel centre
  (`lit_texel_uv`, `native_scene_receiver`, `native_scene_support`) and fetch
  `frame_uv.xy + texel·frame_uv.zw`. So they read the texel at
  `(frame·cw + floor(UV·cw), row·ch + floor(UV·ch))`, the same texel an
  integer fetch reads (`character_geometry_sampling_checks`).
- **The ring.** If UV is at 1.0 (or below 0) by float error, floor gives `cw`
  (or −1): the neighbouring cell's edge texel, or the clamped sheet edge.
  Picking truncates `(frame.x+uv.x·frame.z)·W` (`play.gd:3982`), which can
  land on the same texels. A cell's readable region is therefore
  `[−1, cw] × [−1, ch]`, clamped at the sheet edge.
- **Every fetch:**
  - `modular.gdshader` reads colour, discarding at alpha ≤ 0. At the same
    texel it then reads depth, normal, support and normal_valid (normals);
    normal and normal_valid (body surface); depth and support
    (`native_scene_receiver`).
  - `shadow_caster.gdshader`, vertex: four taps at pixel − {(1,1), (0,1),
    (1,0), (0,0)}, clamped to the cell, using `textureLod 0` on sheet, depth
    and support. A tap counts only if sheet alpha > 0.5. The fragment does the
    same three tests at the clamped texel.
  - `native_scene_support.gdshader` reads sheet (discard if alpha < 1), then
    depth, solid and support.
  - CPU readers:
    - picking reads alpha > 0.05;
    - sockets read colour alpha first, then compact samples or the depth,
      support and solid Images;
    - the condition outline draws a Sprite2D region of the cell, nearest;
    - palette ranges take the luminance of texels with alpha > 128 in each
      facing row;
    - Studio thumbnails also read the sheet.
- **Gate.** Every reader tests colour alpha before it uses a companion. So
  where colour alpha is 0, companion values never reach the picture.

## Bundle (`presentation/resources/sheet_bundle.gd`, `tools/prepack_sheets.gd`)

- **Box.** For each cell, the box is the set of colour-alpha > 0 texels in its
  readable region, ring included.
- **Pages.** Boxes are shelf-packed into 128² pages, one page set per bundle.
  Every channel uses the same layout: colour, depth, the original/gentle/
  reference normals, support, normal_valid and solid. Images keep their
  decoded format, uncompressed, so the runtime uploads them with no decode.
- **Cell table.** 7 ints per cell: page, page x, page y, box x, box y, w, h.
- **Lookup.** `SheetBundle.packed_texel` is the one mapping the shaders and CPU
  readers will share.
- **Page size.** Measured over the real boxes of 359 clips with the same packer:

| Page | Pages | Fill | MiB (15 B/texel) |
|---:|---:|---:|---:|
| 96 | 1,991 | 70% | 262 |
| 112 | 1,451 | 70% | 260 |
| **128** | **1,134** | **69%** | **266** |
| 160 | 777 | 64% | 285 |
| 256 | 447 | 44% | 419 |

  The largest box seen is 91×56. A box larger than a page is an explicit tool
  error.

## Oracle (`tests/sheet_prepack_checks.gd`)

The oracle covers the 359 modular layer-clips that the Gallery, door, movement
and Fireball player-run traces name (74 of them in the Gallery trace). For
every channel and every cell it checks:

- inside the box, the packed texels equal the original texels byte for byte;
- outside the box, the original colour alpha is 0 over the whole readable
  region (the reference region is built independently, by padding the whole
  sheet);
- `packed_texel` agrees at 2,000 random readable texels per bundle.

Result: **1,462,841 checks, 0 failures**, on both the raw and the compressed
bundles. The ring holds visible texels in exactly one cell of the 359 clips
(`Melee2/Attack1`, cell 7).

## Measured (RTX 5090, machine shared with other jobs)

Six runtime channels per clip. GPU bytes are
`RENDERING_INFO_TEXTURE_MEM_USED` deltas.

| | Today: PNG + ImageTexture | Bundle (raw .res) | Bundle (zstd .res) |
|---|---:|---:|---:|
| Load + upload per clip, median | 50.4 ms (41.2 decode + 9.4 upload) | **1.02 ms** (0.90 + 0.12) | 1.49 ms |
| p95 / max | 53.3 / 55.8 ms | 2.27 / 5.72 ms | 4.42 / 5.87 ms |
| GPU, 359 clips | 10,076 MiB | **264 MiB (38×)** | 264 MiB |
| GPU, Gallery's 74 clips | 2,081 MiB | 59.3 MiB (35×) | 59.3 MiB |
| Disk, 359 clips | 82.0 MB | 428.5 MB (8 channels) | 68.7 MB |

`NakedBody` gains 11.4×; its clips use 8–13 pages. The prepack takes 31 s for
359 clips (≈85 ms per clip).

## Phase 2 design (runtime adoption)

- **Pools.** One `Texture2DArray` of 128² layers per channel: colour, depth
  and the selected normal profile (RGBA8); support, normal_valid and solid
  (R8). 2,048 layers per array is about 480 MiB per pool set, roughly 650
  clips. A bundle owns k free-list layers. Load = worker `ResourceLoader.load`
  plus k `RenderingServer.texture_2d_update(array, image, layer)` per channel.
  Evict = return the layers to the free list. Bundle ids are integers from the
  manifest.
- **Cell table.** A global RGBA32I texture holds 120 rows per bundle slot.
  Each layer carries one instance int, bundle_slot·120 + cell. A frame change
  is one int write, which replaces today's `frame_uv` and the six texture
  parameters.
- **Shaders.** A single include provides
  `packed_fetch(pool, t = ivec2(floor(UV·cell)))`: transparent outside the
  box, otherwise `texelFetch(pool, ivec3(page_xy + t − box_xy, layer), 0)`.
  It replaces every `texture(sheet|component_*, uv)` in `modular.gdshader`,
  `native_scene_vertex.gdshaderinc`, `shadow_caster.gdshader` and
  `native_scene_support.gdshader`. The shadow taps stay clamped to the cell.
- **CPU.**
  - Picking and sockets use `packed_texel` over the colour pages, kept as CPU
    Images of k × 64 KiB instead of the 7.5 MiB sheet.
  - The prepack adds palette ranges and compact socket samples. Their inputs
    are the alpha > 0 texels, all inside the boxes, so the result is the same.
  - The condition outline and Studio thumbnails draw through the same
    packed_fetch (Sprite2D cannot address an array layer).
- **What disappears:**
  - per-path Texture2D and CPU Image for modular media (2.4 GB of RAM);
  - modular PNG decode workers;
  - per-path LRU touches;
  - role/family/selection accounting for modular media;
  - six texture parameters per layer material;
  - the clip-change world cut, which exists for texture readiness.
- **Proof.** The Studio replay gate (byte-identical `*-primary`) with both
  paths behind one switch, then the old path is deleted.

## Risks

- `texture_2d_update` on array layers may stall or serialize on the render
  thread. Measure it in the door route before adopting.
- Array layer limits (2,048) and pool sizing against the 2.5 GiB budget.
- The oracle here is CPU-side. Phase 2 must add the GPU capture proof.
- Bundles carry all three normal profiles. Splitting them per profile saves
  disk only, since load is already about 1 ms.
- Raw bundles take 5.2× the PNG disk bytes. Zstd costs +0.5 ms per bundle
  load.
- Consumers outside the actor path still bind a `sheet` texture directly: the
  workshop `modular_3d.gdshader`, and many tests.
- Every bundle needs a valid colour box. The prepack fails loudly if a box
  ever exceeds a page.
