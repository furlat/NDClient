extends RefCounted
# Native selection over borrowed, response-local compact domains.
const Choices = preload("res://sdk/choices.gd")

static func actions(choices: Dictionary) -> Array:
    return Choices.all_actions(choices)

static func owns_action(choices: Dictionary, row: Dictionary) -> bool:
    # Gesture-time ownership: optional actor metadata cannot identify the response
    # that supplied a row. Do not search/expand its potentially large target set.
    for family in Choices.FAMILIES:
        for current in choices.get(family,[]):
            if is_same(current,row): return true
    return false

static func selection(row: Dictionary, indices: Array, safe: bool = true) -> Dictionary:
    return {"action_index":row.get("discovery_index",0),"target_indices":indices.duplicate(),"extra_target_positions":[],"prefer_safe":safe}

static func world_options(choices: Dictionary, identity: String) -> Array:
    var result: Array = choices.get("world_interactions",[]).filter(func(option):return option.subject_uuid == identity)
    result.sort_custom(func(a,b):return a.get("default_priority",100) < b.get("default_priority",100))
    return result

static func same_content_ref(a: Variant, b: Variant) -> bool:
    if a == null or b == null: return a == null and b == null
    # Preserve the entire admitted identity; only numeric representation differs
    # between native-JSON query metadata and canonical/authored content values.
    for field in ["pack_id","definition_kind","content_id","content_version","definition_contract_hash"]:
        if a[field] != b[field]: return false
    return true

static func same_option(a: Dictionary,b: Dictionary) -> bool:
    for field in ["subject_uuid","behavior_id","template_name","connector_uuid","variant_facets"]:
        var fallback: Variant = [] if field == "variant_facets" else null
        if a.get(field,fallback) != b.get(field,fallback): return false
    return same_content_ref(a.get("configured_action_ref"),b.get("configured_action_ref"))

static func admitted(choices: Dictionary, option: Dictionary) -> Array:
    var result: Array = []
    for row in actions(choices):
        var affordance: Dictionary = row.get("interaction_affordance",{})
        if affordance.get("surface","action_bar") != "world" or row.behavior_id != option.behavior_id: continue
        if option.get("template_name") != null and row.template_name != option.template_name: continue
        if not same_content_ref(row.get("configured_action_ref"),option.get("configured_action_ref")) or row.get("variant_facets",[]) != option.get("variant_facets",[]): continue
        if not row.can_afford: continue
        for target in Choices.action_options(choices,row):
            if option.get("connector_uuid") != null:
                var connector: Variant = row.get("connector_traversal")
                if connector == null or connector.command.connector_uuid != option.connector_uuid: continue
            elif affordance.get("binding","target") == "source_item":
                if row.get("source_item_uuid") != option.subject_uuid: continue
            else:
                var subject: Variant = Choices.binding_subject(choices,target)
                if subject == null or subject.uuid != option.subject_uuid: continue
            result.append({"action":row,"target":target,"selection":selection(row,[target.index])})
    return result

static func approach(choices: Dictionary, option: Dictionary) -> Dictionary:
    var best = {}
    var cost = INF
    for row in actions(choices):
        if row.behavior_id != "action.move" or not row.can_afford: continue
        if not row.get("variant_facets",[]).any(func(facet):return facet.key == "movement" and facet.value == "walking"): continue
        for target in Choices.action_options(choices,row):
            var position: Variant = Choices.binding_position(choices,target)
            if not option.get("contact_positions",[]).any(func(contact):return same_position(position,contact)): continue
            var safe_cost: Variant = Choices.binding_value(target,"safe_path_cost")
            var safe = safe_cost != null and float(safe_cost) <= float(choices.get("remaining_movement",0))
            if not safe and Choices.binding_value(target,"is_path_hazardous"): continue
            var distance: Variant = safe_cost if safe else Choices.binding_value(target,"path_cost")
            if distance != null and float(distance) < cost:
                cost = distance
                best = {"action":row,"target":target,"selection":selection(row,[target.index])}
    return best

static func same_position(a: Variant, b: Variant) -> bool:
    # Native JSON stores coordinate numbers as floats; picking uses integers.
    # Compare admitted coordinate values without rewriting the shared domains.
    return a != null and b != null and a.size() == 2 and b.size() == 2 and a[0] == b[0] and a[1] == b[1]

static func target(domains: Dictionary, pool: Array, position: Array, identity: String = "") -> Dictionary:
    if not identity.is_empty():
        for candidate in pool:
            var subject: Variant = Choices.binding_subject(domains,candidate)
            if subject != null and subject.uuid == identity: return candidate
    for candidate in pool:
        if Choices.binding_subject(domains,candidate) == null and same_position(Choices.binding_position(domains,candidate),position): return candidate
    return {}

static func main_attack(choices: Dictionary, identity: String, preference: String) -> Dictionary:
    for row in actions(choices):
        if not row.get("performs_attack",false) or row.get("weapon_slot") != preference or not row.can_afford: continue
        if row.get("costs",[]).any(func(cost):return cost.cost_type in ["bonus_actions","reactions"]): continue
        var hit = target(choices,Choices.action_options(choices,row),[],identity)
        if not hit.is_empty(): return {"action":row,"target":hit,"selection":selection(row,[hit.index])}
    return {}

static func extend_selection(choices: Dictionary, action: Dictionary, prefix: Dictionary,
        preview: Dictionary, position: Array, identity: String = "", safe: bool = true) -> Dictionary:
    # Only the current prefix's native continuation can authorize an append.
    # A computed empty continuation must never fall back to initial eligibility.
    var selected = prefix.duplicate(true)
    selected.prefer_safe = safe
    if Choices.preview_positions(preview).any(func(point):return same_position(point,position)):
        selected.extra_target_positions.append(position.duplicate())
        return {"selection":selected,"position":position}
    var domains = choices if preview.is_empty() else preview
    var options = Choices.action_options(choices,action) if preview.is_empty() else Choices.next_options(preview)
    var candidate = target(domains,options,position,identity)
    if candidate.is_empty(): return {}
    selected.target_indices.append(candidate.index)
    return {"selection":selected,"target":candidate,"position":Choices.binding_position(domains,candidate)}

static func idle_intent(choices: Dictionary, state: Dictionary, hit: Dictionary,
        force_attack: bool, preference: String, mode: String, safe: bool = true) -> Dictionary:
    # Shared ordinary-click/hover policy. Every preview selection is an actual
    # admitted SDK choice, including a distant object's ordinary safe approach.
    if hit.is_empty(): return {}
    var id: String = hit.get("id","")
    if id.is_empty():
        if force_attack: return {}
        for row in actions(choices):
            if row.behavior_id != mode or not row.can_afford: continue
            var candidate = target(choices,Choices.action_options(choices,row),hit.get("position",[]))
            if not candidate.is_empty():
                return {"kind":"move","label":row.display_name,"value":{"action":row,"selection":selection(row,[candidate.index],safe)}}
        return {}
    if hit.get("kind")=="actor" or force_attack:
        var attack = main_attack(choices,id,preference)
        return {"kind":"attack","label":attack.action.display_name,"value":attack} if not attack.is_empty() else {}
    if state.get("objects",{}).get(id,{}).get("contained_items") != null:
        return {"kind":"storage","label":"Open storage","id":id}
    var options = world_options(choices,id)
    if options.is_empty(): return {}
    var defaults = options.filter(func(option):return option.get("default_priority",100)==options[0].get("default_priority",100))
    if defaults.size()!=1: return {"kind":"context","label":"Choose interaction"}
    var option: Dictionary = defaults[0]
    var direct = admitted(choices,option)
    if not direct.is_empty(): return {"kind":"interaction","label":option.label,"option":option,"value":direct[0] if direct.size()==1 else {}}
    var travel = approach(choices,option)
    if not travel.is_empty(): return {"kind":"approach","label":"Approach · "+str(option.label),"option":option,"value":travel}
    return {}
