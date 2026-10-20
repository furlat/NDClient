# Condition selector and baseline producer gaps — 20 October 2026

Read-only evidence against frozen engine
`211b71134ed15c89e62232587381f7e15a5961c3`, player schema16, and installed
Factory `production-bindings-c494177f9ef03e3d`. No selector alias, native rule,
wire translation or fabricated owner was added. Missing information remains
missing; this document does not prescribe a general new protocol.

## The 28 literal selector gaps

Source: `tools/factory_binding_coverage.py`, output
`generated/reports/factory-binding-completion.json`, field
`selections[].undisclosed_condition_selector_fields`. These are **28 Factory
selections**, not 28 missing spell implementations. Selection paths below mean
the row of `assets/vfx/index.json` whose `selection.key` equals the named key;
the actual index stores selections as an array.

| Actual owner behavior ID | Selections | Factory selector paths / literal values | Frozen producer |
|---|---:|---|---|
| `condition.spell.summon_dragon.shared_resistance` | 5 | `condition_dragon_resistance_{acid,cold,fire,lightning,poison}_persistent.condition.when.damage_type` = `Acid`, `Cold`, `Fire`, `Lightning`, `Poison` | `dnd/monsters/spell_summon_actions.py:2262`, `DragonSharedResistance.damage_type: DamageType` |
| `condition.class.paladin.aura_benefit` | 3 | `condition_paladin_aura_{protection,devotion,courage}_persistent.condition.when.aura_kind` = `protection`, `devotion`, `courage` | `dnd/classes/paladin.py:734`, `PaladinAuraBenefit.aura_kind` |
| `condition.summon.draconic_breath_cadence` | 13 | `condition_draconic_breath_cadence_<element>_event.condition.when.breath_type`; all 13 `DamageType` spellings | `dnd/monsters/spell_summon_actions.py:2165`, `DraconicBreathCadence.breath_type` |
| `condition.summon.elemental_multiattack_bonus` | 4 | `condition_elemental_multiattack_{shocked,prone,burning,chilled}_event.condition.when.prerequisite` = `Shocked`, `Prone`, `Burning`, `Chilled` | `dnd/monsters/spell_summon_actions.py:1996`, `ElementalMultiattackBonus.prerequisite` |
| `condition.summon.myrmidon_strike_dice` | 3 | `condition_myrmidon_strike_{lightning,fire,cold}_event.condition.when.{action_id,damage_type}`; exact Air/Fire/Water Myrmidon strike IDs and `Lightning`/`Fire`/`Cold` | `dnd/monsters/spell_summon_actions.py:2439`, `MyrmidonStrikeDice.{action_id,damage_type}` |

The 13 Factory breath values are `Acid`, `Bludgeoning`, `Cold`, `Fire`, `Force`,
`Lightning`, `Necrotic`, `Piercing`, `Poison`, `Psychic`, `Radiant`, `Slashing`,
`Thunder`. Their metadata presence does not prove an actual native variant,
readiness transition or emitted breath event. Those remain separate gaps.
Likewise, the Myrmidon values are bound to the exact literal action IDs
`action.air_myrmidon.electrified_flail`,
`action.fire_myrmidon.scorching_strike`, and
`action.water_myrmidon.hiemal_strike`; an arbitrary attack is not evidence.

`ConditionState` is defined in frozen `dnd/types/actor.py:49`. It contains
`energy_type: DamageType | None`, but no `damage_type`, `aura_kind`,
`breath_type`, `prerequisite` or `action_id` fields. The corresponding native
owners above do not override `BaseCondition.snapshot_state`
(`dnd/core/base_conditions.py:762`) to disclose their private selector operands.
`NativePersistent.lifecycles` currently compares Factory `when` fields directly
with disclosed `condition.state`; `NativeInputs.sync` does not supply an
undisclosed value by guessing its name.

## Exact original owner evidence

All paths in this section are under the project root. Original packet bytes
are unchanged. Occurrences and sequence numbers are local to the named seat;
they are not cross-faction identities.

**Dragon shared resistance — alias rejected.**

`spell.summon_dragon/baseline`, Amber packet8:

```text
.runtime/studio-library/cases/spell.summon_dragon__baseline/
20261019T143657.346589Z/amber/journal/0000000000000008.json
```

`lineages[0].events[1]`, occurrence54, admits condition owner
`28ec0cb2-55b4-48dd-95d0-dff7655efb6c` to actor
`5affe2c7-90cc-42f4-8be0-b6ab07458ad7`. The actual member has behavior
`condition.spell.summon_dragon.shared_resistance` and
`state.energy_type = null`; it has no public `damage_type`.
The native `_apply` reads its private `damage_type` to construct the resistance
modifier, but that value is absent from the snapshot. Therefore an authored
`energy_type → damage_type` mapping would still receive null. A spell variant,
creature color or unrelated damage affinity cannot replace this exact owner's
missing operand. The five literal Factory variants remain unmatched.

The same packet's `lineages[0].bodies[0].body.conditions[1]` admits
`condition.summon.draconic_breath_cadence`, owner
`28b39235-7c27-4f7c-9e71-d37eadff3f92`, with `state.energy_type = null` and no
`breath_type`. Mere condition admission does not prove breath readiness.

**Elemental and Myrmidon controls.**

- `spell.conjure_elemental/baseline`, Amber packet8,
  `.runtime/studio-library/cases/spell.conjure_elemental__baseline/20261019T142259.706975Z/amber/journal/0000000000000008.json`,
  `lineages[0].bodies[0].body.conditions[1]`: actual
  `condition.summon.elemental_multiattack_bonus` owner
  `fcb43d6b-569d-42fd-af04-146e78acabd6`, `energy_type = null`, no public
  `prerequisite`.
- Final actual Hellish trigger study, Amber initialization packet0,
  `.runtime/scenario-expansion-20261020/cases/spell.hellish_rebuke__baseline/20261020T000806.969410Z/amber/journal/0000000000000000.json`,
  `initialization.bodies[0].body.conditions[1]`: actual
  `condition.summon.myrmidon_strike_dice` owner
  `f4083135-7723-421c-97ed-6bca3e7f3878`, `energy_type = null`, no public
  `action_id` or `damage_type`. Its `applied_source_event_cursor = 8` is not a
  substitute for those values or a synthetic event UUID.

**Paladin aura — display-name parsing rejected.**

`PaladinAuraBenefit.model_post_init` creates the name
`Aura of <Kind>:<zone UUID>` (`dnd/classes/paladin.py:746`), while the typed
snapshot omits `aura_kind`. No original aura-benefit owner was qualified in
this bounded study; no packet/UUID is invented for it. Parsing a mutable
display name would turn a presentation label into a rule discriminator.
The exact typed owner operand is needed before these three selectors can be
claimed as supported.

## Positive controls and the Fire Shield counterexample

**Protection from Energy already works without renaming.**
`ProtectionFromEnergyEffect.snapshot_state` explicitly copies its resisted
`DamageType` to public `energy_type`
(`dnd/spells/abjuration.py:647`), and its Factory condition selections already
use `condition.when.energy_type` with `Acid`, `Cold`, `Fire`, `Lightning`,
`Thunder`.

Original Amber packet8, occurrence51:
`.runtime/studio-library/cases/spell.protection_from_energy__baseline/20261019T143240.631130Z/amber/journal/0000000000000008.json`.
Owner `4c7a5ec5-af43-4cf2-8449-0f51b680be55`, actor
`15034cca-5d5f-41e1-acee-bc8c3e266315`, actual `state.energy_type = "Fire"`.
There is no missing alias on this path.

**Fire Shield shows why a global alias is unsound.**
`FireShieldEffect.snapshot_state` publishes `Fire` for warm and `Cold` for
chill (`dnd/spells/evocation.py:4854`). Its `_apply` then resists the **opposite**
element while retaliating with the published one. Factory's warm/chill
selectors correctly use `when.energy_type`, not inferred resistance.

Original Amber packet8, occurrence48:
`.runtime/studio-library/cases/spell.fire_shield__baseline/20261019T142722.276287Z/amber/journal/0000000000000008.json`.
Owner `25fe47aa-f901-4aa0-9888-103170c1b324`, actor
`b9d431ca-a0c8-4189-802b-6b9538dede50`, actual `energy_type = "Fire"` means warm
retaliation, while native resistance is Cold. A global energy-to-resistance
renaming would be factually wrong.

No selector code is warranted by these findings. If an exact non-null public
operand is later available, a per-resource typed mapping may express that
proven relationship. It must not silently fill values that remain absent, nor
claim unsupported event provenance or actor-history behavior.

## Six failed spell baselines: essential evidence

All six remain strict failures. Bounded legal recipe corrections live in
`tools/studio_cases/cases.py:spell_baselines`; original command receipts are
preserved and an indeterminate issued command is never resubmitted. Detailed
machine evidence is `.runtime/scenario-expansion-20261020/baseline_failure_evidence.json`.
The essential causes and evidence are recorded here so they survive without
that ignored report.

| Baseline | Exact current boundary and retained capture |
|---|---|
| Branding Smite | Explicit equipped Longsword and exact Knight recipient still produce `ValueError: lineage requires terminal root and child facts` in native `dnd/player/capture.py:700` (`_lineage_graph`). Capture root is the native `AttackBackedSpell` path (`dnd/spells/hit_effects.py:189`). The precise internal nonterminal child has not been isolated; no renderer cause is claimed. Latest folder: `.runtime/scenario-expansion-20261020/cases/spell.branding_smite__baseline/20261020T000616.680608Z`, incident `5cb10da9-3c2e-4942-b4ec-5017e407e174`. |
| Ensnaring Strike | Same equipped-weapon/recipient probe and same native terminal-lineage failure. Latest folder: `.runtime/scenario-expansion-20261020/cases/spell.ensnaring_strike__baseline/20261020T000625.658459Z`, incident `74a6725a-744c-4b0f-a256-20b908e703cf`. |
| Searing Smite | Same equipped-weapon/recipient probe and same native terminal-lineage failure. Latest folder: `.runtime/scenario-expansion-20261020/cases/spell.searing_smite__baseline/20261020T000640.138407Z`, incident `93ac25bd-7750-4eef-93fb-12c2e7fe6f21`. |
| Fixture Test Bless | Original native startup fails in `_apply_spell_grant` (`dnd/scenarios/encounter_assembler.py:232`): `Spell grant 'content.neurodragon:spell:spell.fixture.test_bless@1' has no directly registered spell action`. Its developer declaration exists (`dnd/content_system/action_definitions.py:263`), but the roster's `_SPELL_ROW_BY_REF` has no grantable action. Original folder: `.runtime/studio-library/cases/spell.fixture.test_bless__baseline/20261019T144511.104263Z`. No substitution with ordinary Bless or repeated startup was attempted. |
| Spare the Dying | Single actual Magic Missile hit for 4 HP brings the wounded living Fighter exactly to 0 HP; further missiles target the healthy caster. Amber packet 4 occurrences 62/63 prove `damage.applied` and `alive→dying`; patient `c1105950-e7dd-4900-b584-b052e35b00c4`, adjacent caster `3e3e257b-ff64-4df6-9495-d7acf0c8169a`. Discovery still returns `no_valid_targets`. Native `_collect_entity_actions` (`dnd/entity.py:6033`) passes the global `include_dead` flag into `_compute_target_pool`, which excludes zero-HP candidates before this template's `include_dead=True` can admit them. Spare is PERCEIVED, so no touch-contact candidate path restores it. Spell rule: `dnd/spells/necromancy.py:2398`. Latest folder: `.runtime/scenario-expansion-20261020/cases/spell.spare_the_dying__baseline/20261020T000649.366845Z`. |
| Hellish Rebuke | Final actual Ice Storm deals 23 Bludgeoning to Fire Myrmidon `f552cf41-281b-4a0f-801c-7d02f9ab94f6`, Amber packet 8 occurrence 64. The same packet spends `reactions` and `resource:innate_rebuke` to 0. Neither independent journal discloses Fire damage or `reaction.spell.hellish_rebuke` attribution. The earlier real Magic Missile probe similarly spends both resources without the public result; the intervening ordinary weapon probe missed and does not qualify a trigger. Native source registration: `dnd/monsters/high_level_spell_summons.py:760`; processor/handler: `dnd/spells/infernal.py:132` / `:255`. This is an unresolved result/capture boundary, not proof of an absent learned handler. Latest folder: `.runtime/scenario-expansion-20261020/cases/spell.hellish_rebuke__baseline/20261020T000806.969410Z`. |

Each folder contains `scenario.json`, `commands.json`, `recording.json`, the
original independent seat journals and `server.log` where a host ran. The
source recipes reproduce through the ordinary frozen SDK recorder; no engine
or Factory files were changed. Current library qualification remains separate
from presentation implementation and visual acceptance.

The two additional real passive outcomes with absent typed handler attribution
(Blessed Healer and Destroy Undead) and their checked-in original fixtures are
documented in [the scenario worklist](SCENARIO_COVERAGE_WORKLIST_2026-10-20.md).

## Bounded spell ownership audit and positive reference correction

An offline pass inspected all 191 current spell TRES `owner_ids`,
`applies_conditions` and cast-time `owner_cues`, existing original baseline
recording summaries and the current Factory lifecycle metadata. After the Aura
correction, no additional unrelated spell-prefixed `owner_ids` alias or sealed
`mode=windup` cue handed to a condition owner was found. Other cast-time held
cues use actual application/apply source phases; those were not mistaken for
casting windups.

One exact positive omission was corrected: `spell.summon_dragon` now includes
`condition.spell.summon_dragon.shared_resistance` in `applies_conditions`.
Original baseline `20261019T143657.346589Z` packet 8 independently applies it to
caster `5affe2c7-90cc-42f4-8be0-b6ab07458ad7` in Amber occurrence 54 and Blue
occurrence 53. Both carry actual condition UUID
`28ec0cb2-55b4-48dd-95d0-dff7655efb6c`. The original public state still has
`energy_type=null` and no `damage_type`; no elemental variant or owner handover
was added. The five delivered resistance selections remain blocked by that
exact missing selector.

Two verbatim complete original operation packets and original recording
metadata are retained under
`tests/fixtures/schema16/condition-ownership/summon-dragon/` (about 27 KiB).
`tests/condition_owner_reference_checks.gd` decodes each through the current
protocol, proves exact native cast ancestry and recipient membership,
checks the typed reference and immutable original packet, and ensures the
missing selector selects none of the five Factory variants. No hand-translated
wire rows or synthetic game outcome is used.

The audit also found cross-wall/frigid-air reference unions on Forcecage,
Wall of Force, Wall of Ice and Wall of Stone, and broad shared condition lists
on Conjure Elemental/Planar Ally/Summon Dragon. These are **not removed based
on their names or a single cast-only absence**. Their real recordings disclose
positive constructions or summoned bodies, but do not qualify every later
break/contact/variant interaction. Original Acid Arrow/Orb surface references,
payload-lifetime reuse and Necrotic Bless/Bane reuse also demonstrate why a
name-prefix rule would delete legitimate shared mechanics. Exact future
exclusion evidence is needed before further reference removal; no broad
rewrite or registry is introduced by this audit.

The focused `condition_owner_reference_checks` gate passed **26 checks,
0 failures, 0 script/engine errors in 1.5 seconds**:
`.runtime/tests/20261020T013442.555282Z`. No source-index build, GPU run,
backend execution or Factory source modification was performed.
