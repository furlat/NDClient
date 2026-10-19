# Characters presentation source

`authoring/characters.tres` (a `PresentationSourceRoot`) lists every entry of
this domain; each entry is one `.tres` here. The build
(`tools/build_presentation.gd -- --only=characters`) checks them and writes
what the game and the Studio load into `build/presentation/characters/`.
Asset paths are relative to `res://assets/`. Classes:
`presentation/source/characters/`.

| Section | Folder | Key | What it holds |
| --- | --- | --- | --- |
| `rigs` | `rigs/` | client rig id (`neuroclient.modular`, `smallscale.goblin01`, `smallscale.undead.3darkknight`) | One art variant: cell, pivot, anchor, facing rows, slots, clips (role, source clip as the files name it, frames, fps, loop, markers, sheet keys, art per layer, body surface), stand-in fallbacks, body contexts, shadow mode, measured data path. 260 rigs: the layered rig and every delivered variant. |
| `characters` | `characters/` | server creature id, plus `creature.player.humanoid_body` | The rig that draws it, portrait, size notes, attack variants, cast gesture, reactions, death clip, kit mismatch, status. |
| `parts` | `parts/` | modular category (`Chest7`) | Its sheet per action with depth and normals (original, gentle, reference) and masks, its source palette, measured socket samples. |
| `gear` | `gear/` | server item id | Looks per visual slot and variant, hand overrides, dropped look, icon. Ids that share a look name their `family` and the visual variant they stand for. |
| `appearance` | `appearance/` | `modular` | How `AppearanceConfig` fields and equipment slots map to rig slots and parts (beard is `Head2`). |
| `portraits` | `portraits/` | bank (`player`, `creature`) | Portrait id to image, labels, hero aliases, named sizes. |
| `ui` | `ui/` | `common` | HUD control icons. |
| `sheets` | `sheets/` | `external` | Other domains' images that cast layers name by sheet key. |

Measured data (pose sockets, rest anchors, clip sockets, surface-socket
samples, palette ranges) is in `assets/measured/characters/`, produced by tools,
never hand-written.

`tools/presentation_build/convert_characters.gd` wrote this source once from the
earlier tables (`catalog/rigs.json`, `creature_rigs.json`, `resources.json`,
`characters/sheet-components.json`, `items/*`, `ui/*`, `generated/*geometry*.json`)
and from the deliveries under `assets/art`; values the game used convert exactly.
From now on these entries are the authority.
