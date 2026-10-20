# Original production condition handover recordings

Frozen engine `211b71134ed15c89e62232587381f7e15a5961c3`, schema16.
These seven already successful baseline recordings were copied from
`.runtime/studio-library/cases/`; no backend or Godot run created these fixtures.

Each `spell.<id>__baseline/<timestamp>/` contains the unchanged original
`scenario.json`, `recording.json`, `commands.json`, and both independent complete
`amber/journal/` and `blue/journal/` streams (nine packets each, 0–8). That is 147
original JSON files. Configuration/authentication files, logs, artwork and
generated captures are excluded. Audience-local occurrence IDs remain local.

| ID | Original source timestamp | Recorded evidence |
|---|---|---|
| acid_arrow | `20261019T141826.056415Z` | Actual `condition.spell.acid_arrow` admission |
| divine_favor | `20261019T142511.372333Z` | Actual `condition.spell.divine_favor` admission |
| hex | `20261019T143104.526336Z` | Actual `condition.spell.hex.quarry` admission |
| hunters_mark | `20261019T144540.033289Z` | Actual `condition.spell.hunters_mark.quarry` admission |
| magic_weapon | `20261019T144735.744552Z` | Completed cast and Concentrating; **no Magic Weapon owner** |
| shillelagh | `20261019T144916.773864Z` | Actual `condition.spell.shillelagh` admission |
| starry_wisp | `20261019T143631.559288Z` | Actual `condition.spell.starry_wisp` admission |

This is six real admitted-owner positives plus Magic Weapon's real no-owner
negative. It is not seven successful condition lifecycles, an equipped Magic
Weapon demonstration, or a removal corpus. The three frozen producer failures
(Branding Smite, Searing Smite, Ensnaring Strike) are not represented as successes.

The focused test is `tests/production_condition_handover_checks.gd`; source,
scenario, native output and visual acceptance remain separate evidence.
