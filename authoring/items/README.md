# Item appearance and materials

**Production editing:** use the typed gear resources listed by
[`characters.tres`](../characters.tres), particularly
`characters/gear/*.tres`. `PresentationGear.slots` owns worn choices;
`ground` owns exact dropped variants, four camera rows/pivots, scale, tint and
the original shadow. `family` declares explicit compatible reuse. The shared
body and environment paths consume these fields. Intrinsic decorations and
actual item-effect memberships use the existing gear EffectUses and the shared
ability item-attachment context; item/effect UUIDs and the real holder keep
their original clocks. See [current authoring ownership](../README.md).

The JSON intake below is retained as historical source material, not the
production edit/assembly command or a current missing-renderer claim.

`index.json` assembles four existing `PresentationCatalogExport` fields. These
are editable client copies, with the original category, variant, slot and
behavior identities preserved:

| File | Existing owner and source | Contents |
| --- | --- | --- |
| `appearances.json` | `ItemAppearanceDocument`, engine `game/data/item_appearances.json` | 100 hand selections and 404 ground selections, including layered clothing, camera rows, contacts, scale and shadows. |
| `materials.json` | `ItemMaterialDocument`, engine `game/data/item-materials.json` | Nine enchantment/coating treatments, with existing tint, bloom and priority. |
| `visuals.json` | `AuthoredItemVariantInventory`, engine `content_data/ledgers/neuroclient_authored_item_visuals.json` → `inventory` | 85 categories and 318 variants, their native factory associations, equipment layers, palettes and unsupported classifications. |
| `../materials/source-palettes.json` | `SourcePaletteDocument`, engine `game/data/neuroclient/source/src/render/data/animation/paletteMap.json` | 118 source palettes, including the existing grayscale classification. |

Equipment layers name the existing root rig's sprite categories. Its authored
clips select `/spritesheets/<category>/<action>.png` resource identities;
`catalog/resources.json` resolves those to the already installed
`/media/smallscale/modular/<category>/<action>.png` files. Adoption connected 325
missing sheet references across the 17 existing body actions. It did not add
new actions or change clocks, sockets, body size or equipment tints.

`catalog/item_attachments.json` remains the single owner of existing attached
effects. Item materials remain separate from body materials. Native mechanics
and the source ledger remain in the engine; the client does not recreate their
factories or make unsupported categories playable.

`tools/import_item_authoring.py` performed the initial adoption through these
existing passive Python types and refuses to overwrite these files. Ordinary
edits use the JSON here; `tools/build_authoring.py` assembles it without engine
imports or copy receipts. Schemas under `schemas/item-*.schema.json` and
`schemas/source-palettes.schema.json` come from those same owners.

These historical intake counts do not establish current assignment coverage,
native output qualification or human artistic acceptance.
