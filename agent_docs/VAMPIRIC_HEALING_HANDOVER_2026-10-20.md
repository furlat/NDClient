# Vampiric Touch positive healing and existing hand owner

20 October 2026. Bounded continuation of
[VAMPIRIC_TOUCH_NEXT_COHORT_2026-10-20.md](VAMPIRIC_TOUCH_NEXT_COHORT_2026-10-20.md).
No Factory artwork, engine, wire fact, reducer or approved lighting changed.
The unchanged positive recording is
`tests/fixtures/schema16/vampiric-positive/{amber,blue}`; the unchanged old
zero-heal original remains the negative input.

## Implemented boundary

`ApplicationResults.observed` now supports the typed `healing_return`
projection on the existing observed-result index. A completed source consumes
only its own actual uncanceled positive/unblocked self HealFact. It supplies
that exact amount, result occurrence, source, patient and native parent.
The component's optical recipient remains the enemy named by the actual
spell/action; the healing packet's patient remains the caster. There is no
half-damage calculation, HP-delta inference, borrowed condition membership,
contribution-active default or invented result identity.

| Real source | Actual heal | Actual healing | Actual activation parent | Optical donor | Actual patient |
| --- | --- | ---: | --- | --- | --- |
| Initial spell occurrence 114 | occurrence 112 | 5 | parent 91 | Enemy 28afd8d7-0e9a-45e0-ac33-51ebeb02f251 | Caster 34430787-4e2a-465b-aa1a-076ea3a07199 |
| Actual repeat action occurrence 196 | occurrence 195 | 12 | parent 174 | Same enemy | Same caster |

Those occurrence numbers happen to match in these two original streams; the
implementation retains each view's own values and never joins views by them.
Each finite source begins at its own actual healing commit, with no imported
0.28-second release offset, and retains the sealed 0.46-second source duration.
Successful Factory review-owner/strike/condition/tick/item operands are cleared
from private construction inputs; the sealed material/phase remains unchanged.

The spell's cue 2 uses this projection. The repeat's actual typed action uses
its existing `effects` list, preserving `action.spell.vampiric_touch.strike`
identity. Its observed branch now forwards the projection's existing `inputs`
packet rather than unconditionally replacing it with lease/event inputs.
The default observed projection retains exactly those prior lease/event fields.
No new dispatcher, provider registry, shader or source copy was introduced.

The source's healing branch explicitly overrides admission with
`healing_admitted()`. Offline build/audit proof is restricted to that exact
sealed source, component path and healing phase. Only owner_input,
strike_input, condition_input and tick_input are marked not applicable; actual
healing_input, recipient_geometry and targets remain required supplied inputs.
This does not classify those four channels as generally optional.

The spell declares `owner_kind=condition`, the exact
`condition.spell.vampiric_touch` owner and `owner_cues=[3,4]`.
Its old held/retire demonstrations hand over to the already delivered
`condition_vampiric_touch_hand_persistent` UUID lifecycle. It is not an exclusion
of an unmet visual requirement. The original UUID
`aebf2ad6-b8cc-4717-82ae-d185ed446e45` applies at sequence 9, remains the same
through movement/repeat and duration update, and is removed at sequence 20.
The package's hand application/sustain/removal retain their existing source
and owner ages, including the 0.35-second removal fade.

## Explicit remaining gaps

- Pre-application windup still requires an unavailable future held-owner input.
  The spell's cue 0 remains marked missing; no future condition is shown early.
- Repeat **impact** still requires an exact source-specific active-owner packet.
  The action contains an explicit missing impact cue. A present membership is
  not treated as a general contribution-active/suppression observation.
- Native qualification, performance and the user's visual acceptance are
  independent facts. The authoring stays `partial`.

## Changed source and gates

Production/source paths are `presentation/application_results.gd`,
`presentation/components.gd`, `tools/presentation_build/abilities.gd`,
`tools/factory_binding_coverage.py`, and the two typed Vampiric spell/action
resources. No change was needed in the generic NativeInputs setter path.

The new `vampiric_healing_input_checks` passed **366 checks/0 failures**,
zero engine/script errors or leftover processes:
`.runtime/tests/20261020T051140.451330Z/`.
It checks both original positive and zero streams, actual first/repeat result
identities/amounts/parents, source admission, blocked/canceled/request/zero,
foreign source/patient, undisclosed donor, missing parent/detached ancestry,
immutable presets, canonical replay drain and one actual hand UUID lifecycle.
The existing first-impact gate passed **119/0** after updating only its former
"healing and held are missing" expectation:
`.runtime/tests/20261020T051401.553468Z/`.

## Native qualification and same-clock input correction

The first actual native run reported **235 checks/8 failures**: the finite
healing source admitted its real packets but drew zero pixels in both tested
quarters for both seats. The held hand lifecycle already passed. The source
had hidden its geometry while accepting changed recipient geometry; the sealed
sampler's unchanged-age shortcut then skipped the component's geometry sample.
A bounded diagnostic using the same actual input/time showed that the component
could render correctly when sampled. The diagnostic was removed from the final
gate; it is not part of the ordinary rendering proof.

`presentation/native_constructed_occurrence.gd` now tracks input revisions
inside the existing private occurrence. An actual forwarded setter invalidates
its sampled input revision. At the same initialized source time, a changed
revision reruns only the declared component sample bindings with their original
rate/offset, restores and updates the source-owned opacity envelope, and uses
the existing material/occurrence clock. It does not replay native particle,
player, carrier or script deltas, reset initialization, change age, or restart
an emitter. Unchanged same-time samples and ordinary advancing samples retain
the existing sampler path. No Factory file, artistic parameter, runtime
validation or presentation clock hold was added.

The focused `native_constructed_input_checks` passed **15/0**, zero errors or
leftover processes, in `.runtime/tests/20261020T053509.566234Z/`. Its explicit
setter/material/emitter/player probes cover exact rate/offset sampling,
source-owned opacity versus external attenuation, unchanged sampling,
multi-argument forwarding, absent receivers and preserved pending native delta.
It is a pure boundary test, not a framebuffer or performance claim.

The final ordinary `native_vampiric_healing_render_checks` passed **235/0**, zero
script/engine errors or leftovers, in **13.4 seconds**:
`.runtime/tests/20261020T053520.871532Z/`.
Both unchanged original perspectives passed exact actual positive setters,
enemy surface/caster hand, actual parents, before/after and zero-heal controls,
strictly published camera quarters **1 and 3**, seek/loop/cleanup, immutable
presets/canonical data, and continuous same-private-UUID hand ownership through
movement, repeat and the original 0.35-second removal.

| Actual finite source | Parent | Quarter 1 changed pixels | Quarter 3 changed pixels |
| --- | --- | ---: | ---: |
| Heal 112, actual healing 5 | 91 | 63 | 639 |
| Heal 195, actual healing 12 | 174 | 268 | 386 |

Those isolated source-present/source-hidden framebuffer results are equal in
both originals. The same real hand owner also contributes pixels during held,
repeat and removal phases, then disappears after its actual removal fade.
Captures and the detailed receipt are under
`.runtime/vampiric-healing-captures` and
`.runtime/native-vampiric-healing-render-checks.json`.

The bounded production review found no material blocker. This qualifies these
actual first/repeat healing returns and existing hand lifecycle, not every
Vampiric branch, all four camera views, full live performance or user artistic
acceptance. Pre-application windup and repeat impact remain explicitly missing.
An analogous same-age setter invalidation risk exists in nonconstructed
occurrences but is not proven by this cohort; that adapter was not expanded.
Root owns source publication, manifest registration and repository checkpoint.
