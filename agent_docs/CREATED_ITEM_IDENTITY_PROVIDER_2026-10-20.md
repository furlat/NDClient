# Created-item identity and condition-event input boundary

20 October 2026. Shared-provider implementation against installed Factory `runtime-e102c29dec58524b` and frozen engine `211b71134ed15c89e62232587381f7e15a5961c3`. No Factory/engine edits, new native weapon body, invented gameplay outcome or recording was introduced.

## Completed producer contract; native qualification separate

`PresentationCondition.creation_source_id` and `creation_item_id` export `persistent.creationIdentity`. They describe the real source behavior and ordinary created item kind; they do not contain a fixture UUID or enable native-body substitution. Metadata-only condition descriptors are emitted even when visual disposition is blank.

`CreationInputs.lifetime_bindings(events, graph, commits)` joins an actual condition admission with a unique **descendant inventory admission under that same completed, uncanceled source lineage**, requiring its actual ItemRecord, before/after controlled holdings, holder and exact item kind. Ambiguous lifetimes/items and missing ancestry remain explicit. Canonical facts are untouched.

The compiler attaches `creation_bindings` to the later actual admission commit. `Conditions.observe` retains it only on that exact existing, unended condition UUID; adding metadata invalidates resources once, unchanged metadata does not. Ordinary samples forward `creation_binding`. Timeline and Recording pass this optional metadata at their existing publication/owner-history boundaries. No new clock or owner registry is added.

`CreationInputs.lifetime_packet` separately checks current exact lifetime membership and the existing resolved item/holder binding. Its packets are:

```text
identity: {created_item_uuid, lifetime_condition_uuid, caster_uuid}
weapon: {lifetime_condition_uuid, caster_uuid,
         lifetime_present: true, item_in_caster_holdings: true}
```

The source's `created_item_identity` setter receives the first packet; existing `weapon_binding` receives the second packet's fields only while actual optical admission is valid. Invalid/removed ownership must clear retained source admission. The six sources that require `created_item_binding` and render a native wielded body remain disallowed.

## Exact independent original evidence

Unchanged durable corpus: `tests/fixtures/schema16/created-flame-blade/{amber,blue}/0000000000000008.json`.

| Actual operand | Amber | Blue |
|---|---|---|
| Source cast | occurrence 51, lineage 41 | occurrence 50, lineage 41 |
| Lifetime admission | occurrence 48, parent 43 | occurrence 48, parent 43 |
| Condition UUID | `6d9deee5-15e6-48bb-9ab2-4f6ccec060e8` | same actual public UUID |
| Created item UUID | `d581a8b1-8878-4765-ae96-0d882c6310fc` | same actual visible item UUID |
| Caster UUID | `885464ab-168d-486f-8b85-09689c3b4d3b` | same actual public actor UUID |
| Inventory admission | occurrence 49, parent 43, actual ItemRecord and controlled holdings transition | not disclosed |
| Equipped layer admission | occurrence 50 | occurrence 49, **unparented**, no cast resolution |
| Creation identity result | positive at inventory commit, before later equip publication | `creation_item_ancestry_not_disclosed` |

Blue's actual visible equipment is not a creation ancestry proof. The client does not borrow Amber's inventory, equate seat occurrence numbers, parse the Flame Blade display name or invent an item→lifetime link from a same-packet coincidence. The missing Blue proof remains an exact public/source-ownership limitation, not a failed decoder.

The focused gate `tests/created_item_identity_checks.gd` uses original journals and a private `Build.documents` cache. It checks exact UUID/lineage/commit provenance, typed export, existing owner forwarding, packet immutability and negative consumed-value controls for cancellation, incomplete sources, missing before-values, foreign item/holder, missing optical admission and lifetime retirement. Counterfactual policy controls are not recorded game outcomes. Native framebuffer output, approved art and all-family completeness are not claimed by this headless gate.

Headless receipt: `.runtime/tests/20261020T072753.949763Z/created_item_identity_checks.log` — **155 checks, zero failures, zero script/engine errors, zero owned leftovers**, 2.1 seconds. This uses the existing runner with an unregistered headless row and no shared source rebuild. Native output remains unqualified.

The metadata-only recipe path omits forced legacy composition defaults: a neutral descriptor must not force `maxLayers=0` or an empty exclusive group and thereby suppress its existing native lifecycle. Authored recipes retain their previous composition output.

## Why no speculative condition-event projector was added

All 21 event-gated selections / 63 lifecycle phases use `assets/vfx/conditions/runtime.gd::set_event_binding/set_event_state`. Exact source/public requirements differ:

| Family | Concrete required public/source operands missing now |
|---|---|
| Tenacity committed miss | `AttackFact` has outcome but no `range_type`; `MyrmidonTenacity.miss` emits damage with only `parent_event=attack.uuid`, no `source_condition_uuid`; a descendant Bludgeoning result therefore does not establish `tenacity_damage_observed` or the exact condition. The source additionally requires an authored `damage_contact` pixel region and matching revision; EntitySurface does not currently publish that receiving-region contract. |
| 13 draconic readiness variants | Public condition lacks `breath_type`, `issued`, `free_action_uuid`, `granted_lineage`. Discovering an action or observing a completed breath does not reconstruct the current allowance and its cancellation/consumption. Source also requires actual mouth-region/revision. |
| 4 elemental multiattack variants | Public `prerequisite` selector and exact bonus packet attribution are absent. A target condition plus any Multiattack damage does not prove `qualified_bonus_observed`. |
| 3 Myrmidon strike variants | Public configured action/element selectors and exact contributed damage-packet attribution are absent. Matching action name or damage type is insufficient for `strike_dice_observed`. |

Frozen source evidence:

- `dnd/player/facts.py::AttackFact` and `DamageResultFact` define the actual disclosed fields; `dnd/player/projection.py` preserves condition attribution only if the native event supplies it.
- `dnd/monsters/spell_summon_actions.py::MyrmidonTenacity._apply` returns `None` from its miss handler after emitting damage, with no source condition argument.
- `dnd/core/events.py::EventQueue._run_handler` publishes `EffectiveHandlerPresentation` only when the handler returns a non-null result and its kind is Reaction/ClassFeature. These condition handlers therefore do not acquire that missing proof merely because a shared handler join exists.
- `DraconicBreathCadence` stores the readiness fields privately; `ElementalMultiattackBonus` and `MyrmidonStrikeDice` append private bonus packets. Exact literal selector gaps and original owner witnesses are in [the producer handout](CONDITION_SELECTOR_PRODUCER_GAPS_2026-10-20.md).

Current durable/library originals contain no actual `condition.summon.tenacity` member; catalog references to its content ID do not count as a positive scenario. No fake event packet, active flag, owner attribution, mouth/contact region or 21-condition switch was added. The work moved to the directly supported shared creation-identity seam instead of implementing a projector that only reports unavailable.

## Native qualification

`.runtime/tests/20261020T074618.643445Z/native_created_item_identity_checks.log`: 48 checks, zero failures/script/engine errors or owned leftovers, 6.0 seconds. Original Amber creation proof plus exact current weapon sprite produces native decoration in all four views. Original Blue remains explicitly unavailable because its visible equip is unparented. The test samples the genuine post-cast idle hold and waits for the declared asynchronous optical source; cast frames correctly hide the weapon and do not prove a held coating. No original rows were changed, future game outcome generated or native weapon body enabled. Real lifetime-removal/output and live readiness remain separate from these originals.
