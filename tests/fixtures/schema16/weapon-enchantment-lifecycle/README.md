# Exact equipped-weapon lifecycle originals

Frozen engine `211b71134ed15c89e62232587381f7e15a5961c3`, player schema16.
Source recipes are `tools/studio_cases/weapon_enchantment_cases.py`. Actual
SDK recordings used the existing `worker.py`/`adapter.py` under the frozen
export; no official engine or Factory files were changed.

Each family contains byte-preserved `scenario.json`, `recording.json`,
`commands.json`, and complete independent `amber/journal`/`blue/journal` streams.
No authentication, server configuration, logs, artwork or generated captures
are included. Local occurrence IDs remain specific to each audience.

| Family | Commands | Packets per seat | Original result |
|---|---:|---:|---|
| magic-weapon | 17, all committed | 29 (0–28) | **Failed required owner observation:** real equipped cast/use/concentration release/replacement, no disclosed Magic Weapon condition/item effect. |
| shillelagh | 13, all committed | 23 (0–22) | Passed actual condition application, weapon use, unequip removal and replacement use. |
| divine-favor | 17, all committed | 29 (0–28) | Passed actual condition application, weapon use, concentration removal and replacement use. |

The caster is an ordinary authored generic caster with
`appearance.presentation_kind = "layered"`, an initially equipped Quarterstaff,
and an inventory Longsword. The actual attack item UUID changes after accepted
unequip/equip commands. Divine Favor's held attack missed, so this corpus does
not qualify a positive Radiant rider. No seed retries selected a desired hit.

`cases.json` preserves the two successes and genuine Magic Weapon failure.
Public provider, native rendering and visual acceptance remain separate gates.
Detailed owner/item/cursor and producer evidence is in
`agent_docs/WEAPON_ENCHANTMENT_LIFECYCLES_2026-10-20.md`.
