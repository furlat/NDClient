# Vampiric Touch: first-cast impact cohort

This change admits only the original first-cast Hit/Crit impact. Held visuals,
repeat strikes, healing and retirement remain explicit missing phases; this is
not visual acceptance of the whole spell.

## Original evidence

The checked-in `tests/fixtures/schema16/scenarios/vampiric-touch/` contains the
unchanged Amber and Blue journals from
`.runtime/studio-library/cases/spell.vampiric_touch__baseline/20261019T143813.329804Z`,
plus its scenario, commands, recording metadata and actual command receipts.
Each seat has nine original packets. The catalog key is `vampiric-touch`.

Amber packet 8 has the native SpellFact occurrence 75, `spell.vampiric_touch`,
`Hit`, from `575909c1-8d91-40b8-a558-66003560a769` to
`43680d6b-54e2-4e61-8fbd-dc7a4c6ed7d5`. Its native descendant applied DamageFact
68 reports 15 Necrotic damage to that same recipient from that same source.
The resolution record names lineage 41 without a multi-application ID. No
application ID, private damage-roll UUID or held owner is manufactured.
Both seat-local identities are retained independently.

The actual HealFact reports zero healing because the source is already at full
health. The held condition UUID is disclosed, but activity/suppression inputs
needed by the retained source are not; those facts do not qualify either phase.

## Shared projection and source contract

`ApplicationResults.spell_strike` consumes the existing native-descendant result
index. It requires an uncancelled first-cast spell Hit/Crit, exact source and
target, and exactly one positive applied Necrotic result in that ancestry. A
repeat action, generic damage, miss, cancelled cast/result, zero damage, foreign
source/target or independent lineage cannot qualify this constructor.

The typed impact cue uses recipient scope, contact timing, actual target body
slots and the existing two caster-hand/recipient-body endpoints. Its descriptor
is `spell_strike`, `spell.vampiric_touch`, `Necrotic`, component path
`["owned_contact"]`, empty input field. Recipient scope preserves the actual
single-target inherited delivery; application scope would falsely require an
absent multi-application record.

The installed c494 source is
`bg3-36/vampiric-touch/vampiric_touch_native/impact`, source script
`res://assets/vfx/sources/8d17316149890f77c98b/vampiric_touch.gd` through
`res://assets/vfx/sources/cfaf73e249ee8206940a/78b90edfda6f239b.tres`.
Its impact branch calls `payload_admitted`; the first-cast path does not consume
held-owner, healing, condition or tick inputs. The existing retained-contact
source explicitly distinguishes its repeat path, which does require an owner.

Only this exact source/phase/behavior/constructor combination marks
`owner_input`, `healing_input`, `condition_input` and `tick_input` as
`not_applicable`, with reason
`first_cast_impact_does_not_consume_owner_or_repeat_inputs`. The offline builder
proves that exact contract. Native diagnostics retain N/A separately from
supplied and unavailable inputs. Review-only owner/healing/condition/tick
packets and their unused identities are cleared from the private constructed
input; sealed phase, material and art settings are unchanged.

## Gate and remaining work

`tests/vampiric_touch_input_checks.gd` checks both original journals through the
production compiler, exact constructor/setter parity, private negative-boundary
controls, immutable original observations/source resource and direct source
admission. The private controls are not new wire events or recorded scenarios.

Run after the coordinated source build:

```sh
python3 -B tools/run_tests.py --only vampiric_touch_input_checks
python3 -B tools/run_tests.py --only native_vampiric_touch_render_checks
```

The serialized GPU gate uses ordinary Play/Recording hosts for both original
seats. It checks native strike supply/admission, the measured casting hand and
recipient body contact, positive framebuffer contribution, absence before and
after the finite impact, replay seek/loop epoch replacement and final cleanup.

## Received future source preparation

The first cold native runs exposed `surface_source_preparing` when the receiver
changed to TakeDamage at impact. Existing media metadata already selected that
received clip, but EntitySurface prepared only the displayed source and its next
two columns. Preparing the displayed Idle source cannot warm a different
TakeDamage sheet.

The existing native preparation lane now forwards its original optical groups
to NativeInputs and EntitySurface. It considers only native-relevant actor/slot
interests and the nearest future received track transition for each interest.
Track starts/ends are evaluated through the existing `Tracks.samples` priority,
tie and source-clock policy. Exact `presentation_actor`, item looks, admitted
layer paths, geometry scalars, rig pivot and retained directions determine the
future source operands. The actual opening frame and at most two subsequently
crossed frames enter the same shared `_source_key` measurement queue.

The worker receives admitted immutable CPU images and scalar pose data. It never
reads a Node, material, Texture or future canonical state. No extra playback
readiness hold, clock delay, image fallback or ResourceLoader call was added.
Missing future media retries the existing preparation lane. Current measurements
retain priority; future requests use the existing two-worker/128-pending/128-source
bounds. A small owner snapshot avoids rescanning retained tracks every frame;
accepted requests are remembered under that owner so an evicted future result
does not endlessly requeue itself. Actual transition/owner/epoch changes replace
that finite preparation interest.

Read-only review caught and corrected an aliased retained-direction snapshot and
raw-track selection that bypassed overlapping-track priority. The focused
`entity_surface_checks` controls missing-media retry, exact future source sharing
between actors, immediate later sampling, overlap priority, in-place direction
publication, unchanged canonical prefix and existing queue/cache bounds.

The original Vampiric GPU gate additionally restores just before impact, waits
for source preparation while the original pre-contact prefix remains paused,
then publishes actual contact through the normal replay API in the same epoch.
It requires the published recipient's exact optical keys to have been measured
before contact, with zero new source jobs/builds at that first sample. This native
proof is distinct from the small headless optical fixture. The first native
attempt correctly failed this requirement: future source selection existed, but
the normal media owner had no future CPU-image demand. Selection now precedes
image-demand publication; deduplicated exact future source paths participate in
the existing native image key and required CPU/GPU records. An empty optical
owner replaces only finite future interest through public preparation and retires
those image requirements while preserving the shared optical measurements.

Coordinated native gate `.runtime/tests/20261020T010218.651770Z` passed **82 checks,
zero failures, script errors or unexpected errors**. Amber measured 33 source
poses before contact and still had 33 at contact; Blue measured 30 and still had
30. Their first-contact samples started no jobs or pending measurements. The
existing first-hit seek/loop pixel controls each observed 28 changed pixels.
This proves paused-prefix preparation/readiness and native contribution, not
short real-time queue lead, general performance, visual quality or whole-family
completion.

The final focused headless gate, including empty-owner demand retirement and
shared-cache preservation, passed **36 checks, zero failures, script errors or
unexpected errors** in `.runtime/tests/20261020T010322.980431Z`.

```sh
python3 -B tools/run_tests.py --only entity_surface_checks
python3 -B tools/run_tests.py --only native_vampiric_touch_render_checks
```

The implementation agent did not launch Godot, builds or GPU work independently.
Root owns the coordinated gate and visual checks. Persistent owner readiness,
repeat-attack attribution, positive healing and held/removal lifecycle remain
missing until actual disclosed operands and recordings support them. No Factory
package, backend rules or approved graphics were changed.


## Qualification

Headless first-hit input/ownership gate121checks passes;
`.runtime/tests/20261020T004039.952269Z/`. Native68checks passes for both original
seats, two seek/loop passes each,28changed pixels per impact, real surface contact
and explicit final owner/pass cleanup;
`.runtime/tests/20261020T004349.174641Z/`. No script/resource errors or exit
warnings on the final native gate. The initial native attempt sampled before
asynchronous exact source points were ready; the test now waits for the actual
native packet rather than treating world-only readiness as effect readiness.
No runtime clock hold or appearance change was added. This gate does not prove
short-queue first-use lead or the still-missing held/repeat/heal phases.
