"""Export Python reference results for Godot's public-player reducer.

Typed boundary examples exercise value reduction, not simulated gameplay. Real
numbered SDK recordings can be added with --packets; their bytes are cold decoded
by the current backend. Expected state is always computed by the production
Python reducer, never supplied by these examples. No backend files are changed.
"""
from pathlib import Path
import argparse
from collections import Counter
from dataclasses import replace
import json
import sys
from types import UnionType
from typing import Annotated, Union, get_args, get_origin
from uuid import UUID

BACKEND = Path(__file__).resolve().parents[2] / "dnd_engine"
sys.path.insert(0, str(BACKEND))

from pydantic import TypeAdapter
from pydantic_core import to_jsonable_python
from dnd.player import reduction
from dnd.player.audience import AudiencePerception, PlayerAudience, audience_view, observe_audience, resolve_audience
from dnd.player.facts import (
    PlayerActor, PlayerFact, PlayerInitialization, PlayerLineage, PlayerNode,
    PlayerObservation, PlayerSequence, PlayerUpdate, SensoryFact, WorldUpdate,
)
from dnd.types.senses import reduce_senses_snapshot
from server.protocol import InitializationResponse, PlayerOperation


def uid(number):
    return str(UUID(int=number))


def cold(owner, value):
    return TypeAdapter(owner).validate_json(json.dumps(value))


def fact_names(owner):
    if get_origin(owner) is Annotated:
        return fact_names(get_args(owner)[0])
    if get_origin(owner) in (UnionType, Union):
        return set().union(*(fact_names(member) for member in get_args(owner)))
    return {owner.__name__}


def senses_normalized(value):
    if value is None:
        return
    value["visible"] = sorted(value["visible"])
    value["seen"] = sorted(value["seen"])
    value["sense_modes_hash"] = json.dumps(sorted(
        (mode["sense_type"], mode["range_feet"]) for mode in value["sense_modes"]), separators=(",", ":"))


def normalized(value):
    result = to_jsonable_python(value)
    if isinstance(result, dict):
        if "senses" in result:
            senses_normalized(result["senses"])
        if "visible" in result and "sense_modes_hash" in result:
            senses_normalized(result)
        perception = result.get("perception", result if "members" in result else None)
        if perception is not None:
            for snapshot in perception["members"].values():
                senses_normalized(snapshot)
    return result


def index_result(lineage):
    value = reduction.index_player_lineage(lineage)
    def key(ref):
        return ref.kind + "," + str(ref.lineage_uuid) + (
            "," + str(ref.application_id) if ref.kind == "application" else "")
    return {"by_lineage": {str(k): normalized(v) for k, v in value.by_lineage.items()},
        "by_uuid": {str(k): normalized(v) for k, v in value.by_uuid.items()},
        "source_order": {str(k): v for k, v in value.source_order.items()},
        "owned": {key(k): normalized(v) for k, v in value.owned.items()},
        "results": {key(k): normalized(v) for k, v in value.results.items()},
        "damage_requests": {str(k): str(v) for k, v in value.damage_requests.items()}}


METHODS = {
    "reduce_initialization": lambda value, content: reduction.reduce_initialization(value, content_additions=content),
    "reduce_operation": reduction.reduce_operation,
    "reduce_lineage": reduction.reduce_lineage,
    "reduce_nodes": reduction.reduce_nodes,
    "stage_lineage": reduction.stage_lineage,
    "stage_actors": reduction.stage_actors,
    "observe_actors": reduction.observe_actors,
    "state_before_event": reduction.state_before_event,
    "lineage_branch": reduction.lineage_branch,
    "index_player_lineage": index_result,
    "audience_observe": observe_audience,
    "audience_view": audience_view,
    "reduce_senses": reduce_senses_snapshot,
    "resolve_audience": lambda observer, supplied: resolve_audience(UUID(observer), None if supplied is None else cold(PlayerAudience, supplied)),
}


class Oracle:
    def __init__(self):
        self.cases = []
        self.facts = Counter()

    def add(self, name, method, *arguments):
        before = [normalized(argument) for argument in arguments]
        try:
            value = METHODS[method](*arguments)
            expected = {"ok": True, "value": normalized(value)}
        except (ValueError, KeyError) as error:
            value = None
            expected = {"ok": False, "error_type": type(error).__name__, "message": str(error)}
        assert before == [normalized(argument) for argument in arguments], name + ": Python mutated input"
        self.cases.append({"name": name, "method": method, "arguments": before, "expected": expected})
        return value

    def group(self, group):
        nodes = group.nodes if isinstance(group, PlayerInitialization) else group.events
        for node in nodes:
            if node.fact is not None:
                self.facts[type(node.fact).__name__] += 1


GEN, OWNER, OTHER, ITEM, OBJECT, EFFECT = map(uid, (1, 2, 3, 4, 5, 6))


def sensory(observer=OWNER, initial=False, **changes):
    result = dict(kind="sensory", observer_uuid=observer, initial=initial,
        observer_position=[-2, 3], observer_position_changed=initial,
        effective_light_levels_changed={}, cause_event_uuid=None,
        visible_cells_added=[], visible_cells_removed=[], seen_cells_added=[],
        entity_contacts_changed={}, entity_contacts_removed=[], object_contacts_changed={},
        object_contacts_removed=[], sense_modes_changed=initial, sense_modes=[] if initial else None,
        passive_perception_changed=initial, passive_perception=11 if initial else None,
        visual_access_changed=initial, visual_access=1 if initial else None, paths_dirty=False)
    result.update(changes)
    return cold(SensoryFact, result)


def node(number, fact=None, **changes):
    result = dict(uuid=uid(number), lineage_uuid=uid(number + 10000), parent_event=None,
        parent_lineage=None, children_lineages=[], phase="completion", canceled=False,
        fact=normalized(fact))
    result.update(changes)
    return cold(PlayerNode, result)


def lineage(state, nodes, **changes):
    start = state.reducer_cursor
    result = dict(generation=str(state.generation), observer_uuid=str(state.observer_uuid),
        lineage_uuid=str(nodes[0].lineage_uuid), root=normalized(nodes[-1]), events=normalized(nodes),
        version_rows=[dict(source_index=start + i, event_uuid=str(n.uuid), lineage_uuid=str(n.lineage_uuid))
            for i, n in enumerate(nodes)], start_cursor=start, end_cursor=start + len(nodes),
        audience=normalized(state.audience))
    result.update(changes)
    return cold(PlayerLineage, result)


def effect(**changes):
    result = dict(content_ref=dict(pack_id="test.contract", definition_kind="spell", content_id="test.effect",
        content_version=1, definition_contract_hash="a" * 64), name="Observed effect", description="Typed boundary value",
        positions=[[-2, 3]], owner_revision=1, apparent_presence=True)
    result.update(changes)
    return result


def contract_cases(oracle):
    oracle.add("contract/default_audience", "resolve_audience", OWNER, None)
    for label, supplied in [
        ("observer_only_audience", dict(controlled=[], observers=[OWNER], revision=0)),
        ("duplicate_observer_rejected", dict(controlled=[OWNER], observers=[OWNER, OWNER], revision=0)),
        ("duplicate_control_rejected", dict(controlled=[OWNER, OWNER], observers=[OWNER], revision=0)),
        ("empty_observers_rejected", dict(controlled=[OWNER], observers=[], revision=0)),
        ("negative_revision_rejected", dict(controlled=[OWNER], observers=[OWNER], revision=-1)),
        ("stable_observer_missing_rejected", dict(controlled=[OWNER], observers=[OTHER], revision=0)),
    ]:
        oracle.add("contract/" + label, "resolve_audience", OWNER, supplied)
    item = dict(item_uuid=ITEM, item_id="test.item", name="Typed item", item_kind="weapon", rarity="common",
        weight=1, visual_item_name="Typed item", equipped_visual_policy="visible", stack_count=2,
        max_stack=3, is_consumable=True, charges=2)
    layer = dict(slot="weapon_melee_main", item_uuid=ITEM, item_id="test.item", item_kind="weapon",
        visual_item_name="Typed item", visual_variant_id=None, equipped_visual_policy="visible")
    actor = cold(PlayerActor, dict(uuid=OWNER, name="Observed owner", character_body_id=None, creature_content_ref=None,
        appearance={}, visual_loadout=dict(active_weapon_set="melee", layers=[layer]), normal_hp=20, maximum_hp=25,
        temporary_hp=5, life_state="alive", armor_class=14, controlled_items=[item],
        last_visual_position=[-2, 3], temporary_hp_grant=dict(instance_uuid=uid(50)), faction="party"))
    other = replace(actor, uuid=UUID(OTHER), name="Observed other", controlled_items=None)
    tile = dict(tile_uuid=uid(20), position=[-2, 3], surface=dict(base_material="stone"), name="Support",
        blocks_optics=False, blocks_propagation=False, walking_cost=5, flying_cost=5, swimming_cost=0,
        burrowing_cost=0, elevation_steps=2, surface_kind="stairs", slope_axis="east_west", default_light=3, resolved_light=3)
    placement = dict(object_uuid=OBJECT, tile_uuid=uid(20), position=[-2, 3], kind="center", occupies_bands=True,
        base_height_steps=2, top_height_steps=4)
    floor_item = dict(item_uuid=OBJECT, item_id="test.object", name="Observed object", visual_item_name="Observed object",
        visual_variant_id=None, map_char="x", boundary_structure=None, is_open=None, is_lit=None, current_hit_points=8)
    connector = dict(connector_uuid=uid(21), authored_id="connector.test", kind="ladder", presentation_key="test.ladder",
        endpoints=[[-2, 3], [-1, 3]], support_tile_uuids=[uid(20), uid(22)], endpoint_elevations_feet=[10, 20],
        movement_cost_feet=10, bidirectional=True, enabled=True, provocation_policy="provokes_source_exit")
    initial_sense = sensory(initial=True, visible_cells_added=[[-2, 3], [-1, 3]], seen_cells_added=[[-2, 3], [-1, 3]],
        effective_light_levels_changed={"-2,3": 2, "-1,3": 1}, entity_contacts_changed={OWNER: dict(position=[-2, 3], visual=True)},
        sense_modes=[dict(sense_type="Darkvision", range_feet=60)])
    initial_nodes = [node(100), node(101), node(102, initial_sense), node(103, sensory(OTHER, True))]
    initial = cold(PlayerInitialization, dict(generation=GEN, observer_uuid=OWNER,
        world=dict(battlefield_id="test.contract", battlefield_name="Reducer values", bounds=[-2, 3, 4, 7], width=7, height=5),
        nodes=normalized(initial_nodes), version_rows=[dict(source_index=i, event_uuid=str(n.uuid), lineage_uuid=str(n.lineage_uuid))
            for i, n in enumerate(initial_nodes)], end_cursor=4,
        observations=[dict(event_uuid=uid(100), actor=normalized(actor), contact=None), dict(event_uuid=uid(101), actor=normalized(other), contact=None)],
        world_updates=[dict(event_uuid=uid(100), tiles=[tile], objects=[dict(placement=placement, item=floor_item)], objects_removed=[], connectors=[connector])],
        audience=dict(controlled=[OWNER], observers=[OWNER, OTHER])))
    state = oracle.add("contract/complete_initialization", "reduce_initialization", initial, ())
    oracle.group(initial)
    assert state is not None
    condition = dict(event_uuid=None, condition_uuid=uid(40), name="Observed condition", category="condition", behavior_id=None,
        resulting_max_hp=30, resulting_ac=17)
    definitions = [
        dict(kind="faction", entity_uuid=OTHER, faction_after="changed"),
        dict(kind="attack", source_entity_uuid=OWNER, target_entity_uuid=OTHER, behavior_id=None, name=None,
            weapon_slot="RANGED_MAIN", attack_outcome=None, damage_types=[], source_item_id=None),
        dict(kind="damage", stage="taken", source_entity_uuid=OWNER, target_entity_uuid=OTHER),
        dict(kind="damage", stage="applied", source_entity_uuid=OWNER, target_entity_uuid=OTHER, applied_damage=3,
            resulting_normal_hp=18, resulting_temporary_hp=0, damage_type="Fire"),
        dict(kind="heal", source_entity_uuid=OWNER, target_entity_uuid=OTHER, actual_healing=4, was_blocked=False,
            resulting_normal_hp=24, resulting_temporary_hp=2),
        dict(kind="temporary_hit_points", entity_uuid=OTHER, resulting_temporary_hp=7, grant=dict(instance_uuid=uid(51))),
        dict(kind="life", entity_uuid=OTHER, previous_state="alive", new_state="dead", reason="damage", normal_hit_points=0, remains_disposition="disintegrated"),
        dict(kind="equipment", source_entity_uuid=OWNER, visual_loadout=dict(active_weapon_set="none", layers=[]), armor_class=9, controlled_items=[]),
        dict(kind="condition", target_entity_uuid=OTHER, event_type="condition_application", condition=condition),
        dict(kind="turn", event_type="turn_start", entity_uuid=OTHER, round_number=3),
        dict(kind="item_charge", source_entity_uuid=OWNER, item_uuid=ITEM, charges_after=1, stack_count_after=1, item_destroyed=False),
        dict(kind="spatial", change_type="entity_entered", entity_uuid=OWNER, position=[-1, 3], commit_event_uuid=uid(2100), occupancy_layer="air"),
        dict(kind="spell", source_entity_uuid=OWNER, target_entity_uuid=OTHER, behavior_id=None, name=None, source_position=None,
            declared_target_entity_uuids=[OTHER], application=None),
        dict(kind="area_reach", stage_index=1, newly_reached_positions=[[-1, 3]], previous_reach_lineage_uuid=None, prerequisite_destruction_lineages=[]),
        dict(kind="movement", source_entity_uuid=OWNER, trajectory="path", start_position=[-2, 3], end_position=[-1, 3]),
        dict(kind="step", source_entity_uuid=OWNER, from_position=[-2, 3], to_position=[-1, 3], from_elevation_feet=10,
            to_elevation_feet=15, disclosed_path=[[-2, 3], [-1, 3]], trajectory="path", provocation_policy="ordinary_exit", committed=True),
        dict(kind="forced_movement", source_entity_uuid=OWNER, target_entity_uuid=OTHER, start_position=[-2, 3], end_position=[-1, 3], actual_distance=5),
        dict(kind="portal_transfer", target_entity_uuid=OTHER, portal_uuid=None, start_position=[-2, 3], end_position=None, committed=False),
        dict(kind="shove", source_entity_uuid=OWNER, target_entity_uuid=OTHER, behavior_id=None, contest_success=True, push_distance=5, knocked_prone=False),
        dict(kind="saving_throw", target_entity_uuid=OTHER, ability_name="dexterity", succeeded=True, effect_id=None),
        dict(kind="death_save", entity_uuid=OTHER, natural_roll=10, succeeded=True),
        dict(kind="item_effect", item_uuid=ITEM, effect_uuid=uid(70), event_type="condition_application"),
        dict(kind="action", source_entity_uuid=OWNER, target_entity_uuid=None, behavior_id=None, name=None),
        dict(kind="spatial_effect_state", spatial_effect_uuid=EFFECT, positions=[[-2, 3]], previous_state="ready", state="activated"),
        dict(kind="mechanism_activation", mechanism_uuid=None, mechanism_content_id="test.mechanism", target_entity_uuid=OTHER,
            origin_position=[-2, 3], direction=[1, 0], affected_positions=[[-1, 3]], end_position=[-1, 3], committed=True),
        dict(kind="object_damage", object_uuid=OBJECT, applied_damage=2, resulting_hp=6, damage_type=None),
        dict(kind="object_destroyed", object_uuid=OBJECT, placement=placement, item_id="test.object"),
    ]
    variants = [
        ("natural_stance", {**definitions[1], "attack_source_kind": "natural"}),
        ("heal_blocked", {**definitions[4], "was_blocked": True, "resulting_normal_hp": None, "resulting_temporary_hp": None}),
        ("item_destroyed", {**definitions[10], "item_destroyed": True}),
        ("internal_condition", {**definitions[8], "condition": {**condition, "category": "internal"}}),
        ("condition_stats", {**definitions[8], "condition": {**condition, "resulting_stats": dict(normal_hp=7, maximum_hp=12,
            temporary_hp=0, armor_class=19, healing_blocked=False, damage_affinities=[], resolved_size="Large", spatial_disposition="present")}}),
        ("condition_removal", {**definitions[8], "event_type": "condition_removal"}),
        ("turn_end", {**definitions[9], "event_type": "turn_end"}),
        ("encounter_end", {**definitions[9], "event_type": "encounter_end"}),
        ("terminal_departure", {**definitions[11], "terminal_departure": True}),
        ("spatial_foreign_entry", {**definitions[11], "entity_uuid": OTHER}),
        ("temporary_hp_grant_cleared", {**definitions[5], "resulting_temporary_hp": 0, "grant": None}),
    ]
    all_facts = [(str(i) + "_" + row["kind"], row) for i, row in enumerate(definitions)] + variants
    for label, raw in all_facts:
        fact = cold(PlayerFact, raw)
        nodes = [node(2100, fact)]
        group = lineage(state, nodes)
        oracle.group(group)
        oracle.add("contract/fact/" + label, "reduce_lineage", state, group)
        if label == "8_condition":
            changed = reduction.reduce_lineage(state, group)
            removed = lineage(changed, [node(2200, cold(PlayerFact, variants[5][1]))])
            oracle.add("contract/remove_existing_condition", "reduce_lineage", changed, removed)
    # World after-values must apply even for a canceled presentation fact.
    update = dict(event_uuid=uid(2300), tiles=[{**tile, "elevation_steps": 4}], objects=[], objects_removed=[OBJECT], connectors=[])
    canceled = lineage(state, [node(2300, cold(PlayerFact, definitions[3]), canceled=True)], world_updates=[update])
    oracle.add("contract/canceled_world_after_values", "reduce_lineage", state, canceled)
    oracle.add("contract/stage_preserves_existing_geometry", "stage_lineage", state, canceled)
    # Nested commit ordering includes declaration versions without completed nodes.
    spatial = definitions[11]
    nested = lineage(state, [node(2401, cold(PlayerFact, {**spatial, "commit_event_uuid": uid(2401), "position": [0, 3]})),
        node(2402, cold(PlayerFact, {**spatial, "commit_event_uuid": uid(2400), "position": [-1, 3]}))],
        version_rows=[dict(source_index=4 + i, event_uuid=uid(2400 + i), lineage_uuid=uid(12400 + i)) for i in range(3)], end_cursor=7)
    oracle.add("contract/nested_commit_wins", "reduce_lineage", state, nested)
    terminal = reduction.reduce_lineage(state, lineage(state, [node(2100, cold(PlayerFact, variants[8][1]))]))
    observation = cold(PlayerObservation, dict(event_uuid=uid(2500), actor=normalized(actor), contact=dict(position=[1, 1], visual=True)))
    oracle.add("contract/terminal_observation_cannot_resurrect", "observe_actors", terminal, (observation,))
    oracle.add("contract/staging_does_not_overwrite_known_actor", "stage_actors", state, (replace(observation, actor=replace(actor, normal_hp=1)),))
    oracle.add("contract/reacquisition_replaces_live_actor", "observe_actors", state, (replace(observation, actor=replace(actor, normal_hp=1)),))
    missing = replace(observation, actor=replace(actor, uuid=UUID(uid(999))))
    oracle.add("contract/staging_introduces_absent_actor", "stage_actors", state, (missing,))
    tied = tuple(replace(observation, actor=replace(actor, normal_hp=hp)) for hp in range(24))
    tied_node = node(2500)
    tied_lineage = lineage(state, [tied_node])
    oracle.add("contract/equal_cursor_observations_keep_received_order", "reduce_nodes", state,
        (tied_node,), tied_lineage.version_rows, tied, ())
    # Causal helpers: damage ancestry, both reference kinds, hidden intermediate parent.
    root = node(3003, cold(PlayerFact, definitions[12]), children_lineages=[uid(13001)])
    request = node(3001, cold(PlayerFact, definitions[2]), parent_event=str(root.uuid), parent_lineage=str(root.lineage_uuid), children_lineages=[uid(13002)],
        resolution_ref=dict(kind="application", lineage_uuid=str(root.lineage_uuid), application_id=uid(90)))
    applied = node(3002, cold(PlayerFact, definitions[3]), parent_event=str(request.uuid), parent_lineage=str(request.lineage_uuid),
        resolution_ref=dict(kind="application", lineage_uuid=str(root.lineage_uuid), application_id=uid(90)))
    orphan = node(3004, cold(PlayerFact, definitions[25]), resolution_ref=dict(kind="event", lineage_uuid=str(root.lineage_uuid)))
    causal = lineage(state, [request, applied, orphan, root], root=normalized(root),
        version_rows=[dict(source_index=4 + i, event_uuid=uid(n), lineage_uuid=uid(l))
            for i, (n, l) in enumerate([(3000, 13003), (3001, 13001), (3002, 13002), (3004, 13004), (3003, 13003)])], end_cursor=9)
    oracle.add("contract/causal_index", "index_player_lineage", causal)
    oracle.add("contract/causal_branch_includes_disclosed_orphan", "lineage_branch", causal, root)
    oracle.add("contract/state_before_damage_descendant", "state_before_event", state, causal, applied)
    # Each independent audience edge uses genuine typed sensory after-values.
    perception = state.perception
    observations = [
        sensory(OWNER, spatial_effects_changed={EFFECT: effect(positions=[[-2, 3]])}),
        sensory(OTHER, visible_cells_added=[[-1, 3]], seen_cells_added=[[-1, 3]], effective_light_levels_changed={"-1,3": 3},
            hazardous_cells_changed={"-1,3": True}, entity_contacts_changed={OWNER: dict(position=[9, 9], visual=False)},
            spatial_effects_changed={EFFECT: effect(positions=[[-1, 3]], anchor_position=[-2, 3],
                suppressions=[dict(provider_uuid=uid(80), positions=[[-1, 3]])])}),
        sensory(OWNER, spatial_effects_changed={EFFECT: effect(positions=[[-2, 3]], suppressions=[dict(provider_uuid=uid(80), positions=[[-2, 3]])],
            upper_volume_surfaces=[dict(position=[1, 2], lower_height_planes=[[0, 0, 2]])])}),
        sensory(OTHER, visible_cells_added=[[-2, 3]], entity_contacts_changed={OWNER: dict(position=[8, 8], visual=True)},
            spatial_effects_changed={EFFECT: effect(positions=[[-1, 3]], owner_revision=2)}),
        sensory(OWNER, visible_cells_removed=[[-2, 3]], spatial_effects_removed=[EFFECT], entity_contacts_removed=[OWNER], paths_dirty=True),
        sensory(OTHER, initial=True, visible_cells_added=[[5, 5]], seen_cells_added=[[5, 5]], passive_perception=17),
    ]
    for i, event in enumerate(observations):
        perception = oracle.add("contract/audience_observe_%d" % i, "audience_observe", perception, state.audience, event, 20 + i)
        oracle.add("contract/audience_view_%d" % i, "audience_view", perception, state.observer_uuid)
        oracle.facts["SensoryFact"] += 1
    # Eventless content/HUD/log transactions and rejection leave old state intact.
    ref = effect()["content_ref"]
    descriptor = {"ref": ref, "display_name": "Admitted descriptor", "visibility": "observed"}
    hud = dict(generation=GEN, observer_uuid=OWNER, revision=4, initiative=[OWNER, OTHER], sheets=[])
    log = dict(generation=GEN, observer_uuid=OWNER, encounter_log_index=0, operation_end_cursor=4,
        entry=dict(entry_type="turn_start", source_name="Observed owner", source_uuid=OWNER,
            compact="Turn", verbose="Turn", detailed="Turn", data=dict(kind="turn", entity_name="Observed owner",
                entity_uuid=OWNER, round_number=1, turn_index=0)))
    operation = cold(PlayerUpdate, dict(audience=normalized(state.audience), lineages=[], hud=hud,
        combat_log_appends=[log], content_additions=[descriptor]))
    after = oracle.add("contract/eventless_operation", "reduce_operation", state, operation)
    oracle.add("contract/empty_operation", "reduce_operation", after, operation.model_copy(update={"hud": None, "combat_log_appends": (), "content_additions": ()}))
    oracle.add("contract/content_identity_conflict", "reduce_operation", after, operation.model_copy(update={
        "content_additions": (operation.content_additions[0].model_copy(update={"display_name": "Changed"}),)}))
    oracle.add("contract/log_duplicate_rejected", "reduce_operation", after, operation)
    oracle.add("contract/future_hud_rejected", "reduce_operation", state, operation.model_copy(update={"hud": replace(operation.hud, revision=5)}))
    oracle.add("contract/audience_change_rejected", "reduce_operation", state, operation.model_copy(update={"audience": replace(state.audience, revision=1)}))
    good = lineage(state, [node(3300, cold(PlayerFact, definitions[0]))])
    oracle.add("contract/operation_with_lineage", "reduce_operation", state, operation.model_copy(update={"lineages": (good,)}))
    oracle.add("contract/gap_rejected", "reduce_operation", state, operation.model_copy(update={"lineages": (replace(good, start_cursor=5),)}))
    oracle.add("contract/stale_lineage_rejected", "reduce_lineage", state, replace(good, end_cursor=4))
    oracle.add("contract/wrong_generation_rejected", "reduce_lineage", state, replace(good, generation=UUID(uid(99))))
    oracle.add("contract/missing_spatial_commit_rejected", "reduce_lineage", state, lineage(state, [node(3400, cold(PlayerFact, {**spatial, "commit_event_uuid": None}))]))
    oracle.add("contract/foreign_item_inventory_rejected", "reduce_lineage", state, lineage(state, [node(3401, cold(PlayerFact, {**definitions[10], "source_entity_uuid": OTHER}))]))
    oracle.add("contract/uninitialized_senses_rejected", "reduce_senses", UUID(OWNER), None, sensory())
    for label, event in [
        ("coordinate_strings_are_integer_keys", sensory(effective_light_levels_changed={" +02, -03 ": 4}, hazardous_cells_changed={"002,-03": True})),
        ("invalid_cell_key_rejected", sensory(effective_light_levels_changed={"1,2,3": 2})),
        ("invalid_light_level_rejected", sensory(effective_light_levels_changed={"1,2": 5})),
        ("initial_capabilities_required", sensory(initial=True, passive_perception=None)),
    ]:
        oracle.add("contract/senses/" + label, "reduce_senses", UUID(OWNER), state.senses, event)
    oracle.add("contract/foreign_senses_rejected", "audience_observe", state.perception, state.audience, sensory(uid(99), True), 50)
    audience_edge_cases(oracle, state.audience)
    return state


def audience_edge_cases(oracle, audience):
    """Independent typed evidence conflicts; Python decides every composed value."""
    base = effect(positions=[[-2, 3]])
    other = effect(positions=[[-1, 3]])
    pairs = [
        ("optional_anchor_conflict", {**base, "anchor_position": [-2, 3]}, {**other, "anchor_position": [-1, 3]}),
        ("semantic_field_conflict", base, {**other, "name": "Different recorded name"}),
        ("suppression_conflict", {**base, "suppressions": [dict(provider_uuid=uid(80), positions=[[-2, 3]], antimagic=True)]},
            {**other, "suppressions": [dict(provider_uuid=uid(80), positions=[[-1, 3]], antimagic=False)]}),
        ("unknown_revision_does_not_union", {**base, "owner_revision": None}, {**other, "owner_revision": None}),
        ("revision_precedes_cursor", {**base, "owner_revision": 2}, other),
        ("volume_only_permission", {**base, "positions": [], "visible_volume_positions": [[7, 7]]},
            {**other, "positions": [], "upper_volume_surfaces": [dict(position=[8, 8], lower_height_planes=[[1, 0, 3]])]}),
    ]
    for label, first, second in pairs:
        perception = AudiencePerception()
        for observer, seen, row, cursor in [(OWNER, [-2, 3], first, 30), (OTHER, [-1, 3], second, 31)]:
            event = sensory(observer, True, visible_cells_added=[seen], spatial_effects_changed={EFFECT: row})
            perception = oracle.add("contract/audience/" + label + "/" + observer,
                "audience_observe", perception, audience, event, cursor)
        oracle.add("contract/audience/" + label + "/view", "audience_view", perception, UUID(OWNER))
    for apparent in [False, True]:
        label = "apparent" if apparent else "concealed"
        perception = oracle.add("contract/audience/" + label + "/known", "audience_observe",
            AudiencePerception(), audience, sensory(OWNER, True, visible_cells_added=[[-2, 3]],
                spatial_effects_changed={EFFECT: effect(apparent_presence=apparent)}), 40)
        perception = oracle.add("contract/audience/" + label + "/first_empty_visit", "audience_observe",
            perception, audience, sensory(OTHER, True, visible_cells_added=[[-2, 3]]), 41)
        oracle.add("contract/audience/" + label + "/view_after_visit", "audience_view", perception, UUID(OWNER))
        perception = oracle.add("contract/audience/" + label + "/known_owner_removal", "audience_observe",
            perception, audience, sensory(OWNER, spatial_effects_removed=[EFFECT]), 42)
        oracle.add("contract/audience/" + label + "/view_after_removal", "audience_view", perception, UUID(OWNER))
        perception = oracle.add("contract/audience/" + label + "/older_presence", "audience_observe",
            perception, audience, sensory(OWNER, spatial_effects_changed={EFFECT: effect(apparent_presence=apparent)}), 39)
        oracle.add("contract/audience/" + label + "/newer_absence_retained", "audience_view", perception, UUID(OWNER))
    perception = AudiencePerception()
    for observer, position, hazard in [(OTHER, [8, 8], True), (OWNER, [9, 9], False)]:
        event = sensory(observer, True, visible_cells_added=[[-2, 3]], effective_light_levels_changed={"-2,3": 2},
            hazardous_cells_changed={"-2,3": hazard}, entity_contacts_changed={OWNER: dict(position=position, visual=True)},
            object_contacts_changed={OBJECT: dict(position=position, visual=True)})
        perception = oracle.add("contract/audience/uuid_tie/" + observer, "audience_observe", perception, audience, event, 50)
    oracle.add("contract/audience/uuid_tie/view", "audience_view", perception, UUID(OWNER))
    oracle.add("contract/audience/missing_stable_member_uses_first", "audience_view", perception, UUID(uid(999)))
    oracle.add("contract/audience/empty_view", "audience_view", AudiencePerception(), UUID(OWNER))


def first_difference(expected, actual, path="$"):
    if isinstance(expected, dict) and isinstance(actual, dict):
        for key in expected:
            if key not in actual:
                return path + "." + key + " missing"
            difference = first_difference(expected[key], actual[key], path + "." + key)
            if difference:
                return difference
        for key in actual:
            if key not in expected:
                return path + "." + key + " unexpected"
        return None
    if isinstance(expected, list) and isinstance(actual, list):
        if len(expected) != len(actual):
            return f"{path} lengths differ: Python {len(expected)}, Godot {len(actual)}"
        for i, (left, right) in enumerate(zip(expected, actual)):
            difference = first_difference(left, right, f"{path}[{i}]")
            if difference:
                return difference
        return None
    return None if expected == actual else f"{path}: Python {expected!r}, Godot {actual!r}"


def recorded_cases(oracle, directory, states=None):
    paths = sorted((path for path in directory.glob("*.json") if path.stem.isdecimal()), key=lambda path: int(path.stem))
    if not paths:
        raise ValueError("No numbered SDK records in " + str(directory))
    if [int(path.stem) for path in paths] != list(range(len(paths))):
        raise ValueError("SDK records must be contiguous from initialization index zero: " + str(directory))
    state = None
    for path in paths:
        raw = path.read_bytes()
        prefix = "recorded/" + directory.parent.name + "/" + directory.name + "/" + path.stem
        if state is None:
            packet = InitializationResponse.model_validate_json(raw)
            state = oracle.add(prefix, "reduce_initialization", packet.initialization, packet.content_additions)
            oracle.group(packet.initialization)
        else:
            packet = PlayerOperation.model_validate_json(raw)
            for i, group in enumerate(packet.lineages):
                oracle.group(group)
                oracle.add(prefix + "/index_%d" % i, "index_player_lineage", group)
            state = oracle.add(prefix, "reduce_operation", state, packet)
        if state is None:
            raise ValueError(str(path) + ": Python reference rejected recorded packet")
        if states is not None:
            actual_path = states / path.name
            if not actual_path.is_file():
                raise ValueError("Missing Godot prefix state: " + str(actual_path))
            actual = normalized(json.loads(actual_path.read_bytes()))
            difference = first_difference(normalized(state), actual)
            if difference:
                raise AssertionError(prefix + ": " + difference)
    return len(paths)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=Path(__file__).resolve().parents[1] / ".runtime/sdk-study/reducer-oracle.json")
    parser.add_argument("--packets", "--journal", type=Path, action="append", default=[])
    parser.add_argument("--states", type=Path, action="append", default=[], help="Optional matching Godot states directory for each --journal")
    args = parser.parse_args()
    oracle = Oracle()
    contract_cases(oracle)
    if args.states and len(args.states) != len(args.packets):
        parser.error("Supply one --states directory per --journal, or omit all --states")
    records = sum(recorded_cases(oracle, directory, args.states[i] if args.states else None) for i, directory in enumerate(args.packets))
    missing = fact_names(PlayerFact) - oracle.facts.keys()
    if missing:
        raise AssertionError("Public fact classes missing reducer boundary coverage: " + repr(sorted(missing)))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps({"scope": "Typed reducer boundary cases plus explicitly supplied real SDK recordings; expected values from current cold Python reduction",
        "normalization": "Only visible/seen set order and process-local sense_modes_hash", "recorded_packets": records,
        "fact_classes": dict(sorted(oracle.facts.items())), "cases": oracle.cases}, separators=(",", ":")))
    print(json.dumps({"cases": len(oracle.cases), "recorded_packets": records, "fact_classes": len(oracle.facts), "output": str(args.output)}))


if __name__ == "__main__":
    main()
