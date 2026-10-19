# UI artwork intake reference

The production source is now the typed `authoring/abilities/` ImageRefs and
`authoring/characters/` portrait banks and character assignments, assembled by
the three `.tres` roots. The ordinary presentation build emits the HUD's icon
maps from those owners. These JSON files preserve the earlier intake and its
source artwork assignments; they are not a second runtime UI catalog.

Current exhaustive coverage and named remaining art gaps are recorded in
`agent_docs/UI_ART_COVERAGE_2026-10-19.md`. The 18 October delivery supplied the
previously missing Unarmed icon and additional creature portraits; the old gaps
and counts below describe the earlier intake, not the present production state.

## Historical intake

This is the editable client copy of the existing UI presentation data. It uses
the installed **smooth48 icons and 192×256 portraits**. No artwork was copied,
cropped or resized during this adoption; Pygame's JSON remains unchanged.

`index.json` assembles the existing `PresentationCatalogExport` sections:

| File | Existing type / source | Selected content |
| --- | --- | --- |
| `resources.json` | `ImageResourceSource`; delivered replacement and portrait lookups | 620 icon keys → 594 images; 661 portrait images plus five premade aliases. All paths are readable `/media/ui/…` URLs. |
| `presentation.json` | `UIPresentationDocument`; engine `game/data/ui_presentation.json` | 48 direct features, 374 direct items, eight common selections, 618 free portraits and five premade defaults. |
| `choices.json` | `ChoiceRecord`; delivered `choice-bindings.json` | All 103 exact owner/choice/icon records: 77 discovery facets and 26 configuration-only selections. |
| `skin.json` | Existing `SkinSource` maps | Empty: rejected legacy panel/slot artwork is not selected. |
| `fonts.json` | Existing `UI_FONT_FAMILIES` | Readable system-font preferences, not rasterized text. |

## Resolution and ownership

An admitted native descriptor already supplies `presentation.icon_key` and/or
`presentation.portrait_key`. Prefix these with `icon:` or `portrait:` and look
them up in `resources.json`. For example, Fireball's `spell.fireball` key selects
`/media/ui/icons/smooth48/spell.fireball.png`; the Goblin's `creature.goblin`
portrait key selects `…/creature-portraits-bg1-2026-10-08/goblin.png`.
All 462 currently bound native icon definitions resolve through this resource map.
There is no second client content registry or full private descriptor manifest.
An available image does not reveal an entity or make an action available.

Direct features/items and common controls retain their existing owners and keys.
Item-specific reuse notes remain explicit; blanket notes about the replaced icon
bank were removed. Condition icons are separate from their world VFX and overhead
markers. In particular, Slow and Ray of Frost retain distinct icon resources.

For portraits, an actor's explicit appearance selection wins; otherwise use its
native descriptor's portrait key. **43 delivered native assignments** were joined
against `catalog/creature_rigs.json` by their exact existing identities and rigs.
The other **618 portraits** (432 player and 186 unassigned creature/source images)
are selectable artwork only. They do not create creatures, rigs or playable classes.
The full 192×256 image is registered: no hard-coded initiative/HUD crop or duplicate
role-sized resources. Layout may scale it or intentionally crop it later.

These five existing premade aliases have new editable defaults. These selections
were made during adoption; they were not supplied as exact native assignments:

| Existing premade | Selected image key |
| --- | --- |
| `hero.barbarian_l5_berserker_torch.hero` | `barbarian--human-white--male` (Cordan) |
| `hero.fighter_l5_archer_torch.hero` | `fighter--human-white--male--extra-01` (Torvin Ashford) |
| `hero.fighter_l5_shield_torch.hero` | `fighter--human-white--male` (Hadrik) |
| `hero.sorcerer_l5_standard_torch.hero` | `sorcerer--human-white--male` (Keldan) |
| `hero.fighter_2_sorcerer_3_spellblade.hero` | `sorcerer--human-white--male--extra-01` (Eldwin Prydwyn) |

The modular **Skeleton Warrior** is the sole current creature-rig identity without
a delivered portrait assignment. The Skeleton Archer assignment is preserved as
the Archer; it is not silently assigned to the Warrior. The existing common
`unarmed` selection also has no dedicated icon in the supplied bank and retains
its explicit null. Neither gap prevents the other mappings from being used.

## Choice values

`ChoiceRecord` remains the shared passive owner in `game/ui/media_types.py`.
Existing `owner`, `facet`, `value`, `icon_key`, `label` and `requirements` remain.
The optional `field` identifies the native configuration field; optional
`field_value` supplies its value only when different from the discovery value.
No gameplay recipes, availability rules or slot requirements were copied here.

- Facet choices match `facet`/`value`; their prerequisites name other facets.
  Wall of Fire sides still require `form=segment` or `form=ring`. Native
  `wall_form` is retained by that owner's `field=wall_form, facet=form` records.
- Configuration-only choices have `facet=null` and match `field`/`value`.
  Bestow Curse retains integer options and `curse_option: 1` prerequisites.
- Spirit Guardians uses delivered lowercase facet values `radiant`/`necrotic`
  and native `field_value` values `Radiant`/`Necrotic`, correcting the old facet
  casing without changing the native enum. These are distinct values, not two
  independently authored representations of the same choice.

Icon availability is not a reason to display an unnecessary control. For example,
retaining wall-side icons does not reinstate rejected left/right confirmation UI;
the gameplay interface must follow the current targeting rules in the master plan.

## Sources and completion boundary

Initial adoption used the delivered files under
`/mnt/c/Users/tommaso/Documents/assets/dnd-engine-icons-and-portraits/`:
`ui-icons-bg3-glyphs-2026-10-07/replacement-bindings.json`, `choice-bindings.json`,
and `production-lookup.json` in the selected full-matrix-v2, white-expansion and
creature banks. Their original source snapshots remain in ignored
`.runtime/ui-assets/authoring-reference/` for provenance, not runtime lookup.

`tools/import_ui_authoring.py` performed this one-time adoption using the existing
passive types. It refuses to overwrite the editable JSON or schemas. Ordinary
builds read `authoring/ui/index.json` without engine imports, intake receipts,
source snapshots or source artwork. `schemas/ui-*.schema.json` derive from the
same existing owners; no parallel client UI type system was introduced.

**Authored-data adoption is complete, with the two named art gaps above.** Shared
UI lookup, widgets, choice interaction, SDK admission and the actual game HUD
remain future runtime work. This step does not claim a working UI screen.
