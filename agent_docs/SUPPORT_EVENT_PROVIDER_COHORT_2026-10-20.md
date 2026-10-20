# Finite support spell events — 2026-10-20

This Phase 5 cohort binds three finite cast effects to the existing
`observed_event` mechanism. It does not declare the spells' other channels,
persistent source leases, pixels, or user visual approval complete.

| Engine ID | Exact delivered clip | Authored recipient | Actual evidence |
| --- | --- | --- | --- |
| `spell.aura_of_life` | `high-level-22/aura-of-life/windup` | caster | Amber/Blue packet 8, cast occurrence 69, lineage 41; real null target, caster `cd67c16b-1235-4790-b72d-aa9196ef03bc` |
| `spell.foresight` | `high-level-22/foresight/windup` | caster | Amber/Blue packet 8, cast occurrence 52, lineage 41; caster `faeb655b-1e7f-4c0c-bf80-248de096fba5` |
| `spell.power_word_heal` | `high-level-22/power-word-heal/spoken_word` | actual target | Amber/Blue packet 8, cast occurrence 48, lineage 41; source `61014fe9-469f-4ed6-8100-21b0d8117c1b`, recipient `f4fac018-af2a-468b-9b41-689d6744576a` |

The local numbers above are inspected independently in each original journal;
these examples happen to match. The producer never equates two seats' cursor,
occurrence, lineage, or private source identity.

## Input and clock ownership

The three sealed native source components are `support`, mode `windup`. Their
finite admission consumes the event's exact opaque occurrence key, source and
recipient UUIDs, and `canceled=false`. No condition owner, expiry, healing or
rule evaluation is needed by this branch. Their `lease` and review `event`
constructor packets are cleared before construction; the same actual event is
then supplied through `event_input`. Original material and art values are
unchanged.

The existing `ApplicationResults.observed` projection accepts the authored
`recipient_role` for cast events. Its omitted-field default remains `caster`
for existing action bindings. `target` requires the actual fact's target; a
null target stays unavailable. The Power Word source's direct
`voice_recipient_actor` setting receives that actual recipient UUID so its
spoken paths and measured endpoint packets agree. This is an optical
constructor operand, not an added wire fact.

`Components.native_spell` dispatches these descriptors through the existing
projection. The observed cast is the same occurrence already scheduled, so
its authored finite start and duration are unchanged. No playback clock hold,
new scheduler, manager, registry, or renderer loop was added.

Two genuine ownership bugs surfaced:

* Aura/Foresight preparation index 0 was in `owner_cues`, preventing the real
  cast from owning its finite preparation. Only index 0 is removed from those
  handovers. Held sources remain condition-owned or explicit provider gaps.
* Endpoint requirements counted all staging cues, including those handed to
  conditions. Aura's actual cast has no target, so a held recipient cue dropped
  the caster-only preparation. `NativeSpells.event_cues` now contains the
  existing phase ownership filter; both phase compilation and
  `SpellDelivery.endpoints` consume it. Genuine recipient cues still require
  their real disclosed recipient.

Aura metadata also incorrectly borrowed Pass Without Trace owners. Its
`owner_ids` and `applies_conditions` now contain exactly the actually admitted
`condition.spell.aura_of_life.owner` and `.benefit`; obsolete `.membership` and
Pass Without Trace aliases are removed. Original packet 8 independently admits
the caster owner and both actual benefits. No alias is retained for old tests.

## Original recordings and qualification

Original unchanged baselines, copied with their scenario/recording/command
metadata and both independent journal prefixes:

* `tests/fixtures/schema16/scenarios/aura-of-life` — original
  `20261019T141931.818160Z`.
* `tests/fixtures/schema16/scenarios/foresight` — original
  `20261019T142836.300856Z`.
* `tests/fixtures/schema16/scenarios/power-word-heal` — original
  `20261019T143155.960038Z`.

All use frozen engine `211b71134`, schema 16. Current focused gate:

```sh
tools/run_tests.sh --only support_spell_event_checks
```

The gate builds only these typed records **in memory**. It does not rebuild the
shared source index. It verifies original journal reduction, exact constructor
and actual source admission, immutable source materials/recordings, one finite
component per cast, explicit caster versus target/null semantics, real Aura
owner/member handover, negative unrelated-owner attribution, no held replay,
old action-recipient defaults, unchanged authored duration, and exact final
reducer prefix without clock holds.

The final **350 checks passed** in 2.4 seconds with zero script or engine
errors (`.runtime/tests/20261020T011438.901095Z`). The following shared
regressions also passed with zero script/engine errors at
`.runtime/tests/20261020T011236.703604Z`:

| Gate | Checks |
| --- | ---: |
| `native_action_cue_checks` | 125 |
| `native_application_constructor_checks` | 104 |
| `observed_damage_inputs_checks` | 439 |
| `vampiric_touch_input_checks` | 121 |
| `propagation_input_checks` | 547 |

The offline Factory join changes exactly the three cue-0 references from
`owner_handover` (Aura/Foresight) or `bound_provider_gap` (Power Word) to
`bound_provider_present_unqualified`; their previously missing `event_input`
and `lease_input` setter channels are now mapped. This is input coverage,
not visual acceptance or full-family coverage.

## Deliberate remaining gaps

The actual Power Word Heal baseline has `actual_healing=0`. No healing
restoration, cross, or recovery result is produced from that cast. A genuinely
wounded patient is needed to qualify positive healing later. Holds,
retirements and secondary condition/removal studies retain their actual
producer gaps or already supplied package lifecycles; their fixture success
packets are not repurposed as real results.

Native GPU construction, framebuffer output, visual timing review, full
family coverage and live performance for these newly bound finite effects
remain parent-serialized qualification work. No GPU or source-index build was
run in this cohort. Parent may rebuild the shared abilities index after all
readers release:

```text
Godot --headless --path <project> --script res://tools/build_presentation.gd -- --only=abilities
```

The bounded remaining-selector audit found no safe alias cohort: the Factory
needs `damage_type`, `aura_kind`, `breath_type`, `prerequisite`, or `action_id`
for 28 condition variants, while current disclosed `ConditionState` does not
supply those selectors. `energy_type=null` must not be translated from names,
creature colors, affinities or review defaults. Existing ordinary condition
package lifecycles are already handled; duplicate typed effects are not added.

## Native output gate (authored; execution remains serialized by parent)

`tests/native_support_spell_event_checks.gd` inherits the existing native
Vampiric Touch gate's frame/readiness/RGBA-difference helpers. It uses the
ordinary `Recording` → `Play` renderer for all three original cases and both
independent seats, seeking before, inside and after each finite source twice.
It checks the actual casting body clip, measured hand/head/recipient endpoint
packet, exact source program event admission, real caster surface points,
private parent/review packet clearing, no fabricated lease or healing,
submitted source geometry, nonzero framebuffer contribution, immutable source
presets/facts, and epoch/teardown release. Present and source-hidden PNG pairs
are saved in `.runtime/support-event-captures/` for visual inspection.

```sh
tools/run_tests.sh --only native_support_spell_event_checks
```

No GPU result is claimed by this authoring handoff. Parent owns the shared
source-index build and native run. A final cast-only projection cleanup clears
the unused `parent_owner_uuid` review value; the original Factory preset stays
unchanged. Six focused assertions cover this private operand (the next
headless run expects 356 checks). Non-cast observed result constructors retain
their existing owner semantics.
