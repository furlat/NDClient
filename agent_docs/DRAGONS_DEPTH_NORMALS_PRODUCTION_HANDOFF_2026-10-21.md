# Dragons: selected depth, normals and separate shadow

21 October 2026. Selected by the user: **multi-view reconstructed depth + Sprite
Fusion Default normals**, shared across all ten dragon appearances. Colour is
shadow-free; the optional authored shadow is a separate shared animated layer.

This packet supersedes the dragon geometry-pending and baked-shadow intake notes
in `ELEMENTALS_DRAGONS_PRODUCTION_HANDOFF_2026-10-21.md`. Elementals are unaffected.
Production runtime and authoring have not been modified.

## Delivery

Folder: `C:\Users\tommaso\Documents\assets\summon-creature-lab-2026-10-20\production-2026-10-21\dragon-depth-normals`

Portable ZIP: the sibling `dragon-depth-normals.zip`. Read `manifest.json` in the
extracted folder. Asset paths are relative to that folder; source provenance is
not a runtime dependency on the larger laboratory or its absolute WSL paths.

The packet covers **15 actions, 8 output directions and 1,200 appearance banks /
20,880 appearance poses**. Ten skins share 261 anatomical time poses, rendered
into 2,088 action/frame/view poses. Two native layouts preserve the original
512-pixel canvas and the spirit/material 768-pixel capture canvas; these are
registered copies of shared geometry, not separate fits for each skin.

The selection contains reconstructed depth, Sprite Fusion Default normals,
separate receiving/depth/caster masks, clean colour for every skin and one
120-bank optional source-shadow library. No alternate normal profiles, raw voxel
caches, enlarged sprites or comparison screenshots are needed for import.

The packet contains 2,520 PNGs: 240 depth maps, 240 selected normal maps,
360 normal-admission masks, 360 depth/caster-support masks, 1,200 clean colour
sheets and 120 shared shadow sheets. Identical logical masks alias the same path.

Appearances: Original Dark/Light, Violet astral, Silver blue, Pale gold, Fire,
Cold, Lightning, Acid and Poison. Material variants remain visual candidates,
not new gameplay or spell bindings.

## Resolve the selected pair

Choose a manifest bank by `(variant, action, angle)`. Its files already select
reconstructed depth and **Sprite Fusion Default** normals. Do not take the old
laboratory manifest's reconstructed `normal_paths.original` as this selection.

`bank.colour.path` selects clean colour. `bank.files.depth` and `.normal` select
the numeric pair; the other entries select the independent masks described below.
`bank.optional_shadow.key` resolves a record in top-level `shadows`, which owns
the shadow layer's layout. Its relative `path` is also supplied on the bank;
`opacity_by_frame` is per appearance. All these image references stay inside the
extracted packet.

Preserve each bank's `frames`, `cell`, `columns`, `rows`, `crop_xywh`,
`frame_canvas`, `contact`, `optical_camera` and `depth_range`. Crops are XYWH.
For frame `f`, atlas column is `f % columns` and row is `floor(f / columns)`.
The cropped cell's contact is `contact - crop_xywh.xy`; do not centre it anew.

Every action retains its native 8–30 frames. Review playback is 12 FPS;
`source_fps` stays null because the vendor rate is unknown. Cycles loop directly;
combat roles, transitions, recoveries and event times remain production decisions.
No mouth sockets, breath-release times, swimming or flying-melee clip were added.

Output angles are vendor source IDs `000,045,090,135,180,225,270,315`. All 16
source views constrained depth reconstruction at actual 22.5-degree steps.
Do not infer engine compass rows from these filenames or rotate normals twice.
The measured source-to-game facing adapter remains intake work.

## Numeric textures and decoder

Load geometry with nearest filtering, no mipmaps, no sRGB conversion, no lossy
compression, no alpha-edge repair and no premultiplication of numeric RGB.

| Operand | Meaning |
| --- | --- |
| Depth | Affine RGBA8. R bytes 32–224 encode source-pixel optical depth in `[-180,309]`; alpha marks depth availability. |
| Normal | Sprite Fusion Default, numeric RGB8. Decode `normalize(rgb * 2 - 1)`. Axes are camera-right, camera-up, camera-toward. |
| Normal admission | This appearance's visible anatomical body, including native spirit death retirement. Independent of depth availability. |
| Depth support | This appearance's body intersected with valid reconstructed depth. |
| Caster support | The preserved reconstructed body/depth domain for the existing dynamic shadow caster. It is not the normal-admission mask. |
| Body visible | Anatomical body only. Aura, wisps, particles and source ground shadow are excluded. |

Depth decode for a normalized texture sample `r`:

```text
d = -180 + (r * 255 - 32) * 489 / 192
```

Use the bank's supplied local `optical_camera.origin` and fixed 45-degree optical
camera estimate. Set **`optical_ground_pixels = 0.0` explicitly**; the inspected
consumer otherwise has a 19-pixel fallback. This depth is already ground-relative.
Facing is baked. The existing screen/canvas Y-normal conversion happens once.
This is not the environment RG16-depth/BA-octahedral-normal format.

Receiving light may use a Sprite Fusion normal wherever its own admission and
normal alpha are valid. A missing depth sample must not flatten a valid receiving
normal. Conversely, a valid Sprite Fusion normal must never invent depth or caster
support. Unsupported depth stays unknown and contributes no depth-based shadow.

## Clean colour and one shared shadow

Use the new clean colour sheets from this packet. Original Dark/Light source
colour was already shadow-free. The eight spirit/material appearances were
exported again through their existing native renderer with only the ground-shadow
node disabled. Existing body-paint shaders, approved colour set, aura, wisps and
GPU death-dissolve recipe are retained. The previously approved baked composites and original source art
remain intact outside this packet.

One optional authored shadow bank per `(action, angle)` serves every skin. It has
its own source-cell grid, crop and contact. Draw it behind colour and align the
two **contacts** at the same point, preserving source-pixel scale. Do not stretch
its cropped rectangle to the colour rectangle or duplicate it for each skin.

The shared source shadow is neutral black plus source alpha. Apply the supplied
appearance/frame opacity separately: Original Dark/Light use 1.0; spirit/material
forms use 0.28, with the existing death fade `0.28 * (1 - f/(N-1))^2` for their
death actions. The final spirit death source shadow is therefore clear. It must
not retain the original dragon's terminal shadow after the body retires.

**When using production's dynamic depth-cast shadows, leave this optional source
shadow off.** Feed the selected reconstructed depth and caster support to the
existing dominant-light caster. Sprite Fusion normals only affect receiving
light; they do not replace caster geometry. The separate source shadow is an
optional authored presentation layer, not a second dynamic shadow or a light
occluder. Baked-shadow pixels are absent from the new colour layer.

The export disables the native source-shadow draw; it is not subtraction from
an already quantized PNG. Native pilot captures found that the old transparent
draw order let this shadow darken some translucent aura despite its shader depth.
In the four pilot captures, opaque body pixels and pixels outside the shadow
were unchanged when disabled; full-batch exceptions are quantified below.
Draw the separate shadow behind the new clean sprite; this intentionally does
not recreate the old translucent overlap ordering. Separate palette quantization
adds another reason the recombined layers need not reproduce the former final
composite byte-for-byte. Validation records both distinctions.

The clean export compares retained shadow-on raw captures against new shadow-off
raw captures at the same native pixels. Where raw RGBA is identical, the approved
finished colour is retained exactly to avoid unrelated palette lookup-order drift.
Changed overlap pixels use the existing approved theme RGB set, without fitting
a new palette or inventing colours; new native alpha and death retirement are
preserved. This is explicit source-pixel preservation, not shadow subtraction or
painting over the flattened sprite.

Full-batch preservation: **455,948,862 visible pixels** in the measured native
unchanged domain retain approved RGBA exactly. Visible changes are confined to
the actual native-change domain, and no new RGB colours were added. Among the
246,529,720 native-alpha-255 pixels, 544 final RGBA samples differ where the old
and new native renders themselves differed; 520 of those are inside anatomical
body masks and 24 are VFX-only. These measured native composite differences
remain part of the shadow-off export.
All native alpha, registrations and spirit death retirement are preserved.
See `receipts/clean-pixel-preservation.json`; pilot ordering measurements are in
`receipts/layer-pilot.json` and full native completion in
`receipts/native-layer-export.json`.

## Production integration

The inspected character binder assumes rig-wide cells/centred pivots and a
single frame row plus facing rows. These dragon banks retain varying crops,
grids and contacts. Add a measured native-bank layout adapter or a lossless
registered repack through existing authoring; copying paths into that assumption
will misregister the animation. Keep per-layer shadow registration independent.

Current `modular.gdshader` also gates receiving normals on depth/support. Adopt
the separate normal-admission rule above to retain the selected full-body
receiving result. Preserve the stricter depth/caster gate for dynamic shadows.
These are explicit consumer integration steps, not hidden runtime changes in an
asset package.

For the inspected `character_geometry.gd` consumer, the source descriptor's
`files.depth` maps to packet `bank.files.depth`; `files.support` maps to
`bank.files.depth_support`; `files.normal_valid` maps to
`bank.files.normal_admission`. The selected normal texture is
`bank.files.normal`. Retain its per-bank `cell_size`, local optical origin,
depth range and `optical_ground_pixels=0` when creating the existing descriptor.
Mapping those fields alone does not remove the old receiver's coupled-depth
gate or fix its atlas layout; both integration requirements above still apply.

Retain the approved display scale 2 and mechanical Draconic Spirit occupancy
2×2 tiles. Wings, tails, aura and optical depth extrema do not redefine footprint,
collision, game height or reach. The body source origin is registered, not an
invented breath-mouth contact.
Adopt through existing `creature.spell.draconic_spirit` and its appearance
authoring; shared asset availability does not create new creature identities.

The preview copies current production light-table/Lambert/ambient/accumulation/
cap equations. Its GL Compatibility display-output correction, inspection light
position/cookie and independent receiving-normal admission do not establish an
identical complete production render. Production declares Forward Plus; the GL
branch fix is not proof of a live production brightness bug. Preserve production's
light colour/range and dominant-light policy during intake rather than importing
the demo's inspection settings as game defaults.

## Evidence and limits

Reconstructed depth was independently checked against accepted canonical data:
mean anatomical view coverage 98.55994%; appearance-weighted depth support
98.59799534%; maximum affine depth quantization error 1.2734375 source pixels.
Thin unsupported silhouettes remain explicitly unknown.

Sprite Fusion Default was independently checked across all 120 action/view banks
and both layouts: unit-length error at most 0.00669806 after RGB8 decoding, with
100% receiving admission of the recorded visible-body masks. Coverage is not a
measurement of physical surface accuracy. The method infers relief from clean
Light body paint and outlines, shared across skins. Pinned upstream revision:
`d14b06726cabab09c68a403ce2e684a52efbfe4c`.

Default controls: normal strength 1.5, detail strength 6, detail scale 0.6, shape
strength 1.15, shape radius 4px, shape softness 1.15px, alpha threshold 0.03;
OpenGL normal axes, neither generator input axis inverted. Native 512×512 cells
were processed without resizing. These normals and the reconstructed depth are
independent estimates, not a recovered vendor mesh or a newly coherent surface.

The package's final validation receipt covers selected files, relative paths,
all 1,200 registrations and shadow/clean-colour layer export. Original geometry
and Sprite Fusion audit evidence remains in the source laboratory. Native
comparison covers representative poses, not every pose's artistic quality.

**Final independent acceptance: PASS**, `VALIDATION.json`, zero errors. All
2,520 PNGs are byte-exact copies of their accepted selected inputs. All 1,200
native registrations and internal image references match. Normal admission is
inside clean colour alpha everywhere, and all 128 spirit/material terminal death
colour frames and optional shadow fades clear. The selected PNG payload totals
1,128,324,790 bytes (about 1.05 GiB); the ZIP also includes this handoff, manifest
and compact evidence receipts.

The existing Godot inspector was rebuilt against all 1,200 clean packet banks;
its corrected receiving-light comparison completed 180 native captures across
two representative actions, three facings, five normal methods and three light
positions in receiving/normal-RGB modes. Sprite Fusion Default remains the
selected startup method. Diagnostic captures stay in the laboratory and are not
duplicated in this production packet.
