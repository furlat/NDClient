# Environment authoring

`index.json` assembles the existing EnvironmentDocument. These files are the
editable NDClient sources; Pygame JSON and artist exports remain unchanged.

| Folder/file | Owns |
| --- | --- |
| `banks/doors/<family>/<state>.json` | Opening and destruction frames, leaf/frame registration, clocks, existing depth |
| `banks/props/`, `banks/traps/`, `banks/windows/`, `banks/walls/` | Corresponding source-frame registrations and state animations |
| `doors/`, `traps/`, `props/` | Existing native item IDs selecting those banks |
| `wrecks/` | Settled outcome association with the original item family |
| `walls/destructions.json` | Existing material-to-debris choices |
| `library/` | Existing catalog families, explicit source samples, clocks and surface companions |
| `source-records/` | Received assembly/placement evidence and installed-media links, including unused library assets |
| `../world.json` | Terrain, G17 stair contacts, G12/G13 supports, wall/corner selectors, fixture transitions |
| `../assets.json` | Registered images and animations, source pivots, geometry, water channels |

Media paths start at `/media/environment/`, mapped directly onto `.media/environment/`.
Active files are grouped under doors, walls, windows, props, traps, devices,
terrain, fixtures, portals, lighting and water. `library/` preserves the original
Fantasy art and workshop exports, including currently unselected assets. File
moves did not modify pixels, rescale art or change animation rates.

## State and animation connections

- Doors select an opening by swing and destruction by open/closed state and
  outcome. Closing uses the authored opening frames in reverse. Retain the
  selected `pose_offset`; external frame poses differ from leaf poses for C1/C3.
- Traps retain ready/activated/deactivated frame selections and corresponding
  destruction banks. World fixture transitions also retain contact/release and
  activation markers, projectile/muzzle registrations and existing attachments.
- Chests select the authored closed/open banks from `is_open`.
- Window parent walls and inserts remain separate. Parent destruction selects
  the after-insert variant when its insert is already absent; removing a parent omits its attached insert.
  Masks, aperture registration and passage points remain with their owners.
- Destruction clocks, frame counts, sampled times and final states remain as
  authored. Nothing is normalized to a blanket frame rate.

## Geometry and placement

The current depth/normal delivery is installed. The original colour registrations,
clocks and IDs are unchanged; media copies remain ignored by Git. Static images
carry geometry/normal/support/role data directly. Banks use
`surface_frames_by_pose`, matching their existing colour frame clock. Devices
preserve pitch/camera/aim/frame axes; the hatch front and moving layer stay separate.
The existing legacy actor-depth packets retain their original byte meanings.

`library/` contains the 725 existing catalog family IDs with explicit original
colour/frame/view/variant records. Unspecified pivots, scales or clocks remain
unspecified. Library art acquires no new native item or gameplay assignment.

Colour and numeric data are separate registrations. Native index lookup uses
`floor(colourIndex * scale + offset)` and the declared pixel centre; out-of-range
samples are absent, never clamped to create a surface. This handles both half-size
packets and translated crops. Numeric PNG channels are lossless data, not opacity
or colour. Raw masks declare their storage, byte order and exact region. Normal
transport uses the supplied effective matrix once; export-time transforms already
baked into the packet must not be applied again.

Support and component labels retain their meanings. Ground shadows, dust, flames,
cloth, aperture mattes and surface paint are distinguished from solid receivers;
a paint overlay retains its parent resource. Role-specific geometry is retained
where supplied. D6 includes both its sampled ray packet and aperture-preserving
receiving mesh. Source/inferred qualifications remain alongside the data; a
visible receiving mesh is not a new gameplay collider or a hidden closed volume.

The six generated indoor doors and timber flight have their delivered physical
mount/assembly corrections connected to existing bank/door/library placement
metadata (10 October). Banks carry `physical_source_contact_by_pose` and
`camera_quarter_by_pose`; library samples use `physical_source_contact_px` and
existing `camera_quadrant`. The effective geometry/normal matrices are mounted
once. Door `assembly_variants` keeps each compatible header/partition set together;
timber `support_profile` preserves continuous treads and its separate landing.
The raw `pivot` is retained: sprite position is projected floor anchor plus
`scale * (rawPivot - physicalContact)`. Generated door/timber capture order is
e0/s3/w2/n1, while their neighboring wall/floor families retain e0/s1/w2/n3.
Original image pivots are separate from physical floor contacts. The timber fractional rise is
not substituted for G17. Wall corners use `world.wall_corner_faces`: NE→e, ES→s, SW→w, WN→n.
Join only exactly two perpendicular walls sharing owner, material and base height;
retain provider identities and replace their two straight drawings with the corner.
Cliff corners have a separate authored map. A corner pose is not an elevation or
adjacency permission. B13/B44/B45 source qualifications remain explicit; native
code continues to own collision and traversal.

Build with `python3 tools/build_authoring.py`. It assembles current JSON without
the engine, source exports or `.runtime/` receipts. Source records are authoring
references, not another runtime asset registry. Renderer and Studio consumption
are the subsequent application work, not something this preparation claims to do.

Environment companion adoption is complete (10 October): 42,805 required files (1114.43 MiB) were copied into the existing readable family folders. Tracked authoring now includes all 324 selected banks (24,632 pose/frame associations), the selected static resources, device/hatch layers and 725 library families (67,272 explicit samples). All seven assembly closures are connected to typed authoring; source records remain provenance. The focused checks cover 30 banks, 5,736 door library samples, 124 timber samples and seven member families, with original registrations/clocks preserved.
