# Godot intake — elementals and dragon variants, 21 October 2026

Durable release:

`C:\Users\tommaso\Documents\assets\summon-creature-lab-2026-10-20\production-2026-10-21`

WSL: `/mnt/c/Users/tommaso/Documents/assets/summon-creature-lab-2026-10-20/production-2026-10-21`

Review: `http://127.0.0.1:8809/production-2026-10-21/` or local `index.html`. This static asset viewer does not involve the game/backend server. Production runtime files and bindings were not changed.

## Elementals: finished art and actual 3D geometry

Read `elementals/HANDOFF.md`, `manifest.json`, `inventory.csv` and `validation.json`. Portable archive: `elementals-production-2026-10-21.zip`.

Earth, Water, Fire and final legless Air each have nine actions, eight facing rows and 15 frames at 12 fps: **36 banks / 4,320 poses**. Colour/depth coverage matches exactly. Cells are 192×192; sheets 2880×1536; columns 0–14; rows E, SE, S, SW, W, NW, N, NE. Fixed contact is (96,138).

Use this Air instead of the old version in the original sprite-delivery ZIP. Its attacks/cast remain continuous; its separate wind death remains. Earth Death retains rubble; Water Death retains a puddle; Fire/Air retire clear. Idle/Walk wrap directly; other actions use state-driven recovery. No Ice or armoured Myrmidon bodies are included.

Existing body IDs: `creature.spell.air_elemental`, `creature.spell.earth_elemental`, `creature.spell.fire_elemental`, `creature.spell.water_elemental`. Adopt them through existing creature/body authoring. Backend sizes, reach and combat events remain unchanged. Alias the existing `Die` role to supplied `Death` deliberately; no hit/release event timestamps were invented.

### Operands for the inspected character consumer

`presentation/character_geometry.gd`, `presentation/native_scene_vertex.gdshaderinc` and `modular.gdshader` expect optical RGB normals and affine 8-bit depth/support. The authoritative export instead contains RG16 ray depth / BA octahedral WORLD normals. **Do not pass that canonical PNG into the current decoder.**

Each bank's `current_consumer` supplies the derived operands for the existing importer:

- `files.depth`: `depth-affine.png`; `files.normal`: `normal-optical.png`.
- `files.support` and `files.normal_valid`: the same exact `support.png`.
- `normal_paths.original`: the optical normal, not the world-normal preview. No additional normal profiles were invented; production retains profile admission.
- `depth_range=[-46,99]` source pixels; decode `d=lo+(Rbyte-32)*(hi-lo)/192`.
- `optical_camera.origin=[96,138]`, `elevation_degrees=30`, `cell_size=[192,192]`.
- **Set `optical_ground_pixels=0.0` explicitly.** Omitting it falls back to 19 pixels in the inspected consumer and would lower this export incorrectly. Its reconstruction is already ground-relative; `native_scene_ground_height` therefore equals zero.

The normal basis is camera-right, camera-up, camera-toward. Facing is baked; do not yaw it twice. Existing canvas-Y conversion applies once. Read numeric textures with nearest filtering and no sRGB conversion, premultiplication, mipmaps or lossy compression. Disable alpha-edge repair on canonical geometry: its A channel contains normal data.

The canonical 16-bit depth is unchanged. Compatibility depth adds at most 0.0188793 m (0.377585 source pixels) and optical normal quantization at most 0.376239°. Both errors are measured against canonical channels. `decode_geometry.gd` gives the canonical decoder and passed a native Godot compile/decode check.

Current `component_units` equals display scale / `(64*sqrt(2))`; this source uses 20 pixels/metre. Supply the correct 192-pixel cell and contact through existing authoring. Choose display size against authored in-game creatures; optical bounds do not define mechanical footprint. Colour contains approved lighting/emission rather than unlit albedo. Air's wind death advects reconstructed 3D surface samples with carried normals; it is not a new mesh fluid simulation.

## Dragons: colour/motion prepared; geometry deferred

Read `dragons/HANDOFF.md`, `manifest.json`, `inventory.csv` and `validation.json`. Portable archive: `dragons-colour-2026-10-21.zip`.

Ten appearances: original Dark/Light; Violet astral, Silver blue and Pale gold; Fire, Cold, Lightning, Acid and Poison material forms. They preserve 15 native actions and eight source views: **1,200 banks / 20,880 poses**. The five material forms use the final clean spirit recipe without the added procedural web or hard rim. They are visual candidates, not new spell bindings.

Preserve all 8–30 native frames/action. The reviewed clock is 12 fps; vendor FPS remains unknown/null. Original source crops used XYXY while spirit exports used XYWH: **every packet `crop_xywh` is normalized XYWH**. Originals restore to a 512-pixel canvas; spirit/material captures restore to 768 pixels. Keep recorded contacts and display scale 2; Draconic Spirit occupancy stays 2×2 tiles, independent of wings/tail/aura.

Angles 000–315 retain vendor image-space headings. Measure their engine-facing adapter rather than copying elemental row labels. Original shadows are separate shared layers. Spirit/material PNGs already include the source shadow at 0.28 opacity; do not add the full shadow again.

Use existing `creature.spell.draconic_spirit` and existing appearance authoring. **No dragon depth, normal maps or recovered 3D body rig are supplied.** They are null/pending in every bank, as requested. Real per-pose mouth sockets/optical regions for DraconicBreath also remain pending: aura anchors are not mouth contacts. No dedicated swimming or flying-melee clip was authored. Preserve explicit role/event limitations.

## Verification and editable sources

Each packet contains a verifier, bank hashes, checksums, inventory, evidence and source index. All 4,320 elemental and 20,880 dragon poses passed structural checks. Browser checks cover 330 selections / 2,640 views, stable counters and live loop wraps. Final archive checks are in release-root `archives.json` and `release-validation.json`.

Run `python verify_packet.py` inside either packet with Pillow and NumPy. Native Blender/Godot/vendor sources remain durable at paths in `source-index.json`; large caches are not duplicated. This handoff supplies assets and encoding/registration details. Tracked authoring adoption, measured game-facing/scale admission and runtime integration remain production work.
