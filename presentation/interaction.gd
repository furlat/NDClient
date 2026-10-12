extends RefCounted
# Port of Pygame's world_interaction.py: references and native pools, no paths.

static func actions(choices: Dictionary) -> Array:
    var result: Array = []
    for family in ["entity_actions","position_actions","self_actions","object_actions"]:
        result.append_array(choices.get(family,[]))
    return result

static func selection(row: Dictionary, indices: Array, safe: bool = true) -> Dictionary:
    return {"action_index":row.discovery_index,"target_indices":indices.duplicate(),"extra_target_positions":[],"prefer_safe":safe}

static func world_options(choices: Dictionary, identity: String) -> Array:
    var result: Array = choices.get("world_interactions",[]).filter(func(option):return option.subject_uuid == identity)
    result.sort_custom(func(a,b):return a.default_priority < b.default_priority)
    return result

static func same_option(a: Dictionary,b: Dictionary) -> bool:
    for field in ["subject_uuid","behavior_id","template_name","connector_uuid","configured_action_ref","variant_facets"]:
        if a.get(field) != b.get(field): return false
    return true

static func admitted(choices: Dictionary, option: Dictionary) -> Array:
    var result: Array = []
    for row in actions(choices):
        var affordance: Dictionary = row.interaction_affordance
        if affordance.surface != "world" or row.behavior_id != option.behavior_id: continue
        if option.get("template_name") != null and row.template_name != option.template_name: continue
        if row.get("configured_action_ref") != option.get("configured_action_ref") or row.variant_facets != option.variant_facets: continue
        if not row.can_afford: continue
        for target in row.valid_targets:
            if option.get("connector_uuid") != null:
                var connector: Variant = row.get("connector_traversal")
                if connector == null or connector.command.connector_uuid != option.connector_uuid: continue
            elif affordance.binding == "source_item":
                if row.get("source_item_uuid") != option.subject_uuid: continue
            elif target.get("target_uuid") != option.subject_uuid: continue
            result.append({"action":row,"target":target,"selection":selection(row,[target.index])})
    return result

static func approach(choices: Dictionary, option: Dictionary) -> Dictionary:
    var best = {}
    var cost = INF
    for row in actions(choices):
        if row.behavior_id != "action.move" or not row.can_afford: continue
        if not row.variant_facets.any(func(facet):return facet.key == "movement" and facet.value == "walking"): continue
        for target in row.valid_targets:
            if not target.get("position") in option.contact_positions: continue
            var safe_cost: Variant = target.get("safe_path_cost")
            var safe = safe_cost != null and float(safe_cost) <= float(choices.remaining_movement)
            if not safe and target.get("is_path_hazardous",false): continue
            var distance: Variant = safe_cost if safe else target.get("path_cost")
            if distance != null and float(distance) < cost:
                cost = distance
                best = {"action":row,"target":target,"selection":selection(row,[target.index])}
    return best

static func target(pool: Array, position: Array, identity: String = "") -> Dictionary:
    if not identity.is_empty():
        for candidate in pool:
            if candidate.get("target_uuid") == identity: return candidate
    for candidate in pool:
        if candidate.get("target_uuid") == null and candidate.get("position") == position: return candidate
    return {}

static func main_attack(choices: Dictionary, identity: String, preference: String) -> Dictionary:
    for row in actions(choices):
        if not row.get("performs_attack",false) or row.get("weapon_slot") != preference or not row.can_afford: continue
        if row.costs.any(func(cost):return cost.cost_type in ["bonus_actions","reactions"]): continue
        var hit = target(row.valid_targets,[],identity)
        if not hit.is_empty(): return {"action":row,"target":hit,"selection":selection(row,[hit.index])}
    return {}
