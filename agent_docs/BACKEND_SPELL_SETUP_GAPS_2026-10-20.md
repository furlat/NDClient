# Spare the Dying discovery and Hellish Rebuke trigger evidence

Frozen engine `211b71134ed15c89e62232587381f7e15a5961c3`, player schema16.
The official engine and Factory were not changed or run. Captures below retain
both original faction journals, actual selections and committed command receipts.
No native rendering qualification is claimed by a successful SDK recording.

## Result

- **Spare the Dying remains blocked in public discovery**, despite an adjacent
  lawful patient reaching exactly 0 normal HP and DYING through actual damage.
- **Hellish Rebuke has a successful ordinary single-target trigger**. The one
  bounded Dissonant Whispers probe produced its real reaction and 14 Fire damage
  in both journals. This is a usable recording candidate, not proof that the
  earlier area/group trigger failure is fixed.
- The three smite `game_failed` cases, unregistered Fixture Test Bless action
  and Mirror Image Factory shader error were outside this probe and remain
  separately reported in the complete live inventory.

## Spare the Dying: lawful patient, excluded discovery target

Original recorder attempt:

```text
.runtime/scenario-expansion-20261020/cases/spell.spare_the_dying__baseline/
20261020T000649.366845Z/
```

`scenario.json` grants the actual cantrip to Amber caster
`3e3e257b-ff64-4df6-9495-d7acf0c8169a` at **[3,6]**. Its living fighter ally
`c1105950-e7dd-4900-b584-b052e35b00c4` is at **[4,6]**, initially wounded by
the ordinary roster starting-damage edit. A legal Blue Magic Missile puts only
the first missile on that patient; the other two target the healthy caster and
are intercepted by its actual Shield. There is no repeated damage to the
patient after reaching zero in this original attempt.

Amber `journal/0000000000000004.json` contains:

| Actual occurrence | Public fact |
|---|---|
| 56 | Patient `normal_hp` changes to 0. |
| 62 | 4 Force applied to that patient; resulting normal HP 0. |
| 63 | Patient `alive → dying`, reason `damage`, normal HP 0, remains intact. |

Blue's independent occurrences for the same disclosed results are 51/57/58;
these are seat-local identities. The original recorder then reports exactly:

```text
CaseError: Not offered to Amber caster: spell.spare_the_dying
(spell.spare_the_dying:no_valid_targets)
```

The original discovery row was summarized by the recorder in `recording.json`;
its full Choices reply was not saved. Do not call that summary a complete wire
reply. The original packets and committed setup commands are present.

Frozen source explains the exclusion:

1. `dnd/player/session.py:304` calls `get_available_actions` without
   `include_dead`, whose default is false. Public `ChoicesRequest` has actor,
   revision, `force_attack` and correlation fields, but no such override.
2. `dnd/entity.py:6033` passes that outer flag to `_compute_target_pool`, rather
   than the actual template's `include_dead=True`.
3. `dnd/entity.py:5654` removes every candidate without positive normal HP
   before the cantrip's rule check. Its rule at
   `dnd/spells/necromancy.py:2398` explicitly requires DYING/STABLE and exactly
   0 HP, excluding undead and constructs.
4. The cantrip retains perceived targeting. It does not enumerate
   `TOUCH_CONTACT` or additional candidates, so adjacency cannot rescue the
   excluded patient through that existing path. The packet4 sensory update
   also omits the patient from its contact rows; repairing only the pool flag
   is therefore not yet proof that the later visual-recipient check passes.

Backend qualification should retain the actual 0-HP patient/life and public
perception checks together, then require a real offered selection, actual
committed Spare the Dying and its DYING→STABLE result. Changing patient HP to a
positive value or injecting a target into the client would invalidate the case.

## Hellish Rebuke: failed area trigger retained

Original area-trigger capture in the joined live inventory:

```text
.runtime/consolidation/hellish-free-aim-driver/
spell.hellish_rebuke__baseline/
```

Amber's actual native Fire Myrmidon caster is
`8a65b400-2908-4c66-9b2b-a26961e4379c` at [3,7]; the visible Blue caster
`37b6e2d0-6dc4-4b91-b87e-716b288d76b8` is at [4,7]. A legal Ice Storm
commits at Blue cursor8. Amber packet8 occurrence64 applies **23 Bludgeoning**
from that Blue actor to the Myrmidon, resulting HP100. Its own HUD in the same
packet reports **reactions=0 and resource:innate_rebuke=0**, both maximum1.
Neither complete journal contains the Hellish reaction, its saving throw or
positive Fire result. The earlier recorder reproduction at
`.runtime/scenario-expansion-20261020/cases/spell.hellish_rebuke__baseline/20261020T000806.969410Z/`
has the same consumed-resource/missing-result pattern.

The Myrmidon owns a real learned reaction source installed by
`dnd/monsters/high_level_spell_summons.py:760`, not a fabricated behavior grant.
`dnd/spells/infernal.py:132` requires positive incoming damage, a different real
attacker, actual learned source, reaction affordability, visual contact and
distance≤60 before consuming either resource. Consumption alone is not the
reaction/result witness; it narrows the failure beyond those preconditions.
The handler uses `AFTER_GROUP`. Exactly where the area/group path loses or
fails its outcome remains unproved; no engine fix is asserted here.

## Successful single-target control

One new bounded attempt, seed2, using the unchanged native Myrmidon roster and
the existing recorder/SDK worker:

```text
.runtime/consolidation/hellish-dissonant-single-target/
20261020T062826.703427Z/
```

The only trigger change is Blue target's learned spell and command:
`spell.dissonant_whispers`, rank1, actual target Amber caster. Its Psychic
damage is not an immunity of the native Fire Myrmidon and remains positive
after a successful save. Required evidence still includes
`reaction.spell.hellish_rebuke` and **positive Fire damage**; Dissonant Whispers
itself is also required. No setter, inferred damage or resource-spend substitute
can satisfy those checks.

Both original packet8s disclose:

| Result | Amber occurrence | Blue occurrence |
|---|---:|---:|
| Hellish DEX save against Blue target, failed | 66 | 58 |
| Actual Myrmidon→Blue target **14 Fire**, target HP146 | 82 | 74 |
| Completed `reaction.spell.hellish_rebuke` action | 84 | 76 |
| Blue target→Myrmidon **15 Psychic**, Myrmidon HP108 | 88 | 80 |
| Completed original Dissonant Whispers cast | 95 | 86 |

New actor identities: Myrmidon
`4b9e8e2f-9b6e-43c0-965d-081270b80649`, Blue attacker
`b59a86dd-f7cd-4769-9b95-1b135a090232`. Packet8 HUD again consumes reaction
and innate rebuke. Keep original event order and ancestry: the published Fire
reaction precedes the outer Psychic applied-damage completion; do not reorder
or manufacture native packet facts to match an expected narrative.

`recording.json` is `ok=true`, both perspectives present, applied damage types
Fire/Psychic; all four actual commands have committed own-seat receipts. The
Blue cast receipt is command2, own cursor8. Worker exit0. Its hosted owner
stopped in `finally`; host PID2873504 no longer exists. No Godot/GPU process
was launched.

The authorized durable intake is
[`tests/fixtures/schema16/hellish-single-target`](../tests/fixtures/schema16/hellish-single-target/README.md):
all 21 source files (three metadata/command files and nine packets per seat)
were copied byte for byte. The Hellish baseline in `tools/studio_cases/cases.py`
now uses this exact roster, rank1 single-target command and strict reaction/Fire
requirements. Native/live qualification is still separate. The recorded
scenario retains its original probe ID; a Studio baseline alias must remain
explicit catalog metadata rather than rewriting the original scenario or wire.
After `record.py --import-recordings` published that actual ID, the active
library row was explicitly aliased to `spell.hellish_rebuke/baseline` with
`original_case_id` retaining the probe ID. Its prior failed library entry was
preserved as `superseded-library-entry.json` beside the new original attempt;
all older failed captures remain unchanged. The baseline is recorded, with
`studio_checked=false`, and is not a replacement native/live result.
