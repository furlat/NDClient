# Positive healing and restoration — 2026-10-20

This cohort connects the existing observed-result producer to Power Word Heal's two finite restoration phases. It does not change the artwork, simulate healing, infer passive feature attribution, or qualify the complete spell family.

## Real source and engine evidence

The unchanged c494 Factory clips are:

- `high-level-22/power-word-heal/full_restoration`, sealed phase `assets/vfx/sources/58e42af97dd2888935ce/db349b64828e14df.tres`, 1.7 seconds.
- `high-level-22/power-word-heal/restoration_cross`, sealed phase `assets/vfx/sources/c2ea4d215e020d973d17/e6797c5b03266a5a.tres`, 0.85 seconds.

Both use `support_power_word_heal.gd` / `power_word_heal.gd`. Their finite admission requires the actual positive, unblocked `event_input.heal_fact`, its exact source and patient, and the same native occurrence key as the private constructor. Their original geometry/material/phase duration remain unchanged.

The frozen engine is `211b71134ed15c89e62232587381f7e15a5961c3`, schema 16. The actual capture is `.runtime/positive-healing-cohort/20261020T014922.271583Z`; its original journals, scenario, recording metadata and commands are copied unchanged to `tests/fixtures/schema16/scenarios/power-word-heal-restoration/`.

The legal scenario starts a wounded Knight, casts Hold Person through offered SDK choices, then has a different actual caster use Power Word Heal. It records 38 actual healing, resulting normal HP 59, and actual condition removals. Independent seats retain their different native identities:

| Seat | PWH root lineage | Spell occurrence | Heal occurrence | Heal lineage |
| --- | --- | --- | --- | --- |
| Amber | 89 | 108 | 104 | 101 |
| Blue | 105 | 124 | 120 | 117 |

The existing unchanged `power-word-heal` baseline heals zero and remains the real negative control. Private unit-test copies also exercise blocked healing, zero healing and a foreign recipient; these are explicitly test inputs, never recordings or authoritative facts.

Failed recording attempts remain under `.runtime/positive-healing-cohort/`: one relative-path launcher failure, one unsupported starting-paralysis setup, and two same-source affordability failures. The successful recipe uses a real Hold Person application and an independently available healing caster. No engine/setup constructor was added and no outcome was forced.

## Shared boundary

`ApplicationResults.observed_index` already selects positive, unblocked HealFacts and retains actual native ancestry. Its existing flat `actual_healing` / `blocked` fields remain available to previous consumers. The finite source additionally receives the exact disclosed `heal_fact`; no synthetic source condition or handler identity is supplied.

Power Word Heal's restoration cues now select `observed_event / heal` and actual recipient geometry. They are finite, have empty leases, and bind all endpoint actor UUIDs. The caster's face uses the already measured head registration rather than a guessed socket. The cast's spoken-word cue remains separately cast-owned.

The new positive original exposed a pre-existing clock-order defect: native spell result cues were emitted before their child result clocks were scheduled. Root owns the bounded Components/Compiler correction, preserving captured optical delivery points and emitting these non-cast observed phases during the existing post-schedule component compilation. Ordinary cast/body/event ordering stays intact; no gameplay queue, clock hold or second reducer is introduced.

## Gates and limits

- `tests/positive_healing_event_checks.gd` loads the typed PWH entry in memory, folds both original seats, checks exact positive/zero/blocked admission and source/recipient/result identities, verifies real captured condition before-values under the actual PWH ancestry, checks source immutability, and compares the complete replay against the independent canonical reducer state.
- `tests/native_positive_healing_render_checks.gd` is a Forward+ GPU gate using ordinary `Play` and `Recording`. It requires actual prepared input admission, measured patient/caster geometry, finite before/during/after intervals, independent framebuffer contribution of each of the two original sources, seeking/looping teardown and immutable canonical/source state. It saves actual present/hidden-control PNGs only under `.runtime/positive-healing-captures/`.
- Focused command: Godot `--headless --path C:/Users/tommaso/Documents/Dev/NDClientGodot --script res://tests/positive_healing_event_checks.gd`.
- Native command after the coordinated abilities source build: Godot `--rendering-method forward_plus --path C:/Users/tommaso/Documents/Dev/NDClientGodot --script res://tests/native_positive_healing_render_checks.gd`.

Source availability, factual provider qualification, scenario coverage, native output and user visual approval are separate. PWH remains `partial`. The imported existing/retiring paralysis and poison demonstration cues are not promoted to a real held lease or declared implemented by this cohort. Actual removal of paralysis is checked from original native facts; it is not claimed as qualification of those unbound Factory probes. No positive healing is inferred from a cast, and no blood/light/art tuning is included.

Qualification result will be appended after the focused regression and root's serialized native run.

## Focused qualification

The headless gate passed **251/251 checks, zero failures and zero script/resource errors**, exit 0 (`.runtime/positive-healing-cohort/headless.log`). The exact positive result starts both finite sources at the real healing commit in each seat; the zero-heal original admits neither. Both full replays drain to the canonical independently reduced state.

The original removal chain also ends `condition.concentrating` on the former Hold Person caster. The gate checks every removed membership against its own captured actor/condition UUID, and separately requires the paralysis/Hold Person members to belong to the PWH patient. It does not force all secondary effects onto the patient or turn the former caster into the healing recipient.

The Components correction is confined to passive compile-time phase data and the existing post-schedule component pass. It preserves the captured delivery operands and explicitly sets the result start before `add` merges parameters, so an old phase start cannot overwrite the actual healing onset.

Native output qualification remains root's serialized gate after the coordinated abilities build. No GPU run, source build, Factory change or artwork retuning was performed by this cohort worker.

## Bounded correctness review of the shared fixes

Read-only review covered `Components.native_spell` / `Components.compile`, the existing delivery-scope filter and `Components.add`, plus `Timeline.replay_publish` and its ordinary Play publication callbacks.

- The retained value is the already selected phase's local offset from its owning native spell start. Post-schedule emission adds that offset to the exact real result clock. Explicitly replacing `parameters.start_ms` before `add` is necessary because `add` merges parameter keys over its initial row; the previous phase start otherwise wins. The 251-check original-journal gate proves both PWH phases start at their actual heal commit.
- The deferred record retains the selected constructor, actual result occurrence, source/recipient and optical delivery operands captured during normal spell scheduling. Only its private timing field changes later. Sealed Factory resources, canonical event facts and the shared source recipe remain unchanged.
- Cast-owned phases still emit in the original scheduling path. Only actual non-cast observed rows enter the passive compilation list; an empty heal result emits nothing. Existing delivery-scope filtering remains the sole cast/application ownership filter, rather than introducing a second selection policy. Current PWH originals yield exactly two distinct restoration phases per positive result and zero for their zero-healing control.
- Replay now preserves the exact prepared candidate, performs the existing atomic delta publication and preparation cancellation, then calls the same source-owner transfer hook as live playback once. Clearing preparation first prevents reuse of that plan. The Play hook consumes source-only work; returning false for real world work retains its ordinary scene-publication path. Replay-media release currently clears only its borrowed group list, not the pending prepared owner's resources.
- The original Divine Arm replay callback regression independently passed **75/75**, no errors (`.runtime/tests/20261020T015415.644918Z/dynamic_item_effect_checks.log`). It covers exact candidate identity/clock, consumed-plan rejection, an unready world candidate, false-return full-world publication and no-boundary advance. It does not claim GPU visibility.

No additional correctness or anti-OOP blocker was found within this bounded review. No new projection, schedule/body reorder, renderer, validation layer, gameplay queue or source position inference was added. Native output remains the separate root-owned GPU gate.
