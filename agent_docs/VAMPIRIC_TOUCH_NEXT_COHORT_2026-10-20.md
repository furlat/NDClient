# Vampiric Touch: exact next provider cohort

Study only; no runtime, authoring, Factory, build or renderer change is made by
this note. Installed package construction revision is `c494177f9ef03e3d`.
The new genuine evidence is documented in
`VAMPIRIC_POSITIVE_RECORDING_2026-10-20.md` and preserved in
`tests/fixtures/schema16/vampiric-positive/{amber,blue}/`.

## Current capability and bounded next step

| Branch | Existing implementation | What the new evidence permits | Qualification still required |
|---|---|---|---|
| Initial impact | Actual first-cast Hit/Crit + own positive Necrotic descendant, `ApplicationResults.spell_strike` | Exercise unchanged branch alongside positive self-heal | New recording through ordinary Play; exact contact/pixels |
| Healing return | Typed cue2 explicitly unbound | Finite actual HealFact projection, for both initial and repeat event | Real setter, direction/recipient surface, result clock, native pixels |
| Held hand | Installed generic condition lifecycle exists; typed spell still lists independent condition/retire probes as missing | Hand probes3/4 to the exact real UUID lifecycle | One hand owner through move/repeat/removal, same age, .35s fade/pixels |
| Repeat impact | Source accepts the real action ID, but current client projection/build authoring only supports initial spell ID; action entry has no native delivery | Actual completed repeat + positive Necrotic result + uniquely witnessed active held owner | Strict before-member/ancestry join, no new cast or fabricated owner, native contact/pixels |
| Pre-application windup | Source requires held owner admission | No new evidence legitimizes a future owner before application | Keep explicit gap; do not show a future condition early |

The smallest useful next implementation is **finite positive healing plus
existing-owner handover**, retaining the first-impact gate. Repeat contact can
follow through the same result seam with a real before-member join; it is not
already implemented by pointing the action at a spell recipe.

## Installed source contracts

All five `bg3-36/vampiric-touch/vampiric_touch_native/*` clips construct component
`owned_contact` using
`res://assets/vfx/sources/8d17316149890f77c98b/vampiric_touch.gd`.
It extends `43d964a5ab22cb82ad2d/retained_contact.gd`, which extends
`397ef2a8907055317449/smite_common.gd`.

Every finite clip declares seven channels:
`owner_input`, `healing_input`, `strike_input`, `condition_input`, `tick_input`,
`recipient_geometry`, `targets`. A setter's presence does not mean every phase
consumes its packet. The actual branch must prove any inapplicability policy.

### Positive healing, .46 seconds

Source phase:
`res://assets/vfx/sources/368c2f83c6b0ea70d1c8/f0326ecceb3d0c34.tres`.

`healing_admitted()` consumes exactly:

| Supplied operand | Required fact |
|---|---|
| `healing.observed=true` | Actual committed uncanceled HealFact descendant |
| `healing.actual_healing` | Positive native amount,5 initially /12 on repeat |
| `healing.was_blocked=false` | Native `was_blocked=false` |
| `healing.healing_fact_uuid` | Opaque actual seat-local HealFact occurrence112 /195 |
| `healing.source_actor_uuid` | Actual HealFact source = actual spell/action caster |
| `healing.recipient_uuid` | Actual HealFact target = the caster, **not** the drained enemy |
| `healing.parent_event_uuid` | Exact native HealFact `parent_event`,91 /174 |
| Constructor `activation_event_uuid` | That same actual parent_event91 /174, **not** cast completion114 /196 |
| Constructor `source_actor_uuid` | Same real caster |

The geometry roles differ from the healing result roles. `settings.recipient_uuid`
must remain the **drained enemy** (`28afd8d7-0e9a-45e0-ac33-51ebeb02f251`),
because `recipient_surface()` consumes endpoint1's actual actor and
`sample()` draws from measured enemy contact to caster hand. Endpoint0 is the
actual caster hand; endpoint1 is the actual enemy body center + measured surface.
Blindly reusing `observed(outcome=heal)`'s target as the optical recipient would
put both ends on the caster and lose the return path.

The existing immutable graph already indexes positive HealFacts under their
actual spell/action ancestor. Use that index, actual source/target equality and
the original node.parent_event; no log-text match, HP delta or half-damage rule.
Keep the event's actual healing target in evidence even if the component's
optical target remains the drained enemy.

In `sample()`, phase=`healing` overrides payload admission with
`healing_admitted()`. It does not require owner/strike/condition/tick success.
Their review packets and unused item/equipment/condition/owner identities must
be cleared, not retained from the successful Factory fixture. Exact offline
source/phase proof can classify those four channels as not applicable for this
healing branch. Required healing/targets/surface inputs remain real supplied
inputs. Existing first-impact inapplicability policy cannot be copied by name;
it applies only to the first-impact source branch.

Schedule each healing source at its **own actual HealFact response clock**, with
its preserved .46s source duration. Do not retain the imported fixed `.28s`
after-release offset in addition to an already observed heal time.

### Initial and repeat contact, .44 seconds

Source phase:
`res://assets/vfx/sources/cfaf73e249ee8206940a/78b90edfda6f239b.tres`.

`payload_admitted()` accepts either actual behavior:
`spell.vampiric_touch` or `action.spell.vampiric_touch.strike`, with exact source,
enemy recipient and own attack occurrence; `attack_kind=spell`, Hit/Crit,
`payload_applied=true`, nonempty actual damage occurrence and
`damage_type=necrotic`. The current initial-only projection already supplies
those operands without an equipped weapon or invented item UUID.

For the repeat action **it additionally requires `owner_admitted()`**:
actual held condition UUID/id, exact caster as source and recipient, observed
present contribution-active owner and no suppression. The new original repeat
is occurrence196 /sequence19, Crit, own applied Necrotic occurrence190 /amount24.
It is not another `spell.vampiric_touch` cast and must keep that action identity.

The exact public before-member UUID is
`aebf2ad6-b8cc-4717-82ae-d185ed446e45`; only one matching caster membership exists
at this cut. The frozen producer (`dnd/spells/necromancy.py`,
`VampiricTouchStrike._grant_owner_active` / `_apply`) explicitly rejects a
repeat unless its actual grant owner exists, is applied and
`contributions_active()`. Therefore this **completed accepted repeat** supplies
an event-local effectiveness witness in addition to the exact unique public
before-membership. It does not justify inventing effective=true at unrelated
idle cuts. If the before-member is absent or multiple owners cannot be resolved
from disclosed provenance, report unavailable rather than choose one.

`ConditionState` in frozen schema16 does **not** expose general
`contribution_active` or `suppression_provider_uuids` fields. Do not manufacture
those booleans from an absent field or a name match. The existing generic
UUID lifecycle uses disclosed membership/owner age, so it does not need this
extra source-specific owner_input gate.

The typed action currently has `body.enabled=false`, empty `effect_sources` and
no effects. Although `PresentationAction.delivers_spell` exists, its builder
only exports `catalog/action_deliveries.json`; current native lookup
`NativePresentationSources.find()` directly indexes `index.spells` by actual
behavior. No runtime reader consumes `action_deliveries.json`. Merely setting
that resource field cannot activate this repeat. Use the existing typed action
effects/result seam or finish that existing delivery seam deliberately while
preserving native action identity; do not add a second event framework.

### Held hand and removal

Delivered selection `condition_vampiric_touch_hand_persistent` names exact
owner `condition.spell.vampiric_touch` and already supplies prepared
application/sustain/removal clips. They require only `owner_state` + `root_path`;
registration is `caster_hand` / `cast_hand`, with application .35s, indefinite
2s sustain source loop and removal .35s. `conditions/runtime.gd` keeps the
same owner age/held loop phase during removal.

The actual UUID applies at sequence9 occurrence90, is updated at sequence18
occurrence169 with the **same UUID**, and is removed at sequence20 occurrence205.
Blue legitimately withholds duration; UUID lifetime follows actual membership,
not Amber's remaining-round count or the imported2.31s demonstration window.
Use typed `owner_kind=condition`, the exact owner_id and existing handover of
condition/retire cue indices3/4. Do not construct both the cast probe and native
lifecycle. Keep windup0 and any unimplemented branch inspectable as gaps.

## Focused implementation and gates

1. Extend the existing `ApplicationResults` observed projection for the actual
   healing-return input shape, then the existing Components/NativeInputs
   constructor/setter handoff. Preserve source/result ancestry, actual healed
   recipient and separate measured donor role. No parallel reducer or clocks.
2. Update typed spell cue2 at the real heal clock and hand cues3/4 to the existing
   UUID lifecycle. Keep status partial and the pre-application windup gap.
3. If included, extend exact initial/repeat strike projection with immutable
   before-member capture and the accepted-repeat predicate above. Add the
   missing native action dispatch explicitly; never relabel repeat as a cast.
4. Headless: both original streams, first Hit/repeat Crit and positive5/12
   HealFacts, full canonical drain, source preset immutability; private zero,
   blocked, canceled/request, foreign source/recipient, detached ancestry,
   absent/ambiguous/removed owner controls. Keep the old actual zero-heal
   baseline as a negative source and don't rewrite either original corpus.
5. Native: ordinary Play/Recording media closure, process-frame preparation
   before child work plus real post-draw readiness, actual published quarters;
   exact hand/donor surface, independent source-hidden framebuffer controls,
   no heal draw on zero, one retained UUID hand owner through movement/repeat,
   same owner/age for .35s removal, seeking/looping/cleanup and before/end absence.

These are a bounded provider/authoring cohort and qualification gates. Current
evidence makes the operands available; it does not claim the new branches
render, meet performance targets or have human visual acceptance.
