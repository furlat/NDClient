# Studio native row ownership — 20 October 2026

Main checkout only, `codex-authoring-schemabump`. This is an inspection migration
against the current schema16 SDK and existing renderer, not a new reducer,
effect scheduler, UI redesign or runtime validation pass.

## Delivered spatial inspection correction

`Recording._spatial_rows` admitted only legacy spell handovers or Factory
condition lifecycles. The five newly typed Orb surfaces use a third, authored
held-source arm in `NativePersistent.spatial_samples`; their actual source drew
but Studio omitted its owner and source tracks.

Studio now admits the same three source arms, includes authored removal clocks
in both the inspection endpoint and owner spans, and uses its existing
`NativePersistent.spatial_samples`/native-channel path. Source clock, spatial
UUID, cells and original causing commit stay authoritative. Successful native
phases may omit a `status` override; the private inspection component follows
the renderer's existing default unless the source is explicitly missing.

- `tests/studio_spatial_owner_checks.gd`: **48 checks, zero failures, script or
  engine errors**, clean exit and owned cleanup.
- Receipt: `.runtime/tests/20261020T003508.713198Z/`.
- Both original `chromatic-orb/{amber,blue}` journals independently qualify:
  authored-only source selection, one UUID lifetime/source, exact admission
  prefixes, source-field/clock provenance, survival past review expiry,
  canonical seek/loop and immutable recorded cuts.
- The first attempt at `20261020T003408.280986Z` exposed the formerly unreachable
  direct `sample.status` access; that failure is retained.
- Command: `python3 tools/run_tests.py --only studio_spatial_owner_checks --jobs 1`.

This is headless inspection/source qualification. Existing Acid native pixel
evidence remains separate; other materials, real removal/suppression variants
and human visual approval are not promoted by this test. No build or GPU run
was performed for this change.

## Canonical row inspection delivered

`Requirements` now projects the canonical ActorChange container and every
actual ordered row. `EventTrace` retains actor/row ordinals, occurrence and
condition/item/effect identities privately until the real commit. Enabled
equipment bodies must match the exact changed actor; condition component
identities now use the actual cue actor rather than the container's absent
source actor. Existing Studio body/condition/item/light rows supply inspection
links, without new visual tracks or draw witnesses for ordinary accounting.

Dynamic item effects, resolved size, unknown fields and unsupported item-state
keys remain explicit missing/unassessed requirements. Nonempty ItemRecord
effects also remain visible, without treating metadata ingress as a holder or
equipped appearance. The original Arm packet8/occurrence236 actually discloses
`item.property.additional_damage`; its source/visual policy stays unassessed.
This does not change the failed Magic Weapon/Sacred Weapon recordings, which
did not disclose such membership.

The obsolete sensory dictionary path is removed. Indexed sensory values are
still reduced only by the SDK, and the existing offline histories inspect
their exact immutable commit after-values. No replacement sensory effects or
new fold were added.

- New `actor_row_requirement_checks`:817 checks. Current fifteen field
  definitions, disjoint/repeated metadata controls, duration/item-effect
  identities, precommit privacy and original independent Hide, overlapping
  conditions, Gallery, Orb and actual party equipment journals.
- Combined affected headless batch: **1,486 checks, zero failures, script or
  engine errors or leftover processes**. Existing requirements577,
  owner-order44 and spatial Studio48 stay green.
- Receipt: `.runtime/tests/20261020T004436.648756Z/`.
- Final817-check row gate after correcting the ItemRecord schema pointer:
  `.runtime/tests/20261020T004608.000748Z/`, also clean.
- Command: `python3 tools/run_tests.py --only actor_row_requirement_checks,presentation_requirements_checks,studio_spatial_owner_checks,schema16_owner_order_checks --jobs 1`.

Source-index metadata refresh and native/live trace qualification remain the
parent's next gates. This cohort did not rebuild sources or run GPU tests.
Duration and unknown-field metadata controls are not claims of new recorded
gameplay or completed dynamic item-effect rendering.

## Classification problem addressed

`Requirements.FACT_OWNERS` still names retired standalone `condition`,
`equipment` and `item_effect` facts, while canonical `actor_change` has no
classified owner. `Requirements.occurrence` therefore adds one generic
unassessed fact demand to every native ActorChange. `EventTrace` then adds real
condition/equipment components independently, and `Recording._missing_rows`
correctly displays the unresolved generic demand. This is a stale expectation,
not evidence that every such body/condition/light operation is absent.

There are also real inspection/provider gaps; making the entire container
state-only would conceal them. Static source inventory and occurrence coverage
must share the new row policy, while rendered/audible evidence stays independent.

## Approved row ownership policy

Keep `actor_change` as the canonical ordered container. Classify its actual
`actors[].rows[]` fields, preserving actor index, row index, actor UUID, actual
instance/item identity and original occurrence. Repeated fields and transient
remove/reapply must retain distinct row identities. An ItemRecord refresh is
metadata, not evidence of possession or creation.

| Canonical fields | Existing consumer / requirement | Assessment to preserve |
| --- | --- | --- |
| `layer`, `active_weapon_set` | `Compiler._schedule` equipment-change body and commit; `Characters` layer selection; ordinary world preparation; intrinsic item-effect eligibility. | Require the authored equipment body only when enabled and visually applicable. Link the exact actor's body/commit and actual old/new loadout. Final gear sprites alone do not prove finite transition inspection. |
| `condition` | SDK `condition_rows` before/after capture; compiler condition cues; `Conditions` UUID lifetime; Studio condition/material/pose/appearance/native spans. | Delegate each actual application/update/removal to its same actor/condition UUID. Keep each missing authored operation from ConditionCoverage; a working marker cannot cover a missing material/pose. Preserve captured pose and ordered remove/reapply clocks. |
| `condition_duration` | Existing held member update in `fold_bodies`, reconciled by `Conditions.observe` and offline history. | Update/inspect the same owner, without a second application VFX or restarted source clock. Actual field inspection is separate from rendered native output. |
| `inventory` | Controlled-seat inventory; `NativeItems.locations` and intrinsic item eligibility; actual creation-admission descriptor when present. | Ordinary holdings accounting has no automatic body/VFX. Link only exact disclosed item/holder changes; neither cached ItemRecord nor an unrelated creation accent qualifies membership. |
| `item_effects` | Actual item-owned `effect_uuid`, `behavior_id`, optional contribution and applied-source identity already exist in schema16. Legacy `item_attachments` and native weapon inputs are separate consumers. | Keep per-effect source/owner inspection and missing provider work explicit. `NativeItems` currently samples intrinsic `Gear.effects`; it does not implement arbitrary dynamic ItemEffectsRow membership. Do not label this public data unavailable or infer passive/rider attribution. |
| `item_effect_duration` | SDK updates the exact item/effect duration. | Delegate to that actual effect owner; no fabricated apply/remove event or source clock restart. Preserve any genuinely absent dynamic item-effect inspection. |
| `item_state` | Exact current item changes and normal inventory/equipment/world consumers. Native light inspection consumes independently disclosed optical sources. | Expand actual changed keys. An `is_lit` row does not by itself authorize a guessed light/source position; link an optical track only through the real commit and disclosed anchor/source identity. Other state keys remain explicit accounting or unassessed where no consumer is known. |
| `normal_hp`, `maximum_hp`, `temporary_hp`, `temporary_hp_grant`, `armor_class` | Canonical actor/HUD state; actual Damage/Heal/Life facts own their finite body and feedback. | Explicit per-field state/accounting inspection, no duplicate TakeDamage/death/heal effect. A state commit is not a body/framebuffer witness. |
| `spatial_disposition` | `World.visible_actor`, `Characters.resolve`, Play visibility, light/audio eligibility. | Inspect actual present/absent publication and existing owner suppression. Do not claim Banishment departure/echo art or return animation merely because hiding works. |
| `resolved_size` | SDK stores it; current sprite dimensions read authored `appearance.visual_scale`, not this field directly. | Leave the visual-size mapping unassessed; distinguish mechanical resolved size from the separately authored condition body-scale operation. Do not silently call it rendered or invent a new scaling rule. |

Unknown future fields remain explicit per-row unassessed requirements. The schema
mapping supplies the inventory denominator; implementation classification is a
finite source-owned policy, never guessed from whichever components were emitted.

## Spatial, sensory and item distinctions

- `EventTrace._requirements` still reads retired `sensory.spatial_effects_changed`.
  Schema16 uses indexed sensory rows, already resolved once by the SDK into each
  immutable commit's canonical after-values. Join to that exact cut and existing
  spatial/light histories; do not decode sensory tables or fold them again.
- `SpatialFact` is a change envelope, not uniformly nonvisual. Actual object
  placement/removal/appearance belongs to world publication; entity entry/exit
  to disclosed actor/contact ownership; light changes to canonical optical
  membership; tile changes to world/environment state. `movement_collision`
  needs its own explicit policy. Preserve actual movement/destruction/mechanism
  child owners rather than inventing duplicate tracks at each envelope.
- `SpatialEffectStateFact` is witnessed mechanical fixture state. A persistent
  field source is not proof that an authored trap activation/contact/projectile
  sequence is implemented. Keep these requirements separate.
- `ItemChargeFact` remains explicit item accounting unless its actual removal
  changes a displayed owner. ItemRecord media availability cannot certify that
  owner's current existence, slot or contribution.

## Implementation boundaries and remaining gates

1. **Requirements and trace:** add the canonical container/row policy in
   `presentation/requirements.gd`; pass current compiler captures/cues into
   `presentation/event_trace.gd` and attach exact actor/row/owner identities.
   Use actual compiled track/owner references as inspection links, without
   copying actor/world snapshots into the bounded live trace. Do not manufacture
   `catalog/actor_change_context.json` or a standalone recipe per envelope.
2. **Offline inspection:** extend `studio/recording.gd` to resolve those links
   against its existing commit, condition, item and light histories. Keep
   unsupported rows and unbound operations missing; do not hide generic warnings
   until each actual field has a declared classification. `capability_report.gd`
   should count delegated requirements once under their real owner, without
   treating delegation as a draw witness. `source_inventory.gd` remains a
   consumer of that same policy, not another classification table.
3. **Static inventory:** update the existing `Requirements.facts`/authoring-audit
   projection to enumerate current ActorRows fields. Rebuild the existing native
   index's `fact_requirements` via `tools/presentation_build/abilities.gd` when
   the source policy changes; do not leave prepared Resources carrying the old
   generic ActorChange demand. Retired standalone fact kinds must not drive
   canonical schema16 expectations.
4. **Focused proof:** extend `presentation_requirements_checks` for all fifteen
   canonical fields plus unknown-row negative controls; use original equipment,
   Hide/reveal, captured-pose, overlapping condition, torch and Orb journals for
   exact ownership. Preserve current requirement/material/condition tests, and
   add explicit dynamic item-effect gaps instead of certifying them from an
   intrinsic sibling. Test two actors in one envelope, repeated fields,
   same-clock remove/reapply, state-only accounting, missing authored body,
   canceled/undisclosed rows, independent factions, seek/loop and immutable cuts.

**Required stage review:** the existing parent reviewer checks anti-slop
(no blanket green, filtered-away gap or source-presence/render conflation) and
anti-OOP/plan adherence (one passive requirement projection, no new reducer,
manager, scheduler, registry or runtime validation). Source-index refresh and
native regression follow that review. A reduction in warning count alone is
not the exit criterion.
