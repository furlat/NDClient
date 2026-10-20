# Shared-provider completion checklist — 20 October 2026

This is the finite capability worklist for completing the selected Factory migration, not a spell-calibration queue. It follows Phase 4–6 of [the active plan](SCHEMA_AUTHORING_CONDITIONS_STUDIO_PLAN_2026-10-19.md). The audit is offline; it does not qualify rendering, scenario outcomes, frame time or user approval.

## Inventory and evidence boundary

Installed package: `runtime-e102c29dec58524b`, source revision `51f55198b28113fdcc90df9d0613b1f50960d354`. Public engine authority remains frozen schema 16 at `211b71134ed15c89e62232587381f7e15a5961c3`.

| Derived inventory | Count | Meaning |
|---|---:|---|
| Package clip IDs | 1,246 | Source availability, including unassigned weapon delivery |
| Clip IDs referenced by selections | 1,159 | Union of the actual 504 selection rows; not all are active/default or authored |
| Selection rows / condition lifecycles | 504 / 155 | Exact current index rows, including variants |
| Selected declared input channels | 70 | Each is assigned to one dependency group below; the complete package has 71, including unselected weapon_impact |
| Unreferenced weapon clip IDs | 87 | New weapon delivery is present, but has no selection assignment |
| Typed sources: spells / conditions / actions | 191 / 281 / 258 | 730 source Resources in the audit snapshot |
| Engine IDs / joined subject IDs | 639 / 745 | Existing inventory join, not a new runtime registry |

Exhaustive machine evidence: `.runtime/consolidation/shared-provider-completion-e102/report.json`. `selected_runtime_matrix` contains every referenced clip, declared inputs/setters, native/recorded source paths, prepared approach flag, exact selection keys, typed default/variant uses, constructor descriptors, explicit missing inputs and scoped inapplicability. `selection_ownership` preserves all 504 condition selectors and phase IDs. `channels` covers all 70 channels. This is ignored audit output, not application state or a second authoring catalog.

The 220 unselected alternatives are **approaches**, not 220 additional clip IDs. Their existence authorizes no default/art swap. Group clip/selection counts below overlap because one selected family consumes several capabilities; they must not be summed as completed families.

The latest static typed-cue snapshot reports 218 provider-present/unqualified cues, 55 provider-gap cues, 18 explicit gaps, 125 owner handovers, 11 authored-disabled cues and 6 excluded probes. These are dispatch dispositions. A present dispatcher is not proof that its constructor, all setters, actual native output or every family branch is complete.

**Current shared checkpoint:** actual selected lifecycle media replacement and all three native history modes have passed their cohort gates. Shared same-cast created-item identity and actual actor-birth manifestation ownership now pass logical and native output gates. Explicit display-facing cosmetic gaze passes1465 source-equation and257 native-output checks on both original owners/all four published views. See the dated cohort handoffs. This updates implementation/output facts without claiming final live readiness, all historical equipment transitions, missing public inputs or user art approval.

## Supported substrate to reuse

- `NativeInputs` supplies actual displayed layer/material identities, EntitySurface points/normals/UVs, named endpoint sockets, current camera/depth, precise owner visibility, authored delivery timing and condition/item membership. Topology/media share; actor transforms, source clocks, materials, UUIDs and leases remain private.
- `NativePersistent` supplies application/hold/removal from actual UUID lifetimes. `ConditionPose`, Timeline and Recording preserve original departure/logical-pose operands before the cut. `NativeItems` observes exact disclosed item/effect membership, equip/drop/transfer and intrinsic authored effects without forging condition UUIDs.
- `ApplicationResults`, existing Components constructor dispatch, `NativeActionAuthoring`, `CreationInputs` and `PropagationInputs` project actual ordered application results, observed damage/healing/revival/removal, item/object admission and propagation. These are the extension seams; do not add another event framework.
- Preparation already has exact wanted/next source ownership, immutable metadata workers, shared physical media/program admission, future received pose interests and bounded EntitySurface jobs. Publication remains ordered. Missing input must not cause a presentation-clock hold, future canonical publication, fixture construction or synchronous texture readback.
- `NativeInputs` forwards `component.native_inputs` to declared setters, deduplicating actual values. Its final same-name `condition.state[name]` fallback is **not** a factual projector for the many channels absent from public ConditionState.

## Finite shared dependencies

### 1. Close selected owner and optical-source ownership first

**Inventory:** 959 clips / 398 selections. Channels: `activation_projection`, `actor_layers`, `appearance_provider`, `binding_owners`, `delivery_timing`, `entity_geometry`, `live_endpoints`, `owner_projection`, `owner_state`, `owner_visibility`, `pose_provider`, `recipient_geometry`, `root_path`, `targets`, `treatment_state`.

The optical mechanisms exist. The remaining shared work is to apply them consistently to the **actual selected** lifecycle/cue and retain honest missing operands. `NativePersistent.replaced_media` now uses the same actual disclosed member predicate as `lifecycles`. Missing/mismatched selectors preserve old media; all 42 conditional selections across nine families pass 929 checks, including ordered remove/reapply and source/phase agreement.

Explicitly authored display-facing gaze now uses the actual displayed world facing and the delivered source offset. Remaining optical gaps are arbitrary saved review trajectories, genuinely required missing offhand grips in legacy/explicit-hand sources, and unresolved original native-hit framebuffer/body-treatment overlap for departure capture. Prepared Measured/FlameBlade receivers now use exact weapon-surface optical registration when no grip is authored; pending known grips retain their original preparation ownership. Current endpoint/geometry support must not substitute nearest actors, later poses or source review points. `source_geometry` already has an implementation but is declared by zero clips in this selection union; it is not another unimplemented channel.

**Existing files:** `native_persistent.gd`, `conditions.gd`, `components.gd`, `native_inputs.gd`, `native_spell_renderer.gd`, `spell_placement.gd`, `entity_surface.gd`, `condition_pose.gd`, existing typed cue Resources.

- [ ] Gate the shared ownership path across every compatible matched selection: exact original UUID and selector, same-frame remove/reapply, multiple owners, inherited source/recipe media, mutable pose/equipment, hidden/unseen owner and ordered removal/restoration. An unmatched native variant neither draws nor claims replacement. Studio retains its missing requirement.

### 2. Finish authentic assembled-actor history as one cohort

**Inventory:** 9 clips / 3 selections. Channels: `actor_context`, `history_state`; Blur, Mirror Image and Banishment application/hold/removal.

Earlier `current_pose_history` accepted Mirror-only zero-delay context and rejected Blur with `authentic_actor_history_not_bound`. Actual source `assets/vfx/conditions/actor_history.gd` supports non-Mirror delayed contexts. Blur's specifications are 0.08/0.16/0.24-second motion copies plus a current contour; it needs genuine earlier assembled poses/materials and private current-view capture, not a duplicate of the current sprite or another actor.

`duplicate_count` is a **Mirror-only operand**. The public source computes a count but applies it only when `settings.mirror` is true. Null must never reach its `int` conversion. Blur and Banishment must not request a backend duplicate count; Mirror must preserve actual 0–3, including zero. The rolling and departure branches mark that field inapplicable explicitly and pass actual native output gates.

Banishment must retain the immutable actual pre-cut visible body, source/material/item/pose and UUID even where Amber's after-position is null and Blue retains a remembered position. Reuse the existing visibility gate. Do not seed it from a seek destination or claim an unobserved departure. Original capture, current camera recapture and bounded genuine past-context seeding on seek are distinct operations.

**Existing files:** `native_inputs.gd`, `condition_pose.gd`, `timeline.gd`, `studio/recording.gd`, `actor_resources.gd`, `actor_construction.gd`, source `conditions/actor_history.gd` and its three parameterized lifecycle families.

- [ ] Gate all three source branches on original independent faction journals: no invented past, correct count/null handling, private source clocks/materials, actual four quarters, movement/seek/loop, camera/viewport/outfit changes, removal and joined teardown. Source shader compilation and nonzero framebuffer output are separate from logical capture.

Qualified native history evidence: [shared history handoff](SHARED_HISTORY_PROVIDER_2026-10-20.md). Real history topology allocation resumes under the existing frame budget; original departure and bounded prefix seeding touch only the capture helper, never restart the occurrence clock. The broad row gate still includes live/gear-transition qualification.

### 3. Generalize ordered factual event/result operands, then bind the compatible families together

**Inventory:** 262 clips / 98 selections. Channels: `cancellation_observation`, `cast_observation`, `cast_presence`, `condition_input`, `condition_state`, `contact_event`, `damage_event`, `event_binding`, `event_input`, `event_state`, `grant_state`, `healing_input`, `hit_input`, `lease_input`, `native_state`, `observation`, `operation_state`, `owner_input`, `quarry_input`, `recipient_outcomes`, `review_contacts`, `strike_input`, `tick_input`, `trigger_event`.

**Already factual, not universal:** application-result save/damage; completed observed casts; positive applied damage/heal; actual revival; before-member condition retirement; creation admission; initial Vampiric Hit/Crit; actual Vampiric positive healing return with the caster healed and enemy optical endpoint; actual Vitriolic initial contacts; completed Divine Word proclamation. Existing dispatchers must not manufacture the missing held/repeat/recipient-tier semantics from these proven branches.

The next shared inputs must be derived at the existing immutable ordered row/application seam:

| Compatible family set | Exact requirement still needed | Source contract / failure boundary |
|---|---|---|
| Branding/Searing/Divine smites, Ensnaring Strike | Real weapon attack identity, source/recipient/item/slot, hit/critical, exact applied damage component and attributed condition/tick | `sources/397ef2a8907055317449/smite_common.gd`: `strike_input`, `condition_input`, `tick_input`. Any damage on the target is not the rider. Frozen setup crashes remain separate. |
| Hex / Hunter's Mark; retained-contact variants | Exact sustaining owner and linked recipient quarry owner, original source, actual attack/rider component; present/observed/effective membership | `sources/1dc77e979e0f18992748/quarry_common.gd`; retained-contact source `sources/43d964a5ab22cb82ad2d/retained_contact.gd`. Initial quarry admission alone does not disclose every required link/effectiveness operand. |
| Divine Favor and other weapon-hit receivers | Actual attributed hit/damage event tied to equipped item/owner | Declared `hit_input`/`damage_event`; reuse exact application/event ancestry, not all outgoing damage. |
| Divine Word recipient tiers; Prismatic Spray | Actual per-recipient disclosed outcome/tier/result under its cast | `observation` / `recipient_outcomes` / `cast_presence`. Completed proclamation or cast presence does not supply unseen recipient outcomes. |
| Dragon's Breath grant/exhale | Real grant UUID, recipient, original caster and element; actual recipient action admission plus face/cone endpoints and damage | `sources/2f6628255a3170c06996/dragons_breath.gd::set_grant_state`. Baseline only exposes concentration, not the complete required grant packet. |
| Blessed Healer / Destroy Undead / rider passives | Actual `effective_handler` attribution and emitted result lineages; exact rider component where required | Existing handler-join seam. A matching spell/amount or class level is not public attribution. Original passive studies retain the missing attribution evidence. |

**Event-gated conditions are a distinct subcohort:** 21 selections / 63 lifecycle phases request both `event_binding` and `event_state`: 13 draconic breath cadence variants, 4 elemental multiattack prerequisites, 3 Myrmidon strikes and Tenacity. `assets/vfx/conditions/runtime.gd` requires real condition/source IDs, observed active state, monotonic revision, event serial, actual owner/phase ages and any declared matching fields. Readiness additionally requires observed mouth-region/revision; committed-damage variants require actual positive damage/contact and surface revision. Their false/retirement event must correspond to the same real event, not a synthetic idle tombstone. These values are not public `ConditionState.event_state` fields. Some selectors also lack public operands (section below).

**Existing files:** `application_results.gd`, `components.gd`, `native_action_authoring.gd`, `native_inputs.gd`, typed `EffectUse`/ability Resources and existing immutable transition graph. Keep constructor operand production, runtime setter forwarding and source-specific applicability separate. Extend an existing descriptor only where those actual rows prove its meaning.

- [ ] Gate every compatible assigned cue across this cohort, not one example: exact local native parent/lineage/source/recipient/owner, cancellation/request/zero/blocked/foreign/unseen negatives, result clock, retained ownership and removal. Enumerate missing public members explicitly rather than automatically enabling all setters with the same name.

### 4. Complete item/weapon decoration without replacing the weapon sprite

**Inventory:** 74 clips / 31 selections. Channels: `created_item_binding`, `created_item_identity`, `enchantment_input`, `item_snapshot`, `owner_binding`, `weapon_binding`.

The authorized model is the modular character's separate weapon sheet plus attached native decoration. `Gear.effects` and `impact_effects`, BodySourceIndex item bindings, `NativeItems` and `NativeWeaponInputs` provide the existing path. No production Gear Resource in this audit assigns either field, despite the infrastructure being present. The 87 new unselected weapon IDs are an **assignment/authoring task**, not missing loader support. Their approaches must retain the user-approved source policy.

Actual `weapon_binding` resolves disclosed item UUID, current holder, equipment slot and displayed separate weapon layer. Intrinsic owners use item UUID + authored source, not a fake effect UUID. Dynamic coatings use actual effect membership/attribution. An actual authored main hand keeps its unchanged point/binding. For the45prepared Measured/FlameBlade clips, an exact cached optical support centroid supplies registration only when that grip is genuinely unauthored; no `binding.hand` is invented. Explicit hand endpoints and17legacy source clips keep their real grip/contribution requirements. Native main/shield optical controls and actual dynamic equip/unequip/seek pass; a legal offhand weapon-condition scenario remains unrecorded. Baked full-character weapon attachments are deferred and may not borrow guessed hand offsets.

- `created_item_binding` occurs in six selected clips that instantiate a native weapon body. `wielded_native_bodies_not_supported` is deliberate user policy. Do not “complete” this group by enabling body replacement. Spiritual Weapon remains a separate summoned actor.
- `created_item_identity` on the measured Flame Blade overlay now joins actual same-cast item/lifetime/caster admission and the current equipped item through the shared creation descriptor. Amber native output is qualified; Blue explicitly lacks creation ancestry. See [the identity handoff](CREATED_ITEM_IDENTITY_PROVIDER_2026-10-20.md). No source review identity is substituted.
- Continual Flame's `item_snapshot` and Shillelagh's `enchantment_input` need exact item-owner construction. `contribution_active` / `decoration_admitted` are legacy source requirements, not universal wire fields; inspect the actual selected source branch before declaring them missing or inapplicable.
- Missing legacy Antimagic suppression is not an unknown current rule: schema 16 retired that active suppression field. An explicit observed override still matters. Do not request a fake old field to satisfy a source interface.
- Three `owner_binding` clips are production-candidate Aid/Bless/False Life treatments that the user has not accepted. Source availability is not approval.

**Existing files:** typed Gear/EffectUse, character builder/BodySourceIndex, `native_items.gd`, `native_weapon_inputs.gd`, `native_inputs.gd`, `creation_inputs.gd` and current item/effect membership transitions.

- [ ] Gate the assigned decoration cohort across equipped/unequipped, swap/offhand where authored, drop/pickup/transfer, intrinsic/dynamic overlap, exact damage-contact ownership and condition removal; original sheet pixels remain. No whole-body or native blade fallback. Publish remaining missing sockets/assignments and public provenance separately.

### 5. Bind actual spatial membership, payload state and world transitions

**Inventory:** 61 clips / 55 selections. Channels: `accepted_release`, `admitted_cells`, `blast_event`, `body_state`, `glyph_state`, `membership_present`, `patch_states`, `payload_anchor`, `payload_state`, `removed_cells`, `retirement_time`, `suppressed`, `surface_presence`, `surface_records`, `surface_state`, `transition_events`, `visual_occupants`, `visual_state`, `wet_presence`.

Actual spatial UUID/cells/membership already drive the shared `SpatialInputs` / persistent path. `admitted_cells` has explicit grid-frame/capacity/topology constraints. `removed_cells` requires the real spatial owner and recorded retirement observations; loss of sight is not burning or disappearance. The new `surface_presence` branch is in flight, not an excuse to infer all surface transition channels.

| Family | Remaining exact dependency |
|---|---|
| Web and reactive surfaces | Current owner/cells can bind; partial burn/removal/interaction needs real observed transitions for `reactive_web.gd::set_transition_events`, not inferred collisions or subjective visibility loss. Body Restrained is a separate owner. |
| Create/Destroy Water; reactive liquids | Actual named surface records, wet membership, interaction/retirement semantics. An unnamed condition or spatial `created` boolean is not the complete `wet_presence` / reactive event packet. |
| Glyph of Warding | `glyph_state` must include actual spatial/caster owner and armed observation; actual baseline spatial creation does not publicly disclose armed/payload/trigger state. |
| Flaming Sphere | Current spatial owner is available; ram/turn-end `contact_event`, real body and patch state require exact observations. |
| Freezing Sphere / Delayed Blast Fireball | Actual accepted release, payload anchor/state, surface/blast event and damage; no timed synthetic detonation. |
| Vitriolic Sphere | Initial applied contacts and residue owner handover exist; delivery targets/accepted release, blast event and later END native-state packet remain explicit gaps. |
| Walls of Wind/Thorns | Real `visual_state`, admitted occupant/contact records and transition evidence; no saved review occupants. |

Sources: `sources/f9823d19833208be9e82/glyph_of_warding.gd`; reactive Web `sources/4d694813ce66e646e55c/reactive_web.gd`; combustible liquid `sources/50f35275a290e51059ff/combustible_liquid.gd`; reactive liquid `sources/979ecf1a1d9d8264d287/reactive_liquid.gd`. Exact complete per-phase paths are in the machine matrix.

**Existing files:** `spatial_inputs.gd`, `native_persistent.gd`, Timeline/ordered world transitions, `native_inputs.gd` and existing constructor descriptors. Separate exact cell membership from producer outcomes such as damage/burn/armed/accepted-release.

- [ ] Gate each supported spatial contract across original two-seat cuts, empty/partial membership, source hidden, actual removal/return, placement/scale and finite source capacity. Keep unsupported payload/trigger/event semantics missing; never convert a visual absence into an authoritative event.

### 6. Finish propagation consumers using the actual graph

**Inventory:** 11 clips / 11 selections. Channels: `density_field`, `link_edges`, `live_particles`.

`PropagationInputs` already reads actual application propagation/source/target/predecessor lineage and constructs optical links with real sockets and authored travel speed. It supplies `link_edges`. Exact density inapplicability is offline-qualified only for the disabled branch of the selected single-chain source; it is not a blanket channel opt-out.

Other selected declarations request an actual density field or native particle observation. There is no same-name public `ConditionState.live_particles` fact. A compatible source must either consume actual presentation-owned particles through its declared interface, or remain explicitly unsupported; do not synthesize a density graph from nearest actors.

**Existing files:** `propagation_inputs.gd`, Components constructor dispatch, `native_inputs.gd` and exact selected source/descriptor declarations.

- [ ] Apply the existing propagation contract to every compatible assigned link family and qualify branching/multi-target, canceled/unseen predecessor, exact source/result clocks, seek/loop and source-scoped inapplicability. Report noncompatible density/particle consumers separately.

### 7. Interrupted-source reaction presentation needs a real source interface

**Inventory:** 2 clips / 2 selections; `reaction_observation`.

`ReactionInputs` already proves actual ActionFact.reaction, triggered lineage/version/parent, succeeded value and source/target; optional effective-handler attribution is corroboration, not a substitute. Calling the reaction fact missing would be a false blocker.

The client still reports `reaction_incoming_presentation_path_unavailable`. Factory `sources/cc262dc75f07638cfd9a/counterspell_study.gd` retains its own saved incoming source/contact fraction. Its setter checks native identities/contact, but does not turn a real moving interrupted incoming presentation into the source's fixture trajectory. A constant hand endpoint would qualify only that narrower treatment, not an interrupted flight. This requires an explicit compatible source contract, not another backend success bit or a generic cast mapping.

- [ ] Keep the exact factual reaction available to Studio now; qualify no moving-prefix claim until the source can consume actual immutable incoming presentation/phase/path/material/clock. Then cover success/failure/canceled incoming, moving/constant cases, independent seat disclosure and private owner cleanup.

## Public-data blockers that must not consume client implementation time blindly

There are **28 literal selection rows** with missing public selector operands: 5 dragon shared-resistance `damage_type`; 3 paladin aura `aura_kind`; 13 draconic cadence `breath_type`; 4 elemental multiattack `prerequisite`; 3 Myrmidon strike `action_id` + `damage_type`. Public ConditionState has `energy_type`, but the actual dragon/Myrmidon originals contain null; a rename cannot recover the private selector. Protection from Energy already publishes the correct `energy_type`. Fire Shield's public element names retaliation while resistance is the opposite, proving a global alias is wrong.

Exact owner UUIDs, packet locations, producer code and positive controls are retained in [the producer-gap handout](CONDITION_SELECTOR_PRODUCER_GAPS_2026-10-20.md). The e102 selection audit still finds the same literal rows. Also retain explicit missing Frenzy parent identity, passive effective-handler/rider provenance, grant/readiness and payload outcomes where absent. Missing public evidence blocks only the affected variant or phase; it does not justify stopping unrelated shared providers.

Lawful source/setup failures remain distinct: frozen Branding/Searing/Ensnaring baseline `game_failed`, Spare the Dying patient-discovery exclusion, and the developer-only fixture spell with no registered action. Single-target Hellish is now a positive original baseline; the old area-trigger case remains unresolved. See [the backend handout](BACKEND_SPELL_SETUP_GAPS_2026-10-20.md). Do not treat those recipes as native provider failures or edit emitted facts to complete inventory.

## Source and policy boundaries

- e102 closes the old actor-history shader dependency errors and includes the public same-age refresh hook. This is source/API readiness, not native output qualification. Preserve the narrow client fallback for hookless sources until the exact successor branch owns the refresh without double native deltas.
- Recorded Insect Plague still lacks its actual private material clock tracks: [source defect](FACTORY_SWARM_RECORDING_HANDOFF_2026-10-20.md).
- Recorded Sleep retains an identity world-to-source clipping matrix and disappears under real translation: [source placement defect](FACTORY_SLEEP_RECORDING_HANDOFF_2026-10-20.md). Do not add a spell-name uniform repair or swap an unapproved default to hide it.
- Counterspell's incoming-path contract, unaccepted Aid/Bless/False Life/Sacred Flame art, native wielded-body refusal and baked-character attachment deferral are separate dispositions. None is fixed by marking a setter supplied.

## Execution order and completion gates

1. **Shared owner + history closure:** finish the current common ownership and generic history implementations. Apply them to all compatible selected phase Resources, with exact selector/UUID and original pre-cut semantics. Review these shared changes once, then batch their complete family/phase matrix; do not repeat one-off spell tuning.
2. **Factual operand cohorts:** extend the existing ordered application/world/item projections for the event/result, item and spatial subsets whose exact public operands are present. Bind every compatible typed cue in that batch. For each unsupported branch, retain one precise missing public field or incompatible source requirement, not a generic `provider_not_bound` label or invented default. Propagation uses its existing graph seam.
3. **Whole selected inventory gate:** regenerate the derived audit from installed index + typed Resources. Every selected input has an implementation/contract disposition, exact applicable source branch and evidence state. Studio shows all missing constructor/setter/lifecycle lanes and the real cause; it does not turn a recording, copied source or handover declaration into green presentation coverage.
4. **Batch qualification:** original independent journals and immutable ordered negatives first; native constructor/setter/sample + actual framebuffer contribution in genuine published views next; application/hold/removal, overlap/item/view changes and seek/loop/teardown for every compatible shared consumer. Keep requested/supplied/inapplicable/missing separate. Check actual rendered phase coverage across the matrix, not one successful example per family.
5. **Live readiness/performance:** measure original live-issued move/door/attack/multi-target cast and surprise condition application with cold/short queue and warm residency. Preserve source/worker/main/GPU/publish/first-visible leaf timings, memory bounds and event order. A static provider audit, high average FPS or a hidden birth sample proves none of this. Continue to report named source/backend blockers without claiming the full suite or final performance complete.

This closes capability dependencies before calibration. No new runtime registry, speculative outcome, validation/hash loop, presentation hold or whole-catalog warmup is required by this checklist.
