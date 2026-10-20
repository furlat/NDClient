# Authentic Banishment departure inputs

Design only; no runtime, Factory, source-art or build changes in this cohort review. This is the actor-history row of `SCHEMA_AUTHORING_CONDITIONS_STUDIO_PLAN_2026-10-19.md`, not a second renderer/reducer/history manager. Native visual qualification remains blocked by the two installed Factory actor-history shaders below.

## Actual evidence and present failure

Original frozen-211b two-seat recording:
`.runtime/studio-library/cases/spell.banishment__baseline/20261019T141950.309234Z/{amber,blue}/journal/`.
Both seats contain nine unchanged packets; `scenario.json` records one legal Banishment cast and `recording.json` identifies its original engine. This baseline proves admission, not removal/return.

| Actual public operand | Amber | Blue |
| --- | --- | --- |
| Packet sequence | 8 | 8 |
| Banishment application occurrence | 58 | 62 |
| Native lineage / parent occurrence | 51 / 50 | 51 / 50 |
| Recipient actor UUID | `1748b71c-ed20-4031-b138-a5fb41c97d68` | Same disclosed actor |
| Condition UUID | `4505a00a-6bf6-4ab6-8651-fa2304a618cc` | Same disclosed instance |
| Actual condition behavior | `condition.spell.banishment` | Same behavior |
| Other row in that ActorChangeFact | `spatial_disposition=absent` | `spatial_disposition=absent` |
| Additional spatial evidence | Not disclosed | `entity_left`, occurrence 56, native lineage 53, position `[4,7]`, commit occurrence 53 |
| Duplicate count | `null` | `null` |
| Duration | Undisclosed | Ten rounds |

Do not join seats by occurrence/sequence or fill Amber duration from Blue. Blue's `entity_left` is not a `terminal_departure` fact; the current SDK does not clear the retained visual position for this ordinary fact. The condition admission precedes the later sensory removal. Capture each seat's own pre-admission state; do not guess an earlier disappearance cut from the event name.

Current client blockers are independent of the shader defect:

- `Timeline.pose_admissions` runs before the actual canonical after-value, but `ConditionPose.capture_requested` only recognizes `persistent.frozenPose.captureCurrent`. Banishment therefore retains no original pose/outfit.
- `NativeInputs.current_pose_history` deliberately accepts only zero-delay, non-departure Mirror copies. Its refusal to bind current pose as Banishment history is correct.
- `SpellPlacement.endpoints` rejects every non-spatial persistent owner whose recipient is no longer displayed. A real departure packet alone cannot bypass that earlier rejection.
- `NativeInputs.sync` demands an actual `duplicate_count` for every `history_state` input, although the sealed non-Mirror compositor does not use that count to enable copies. Do not manufacture three duplicates.
- `ActorResources.build_private` currently prepares neutral condition parameters; it is not sufficient by itself for a departure with another active body material/scale. The body selection, material operands and transform must be the actual pre-admission ones.

## Sealed Factory contract

`assets/vfx/conditions/condition_banishment_persistent/application.gd` configures `actor_history.capture_departure=true`, `mirror=false`, one `banished-echo` with delay `.08`, opacity `.13`; application/removal are each `.35` seconds. Registration is `recipient_ground`, anchor `ground`, offset zero, scale one. Do not replace these with a fabricated body-center socket or extend the owner from the finite demo length.

`assets/vfx/conditions/actor_history.gd::set_actor_context` accepts actual `Camera3D`, renderer `receiver_depth:Texture2D`, `depth_encoding='rgb24_reversed_z'`, viewport size, actor UUID, pose key, material revision, and actual MeshInstance3D/material layer descriptors. For departure it additionally supports:

| Field | Owner / meaning |
| --- | --- |
| `departure_layers` | Private actual assembled layers realized from the original logical departure, for this current view |
| `departure_revision` | Original condition/admission identity; unchanged by camera, lighting or later actor state |
| `departure_capture_revision` | Optical realization identity: logical capture plus view/source/material revision |
| `departure_origin` | Original ground/height-derived renderer position; unchanged by camera recapture |

The Factory stores an original departure snapshot and refuses a changed optical revision without explicit departure layers. Its internal compositor captures assembled colour/depth; the client need not read GPU pixels back or inject a history array. The sealed API has no public historical-frame ingestion setter.

## Small implementation sequence

1. **Typed intent and ordered logical admission.** Add one explicit `capture_departure` boolean to existing `PresentationCondition` Lifecycle fields, enabled only in `condition.spell.banishment.tres`; round-trip it in `ability_records.gd` to `persistent.actorHistory.captureDeparture`. It is separate from frozen body pose arbitration. Existing offline build checking must prove that this capability selects a departure/non-Mirror constructor; runtime must not repeatedly validate source metadata.
2. **Retain the real departure operands.** Extend `Timeline.pose_admissions` and `ConditionPose.admissions`, using the existing before-apply seam and condition-UUID owner. The helper needs the canonical pre-cut state, not only its actor dictionary: item looks and support elevation belong to that same immutable before-value. Retain the existing exact clip/source-seconds/frame/world-facing/hidden-slots/admitted-at fields, plus the resolved pre-cut actor row, visual-loadout/item-look operands and immutable pre-cut body treatment operands. Include actual motion lift/passage sample when present. Use existing `Characters.resolve/structure`, `Tracks.samples` and `Conditions.material` selection; no file/image loads or scene construction at commit. Never mutate the actor into a temporarily present state to resolve it after disappearance. Existing canonical state and ordered commits remain identical.
3. **Prepare private optical layers in the existing occurrence owner.** `NativeInputs.prepare`/`NativeRenderer.prepare` use the retained operands and existing `Characters.prepare_layers`, `ActorConstruction.prepare_binding`, `ActorResources.build_private` worker path and actual resident colour/normal/depth textures. Give that existing constructor optional exact captured condition parameters; ordinary neutral preparation keeps its present default. Retain shared texture/source Resources and create private MeshInstance3D/material operands. Keep these capture-only nodes outside published actor membership/output collection; their sole lifetime owner is the native occurrence and its existing close/reset path. Release every temporary node explicitly. No new manager, global capture table or broad preload.
4. **Use the same body math.** Extract only the existing pure actor layer transform calculation from `Play._sample_actors` into `ActorConstruction` if necessary, and call it for displayed and capture-only layers. This must preserve actual camera basis, world-facing, support elevation, scale/BodyScale, lift and passage deformation. Do not copy the large actor sampler, borrow later material uniforms, or reconstruct an outfit from a later row. Existing current lighting/depth receiving references may change with the optical view; logical pose, tint/outfit and pre-admission body-treatment operands cannot.
5. **Bind the packet and departure registration.** Extend the existing `NativeInputs.actor_context` path with the prepared departure packet. The earlier `SpellPlacement.endpoints` guard may use an explicitly ready original departure row for this declared capability and ground registration only; ordinary hidden recipients still fail. A missing original capture stays `condition_original_departure_not_observed`; pending texture/layer preparation stays pending. Forward `history_state` as explicitly not applicable for the proven `mirror=false` departure constructor using existing input-policy diagnostics, rather than claiming a supplied count. The existing offline policy check must qualify this exact semantic branch. Mirror count remains authoritative and null remains missing there.
6. **Keep sampling and cleanup in their current owners.** Banishment has one held departure, not a rolling delayed pose stream. Once its actual packet is prepared, use owner age directly only for this source-proven departure mode; never label Blur seekable/current-pose-safe. Camera recapture rebuilds optical layers from the same departure and increments only capture revision. Existing `Effects.close`/renderer retirement frees both occurrence and private capture nodes, including epoch reset, reverse seek, cancellation and removal fade completion.

This changes no SDK wire shape, no rulecaster/event UUID, no group/commit scheduling and no canonical actor visibility. An absent actor stays absent; the echo is a separately owned native output.

## Seek and removal ownership

`studio/recording.gd` already calls `Timeline.pose_admissions` before applying each compiled delta. `Recording.restore` traverses the original faction prefix; extending that shared seam reconstructs the original capture on seeking minutes into the hold. Do not capture the actor shown at the destination seek time. `restore_boundary` remains an inspection prefix, not another reducer.

Retain the departure only while its actual condition owner (including real removal fade) exists. Remove/reapply must keep the first removal owner's immutable capture separate from the new condition UUID/admission. An initialization that starts already banished with no original prefix is explicitly unavailable. Do not synthesize an admission, start time, pose or return.

The current baseline has no removal. Before claiming lifecycle completion, add one legal recorded cast → actual concentration drop/dispel → actual return case through the frozen SDK recorder, preserving failed originals. That is a later authorized recorder task, not work performed in this design review. Require exact condition removal, real spatial/body return if disclosed, and ordinary current body restoration after the native removal interval.

## Files and gates

| Work | Smallest existing owner / test |
| --- | --- |
| Typed flag / passive build | `presentation/source/abilities/condition.gd`, `tools/presentation_build/ability_records.gd`, narrow `abilities.gd` offline validation, Banishment condition TRES |
| Ordered admission / seek | `presentation/condition_pose.gd`, `presentation/timeline.gd`; corresponding existing `studio/recording.gd` helper calls |
| Original outfit / private realization | Existing `actor_resources.gd`, narrow `actor_construction.gd` pure transform seam and its existing Play caller; `native_inputs.gd`, `native_spell_renderer.gd`, `spell_placement.gd` departure registration |
| Durable evidence | Copy unchanged original two-seat journals plus original scenario/recording headers into `tests/fixtures/schema16`; catalog key only after fixture is complete |
| Headless gate | New `banishment_departure_checks.gd`: both real admissions, independently expected actor/condition IDs and original position/outfit, not-yet-admitted negative, held/reverse seek agreement, null-count non-Mirror vs Mirror control, no frozen-body arbitration, absent actor canonical state unchanged; all original frozen-pose controls retained |
| Native gate | New `native_banishment_departure_checks.gd`: ordinary Play + real original recording, actual private source/frame/parameters and source Texture identities, all four camera recaptures retaining logical revision/origin, independent occurrence owners and cleanup, reverse seek/no future echo, real removal/return once recorded; exact original-source colour/depth/pixel comparison, no substituted effect |

During implementation, use the existing plan-adherence reviewer and a short anti-slop/anti-OOP boundary review before source build. In particular review the pre-cut material/transform seam and absent-recipient exception. Root serializes builds/GPU; no source-index rebuild or test launch was performed for this note.

## Limits that remain red

All three actor-history families reference shared programs
`e7ee404afa25f1a82e67ee0e853f083d0e72c1c568063acea0d3b2074d02f6bb.res` and
`bda6d5b000039e4a932a2da57906325cb960203a5955eb6f5b5b0d9510d14dff.res` under `assets/vfx/shared/resources/`. The existing native Mirror log `.runtime/tests/20261019T231410.817195Z/native_actor_context_render_checks.log` reports invalid serialized `#include` programs. The original Mirror gate stays red; no suppressing its assertions, editing Factory programs locally, or labelling packet admission an output qualification. A corrected sealed Factory source is required for positive native history output.

Blur additionally needs actual `.08/.16/.24`-second observed prefixes, not a departure snapshot. Its durable two-seat `tests/fixtures/schema16/scenarios/blur` recording has real application, movement and removal, but the current compositor accepts only current context and keeps its own sample history. A separate bounded client cohort must drive real ordinary hidden playback across the retained prefix and exact source ages; sampling today's pose at older times is forbidden. This Banishment work does not claim Blur completion, shader repair, visual acceptance or performance approval.
