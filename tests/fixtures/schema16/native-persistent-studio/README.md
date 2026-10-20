# Native persistent Studio lifecycle originals

20 October 2026. Original schema16 player journals from the frozen engine
`211b71134ed15c89e62232587381f7e15a5961c3`, schema digest
`49d14bc20920f5698eb4f09e3aeece442380242cd1453893d45f94ea9fb0c8a5`.
`cases.json` supplies all ten required lifecycle families and Ice Knife's
one-cast/multiple-application trace to `native_persistent_studio_checks`.

Each family retains its exact original scenario, issued commands/receipts,
recording result and both independent complete Amber/Blue packet streams.
Packets are copied byte for byte; there are 410 packets in total. No engine,
Factory, renderer, light, timeline or effect input was changed for this intake.
`lifecycle-evidence.json` is a direct original-packet index, not additional wire
facts, an alternative reducer or evidence that a frame was rendered.

| Family | Packets per seat | Actual disclosed owner application → removal in each seat | Lawful end |
| --- | ---: | --- | --- |
| Bane | 26 | condition UUID sequence 8 → 18 | Drop concentration after holder movement |
| Command | 24 | Grovel UUID 8 → 15 | Actual next-turn expiration; later target movement |
| Guidance | 22 | UUID 8 → 18 | Drop concentration after holder movement |
| Light | 22 | UUID 8 → 18 | Drop concentration under this frozen engine's actual rules |
| Mage Armor | 12 | UUID 8 → 10 | Caster equips actual inventory Chain Mail in Body slot |
| Resistance | 22 | UUID 8 → 18 | Drop concentration after holder movement |
| Sanctuary | 14 | UUID 8 → 12 | Protected ally casts an actual hostile Fire Bolt |
| Shield | 10 | UUID 6 → 8 | Actual Shield reaction intercepts Magic Missile, next-turn expiration |
| Shield of Faith | 18 | UUID 6 → 14 | Actual incoming attack, then drop concentration and recipient movement |
| Web | 26 | Two restrained UUIDs 8 → 18; spatial UUID created 8/removed 18 | Actual concentration removal retires body and area owners |
| Ice Knife | 9 | No persistent owner claimed | Actual cast and burst: five Spell facts/four Damage facts |

Sequence columns describe these recordings' independently inspected public
streams. They do not establish a global cursor or equal occurrence identities
between factions. Exact actor/condition/spatial UUIDs, local occurrences and
lineages are recorded in each seat's evidence section. Command covers the
actually offered Grovel branch; it does not claim Halt/Flee were executed.

Nine new successful recipes live in
`tools/studio_cases/cases.py::native_persistent_studio_studies()` and are part of
`first_cohort()`. They can be selected through the existing recorder, e.g.
`python3 tools/studio_cases/record.py --only spell.guidance/studio_uuid_lifecycle --out <separate-output>`.
They use only normal published roster setup, offered choices, Preview and
committed player commands. The recorder owns and closes its backend. No fixture
is refreshed by the test suite.

The new originals came from
`.runtime/scenario-persistent-studio/20261020T050230.445464Z/` except Mage Armor
and Web, whose successful bounded retries came from
`.runtime/scenario-persistent-studio/20261020T050421.392250Z/`.
The first Mage Armor attempt legally rejected the requested ally target and
reported only the caster as offered. The successful recipe uses that offered
caster, moves while the actual owner is present, then equips its real Chain Mail.
The first Web attempt requested movement to [3, 8], occupied by the ally; its actual
Choices rejected that cell. The successful recipe moves the caster to [3, 6].
Both failed attempts and their original partial journals remain in the first
runtime folder; no emitted packet was repaired or silently retargeted.

Shield of Faith reuses the already successful complete current capture at
`.runtime/scenario-expansion-20261020/cases/spell.shield_of_faith__defend_then_remove/20261019T233723.038256Z/`.
Its unchanged reproducible recipe is already in `interaction_cohort()`.
Ice Knife reuses the unchanged current baseline at
`.runtime/studio-library/cases/spell.ice_knife__baseline/20261019T144555.177965Z/`.
Each family's `provenance.json` retains its exact source and engine identity.
Server credentials/configuration, logs, host processes and spool files are not
part of this fixture tree.

Qualification at intake: all eleven original recorder results succeeded, direct
packet inspection found every required body's same UUID removed in both views,
and Web's actual spatial owner was also removed. All owned backend PIDs were
confirmed closed. Independent SDK/Studio gate execution, native framebuffer
qualification and visual acceptance are separate and are not claimed here.
