# Environment presentation source

`../environment.tres` (a `PresentationSourceRoot`) lists every entry below; an
entry file it does not list is a build error. Entries are keyed by the server's
ids (`authoring/server_ids.json`), client-only art by short client ids. Classes:
`presentation/source/environment/`.

| Folder | One entry per |
| --- | --- |
| `terrain/` | tile material (floor art per view, receiving, water look, material behaviour, stairs/ramps) |
| `structures/` | boundary structure × material (`wall.stone` = `wall/stone`): pieces, corner faces, cutaway, destruction |
| `objects/` | server environment object: states → banks or images, destructions, transitions, parts, light, masks |
| `library/` | catalogue piece no server id uses yet (fantasy-unified-catalog, Dimension Door portal, spell wall sections) |
| `surfaces/` | spatial effect, residue and decal: layer, effect uses, operations, amount look, old blocks |
| `connectors/`, `lighting/`, `battlefields/` | traversal kind; light appearance and the lighting entry; battlefield |
| `art/` | art piece (bank, images, library samples, device, portal, old sprite) the others name |

Measured registration (atlas rects, contacts, depth/normal packets and their
matrices, particle sets, delivered source records) lives in
`res://assets/measured/environment/`, its number text exactly as delivered. Art
paths are relative to `res://assets/`. `tools/build_presentation.gd` checks all
of it and writes `build/presentation/environment/`, the only environment data
the game and the Studio read.
