# Editable NDClient authoring

This directory is Git-tracked source. It is the NDClient copy of the effective
Pygame authoring, updated to the selected Factory replacements and the installed
artwork paths. Editing it does not change Pygame's `game/data/` files.

## Files and ownership

- `catalog-index.json` assembles the existing `AnimationData` fields. It maps
  existing identities to files; it does not assign new spell or creature IDs.
- `spells/` contains all 149 spell/effect drafts, including gestures, sockets,
  release/contact timing, travel, impacts, damage feedback and child outcomes.
- `catalog/` contains action and condition recipes, rig registrations, material
  and palette behavior, resource URLs and the remaining catalog fields. Conditions
  keep their independent application, persistent and removal lifecycle.
- `characters/sheet-components.json` holds per-source body/shadow/accent
  annotations. [Character authoring](characters/README.md) explains whole-layer,
  source-RGBA and registered-mask records, plus the implemented source-interaction
  material for all Goblins/Demons. Original body/shadow/effect inputs drive the same
  reusable shader in the inspection page. Other packs retain initial partition
  qualifications; these labels are not a universal shadow/swoosh/depth filter.
- `media/definitions/` contains the selected asset definitions and phase metadata.
- `media/storage/` binds those same IDs to ordinary frame regions or paired bank
  selections, including windows, directions, components and coalescing.
- `media/banks/` contains the 193 shared depth/normal banks: clocks, crop/canvas,
  pivot, camera matrices, radiance interpretation and appearance/geometry URLs.
- `world.json` owns world material bindings. Spatial, construction, concentration
  and deposit mappings are referenced from the catalog index with JSON pointers;
  they are not duplicated as separately editable catalog files.
- `assets.json` holds the selected image resources and their authored geometry.
- `ui/index.json` assembles the existing UI resource, presentation, choice,
  selected skin and font sections. [UI authoring](ui/README.md) connects the
  selected icons/portraits, preserves all 103 choice records and records the
  Skeleton Warrior portrait and dedicated Unarmed icon gaps. Free portraits do
  not create native content assignments.
- `items/index.json` assembles the existing item appearance, material and variant
  documents, plus `materials/source-palettes.json`. [Item authoring](items/README.md)
  locates the four source owners, held/ground selections, coatings and equipment
  layer references. They reuse the installed modular library and retain existing
  authored values; item attachments remain in `catalog/item_attachments.json`.
- `environment/index.json` assembles the selected existing `EnvironmentDocument`: 324 banks,
  11 door families, 12 traps, 113 props, 28 wreck records and two ordinary-wall
  destruction mappings. It retains opening/state/destruction choices, parent and
  insert behavior, frame/leaf associations, source pivots and depth calibration,
  masks and passage points. Paths reference existing `/media/environment/` files.
- `environment/banks/` groups the existing banks by family and state. Door, prop,
  trap and wreck selectors have their own readable files; bank IDs are unchanged.
- `environment/source-records/` preserves the 60 delivered records, their units,
  evidence and qualifications, plus installed-media addresses. Existing native
  assignments link from the corresponding door/prop's `authoring_record`; these
  records are inspection sources, not alternative collision or placement rules.
- `schemas/environment.schema.json` comes from that same Python owner. Existing
  `actor_depth` and optional `surface_geometry_by_pose` remain available for new
  companions; no new normal export is required to load existing authoring.
- `schemas/assets.schema.json` and `schemas/world.schema.json` use the existing
  passive owners. Static `geometry_region` locates a sampled companion alongside
  existing ray-depth calibration. `wall_corner_faces` preserves the existing
  wall join rule separately from cliff corner faces.
- `schemas/animation.schema.json` comes from the existing passive Python owner,
  extended for paired banks. Ordinary parameter edits do not regenerate schemas.

The selected catalog retains 160 condition recipes, 236 condition media layers,
1,054 media identities and 2,730 resource bindings. Of those media identities,
392 select replacement banks; preserved casting/travel layers remain ordinary
sheets. These counts describe prepared authoring, not completed renderer support.

## Binding examples

`spell.fireball` keeps its existing impact ID
`shared.fireball.20ft-ground.smoke.v3`. Its storage now selects `core:fireball`,
frames `[0,46)` at 24 FPS. The bank points to
`/media/vfx/areas/fireball/explosion/{near,far}/…`; the stable `.v3` ID does not
select old pixels. Travel and casting sockets retain their independent authoring.

The impact storage also owns Fireball's `emitter`, adopted from the accepted
v4 demo on 10 October at the user's request. Its seven linearly interpolated keys
retain the demo's 0.44 s peak and fade to zero at 46/24 s. Times use the demo's
playback clock, positions are already in occurrence-local host `[x,height,z]`
units, ranges remain grid units, and intensities include the demo's ×4 gain.
Do not apply that transform/gain again or emit one light per near/far packet.
This is the demo's fitted cosmetic curve, not recovered physical emission or a
gameplay illumination rule. Other spell media currently have no `VisualEmitter`
curves; their authoring is deferred until Fireball is tested in the shared renderer,
as agreed on 10 October. None are inferred automatically from bright pixels. Shared rendering
consumes this same optional field when its lighting path is implemented.

Ice Knife enables the delivered burst, with coverage debris and the additive
zero-opacity flash kept as separate components. Thunderwave retains the whole
crest and occurrence coalescing. Sunbeam uses the source's explicit directional
mapping. Frigid Air uses wall-axis selection. Flat condition sheets, procedural
Lightning/Chain Lightning and construction operators remain their own kinds of
media. No retired XYZ storage or conversion fallback is selected.

## Edit and assemble

Edit these JSON files directly. From the repository root:

```sh
python3 tools/build_authoring.py
python3 tools/build_authoring.py --output .runtime/presentation.json
python3 -m unittest discover -s tests -v
```

The first command checks installed resource references. The optional output is
an assembled catalog/world/assets/environment document with the four item/palette
and five UI sections, using their existing shapes; it is a
preparation artifact, not the complete application release. Build needs no
Pygame, native engine, Factory, copy receipts or media import. The installed
artwork must be present for the resource check. `/media/` will map to `.media/`.

`tools/import_vfx_authoring.py` performed the initial import through the existing
engine exporter. It refuses to run when `authoring/` already exists, protecting
client edits. Do not delete this directory to refresh artwork. Family copy tools
only refresh private media/receipts; intentional binding changes are edits here.

`tools/import_environment_authoring.py` adopted the current non-Desert engine
selection once, preserving all selected bank and state values and relocating
only file addresses. It refuses to replace existing client authoring or schema.
New export channels belong in the corresponding existing bank/resource record;
do not rerun intake over client edits.

Stair contacts, support offsets and cliff corner directions remain single-owned
in `world.json`. Door/frame selections and source pose offsets are in
`environment/doors/` and `environment/banks/`. The 60 delivered supplemental
records now live in `environment/source-records/`, with their original evidence
and installed-media addresses; relevant existing door/prop owners link to them.
They are inspection references, not automatically selected runtime geometry. Source
example layouts are not universal compatibility rules. The six indoor-door mounts
and timber support correction are now connected at the typed bank/door/library
owners: physical contacts, camera mapping, effective transforms and finite
member/support data. Normal assembly requires no source-record interpreter.
The 10 October assembly pre-phase verified source registration preservation,
independent contact/projection arithmetic and all affected samples. No additional
artist measurement or artwork copy was needed. The fractional-rise timber flight is not
substituted for the selected two-step staircase. See the engine's
[environment handoff](/mnt/c/users/tommaso/documents/dev/dnd_engine/agent_docs/audits/ndclient-environment-assets-20261009/README.md).
This adoption does not claim renderer, adjacency selection or placement acceptance.

The raw Factory manifest and capture provenance live in ignored
`.runtime/vfx-replacements/`; they are intake evidence, not runtime authoring.
Pixel/plane files live in ignored `.media/`. The original Pygame JSON and source
artwork were not overwritten by this migration.
