extends RefCounted
# Native selection over borrowed, response-local compact domains.
const Choices = preload("res://sdk/choices.gd")
const Cells = preload("res://sdk/fold_cells.gd")

static func actions(choices: Dictionary) -> Array:
    return Choices.all_actions(choices)

static func owns_action(choices: Dictionary, row: Dictionary) -> bool:
    # Gesture-time ownership: optional actor metadata cannot identify the response
    # that supplied a row. Do not search/expand its potentially large target set.
    var native:Dictionary=row.get("_native_action",row)
    for family in Choices.FAMILIES:
        for current in choices.get(family,[]):
            if is_same(current,native): return true
    return false

static func selection(row: Dictionary, indices: Array, safe: bool = true) -> Dictionary:
    var result={"action_index":row.get("discovery_index",0),"target_indices":indices.duplicate(),"extra_target_positions":[],"prefer_safe":safe}
    if row.get("cast_at_level")!=null:result.cast_at_level=int(row.cast_at_level)
    return result

static func level_rows(row:Dictionary)->Array:
    # UI-only, bounded metadata views. Large shared target domains stay borrowed.
    var levels:Array=row.get("cast_levels",[])
    if levels.is_empty():return [row]
    var result:Array=[]
    for level in levels:
        var view:Dictionary=row.duplicate();view._native_action=row.get("_native_action",row);view.cast_at_level=int(level);result.append(view)
    return result

static func region_origin(choices:Dictionary,row:Dictionary,state:Dictionary)->Variant:
    if row.get("range_origin")!=null:return row.range_origin
    return state.get("actors",{}).get(choices.get("entity_uuid"),{}).get("last_visual_position")

static func region_allows(choices:Dictionary,row:Dictionary,position:Array,state:Dictionary={})->bool:
    var region:Variant=row.get("position_region")
    if region==null or position.size()!=2:return false
    var origin:Variant=region_origin(choices,row,state)
    if origin==null:return true # Preview resolves an undisclosed origin; never guess another actor.
    var dx=int(position[0]-origin[0]);var dy=int(position[1]-origin[1])
    if region.get("exclude_source_position",true) and dx==0 and dy==0:return false
    if region.get("range_feet")!=null and floor(sqrt(float(dx*dx+dy*dy)))*5>float(region.range_feet):return false
    if region.get("requires_axis_or_diagonal_alignment",false) and dx!=0 and dy!=0 and absi(dx)!=absi(dy):return false
    # Seat cells are composed, not a member's visibility/occupancy proof. The
    # exact visible/reachable/walkable/unoccupied checks belong to real Preview.
    return true

static func region_positions(choices:Dictionary,row:Dictionary,state:Dictionary)->Array:
    var result:Array=[];var senses:Variant=state.get("senses")
    if senses==null or row.get("position_region")==null:return result
    for position in Cells.mask_points(senses.visible):
        if region_allows(choices,row,position,state):result.append(position)
    return result

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
    return true

static func admitted(choices: Dictionary, option: Dictionary) -> Array:
    var result: Array = []
    for row in actions(choices):
        var affordance: Dictionary = row.get("interaction_affordance",{})
        if affordance.get("surface","action_bar") != "world" or row.behavior_id != option.behavior_id: continue
        if option.get("template_name") != null and row.template_name != option.template_name: continue
        if row.get("variant_facets",[]) != option.get("variant_facets",[]): continue
        if not row.can_afford: continue
        if row.get("position_region")!=null and affordance.get("binding","target")=="source_item" and row.get("source_item_uuid")==option.subject_uuid and row.get("availability_status")=="available":
            result.append({"action":row,"target":{},"selection":selection(row,[]),"needs_aim":true});continue
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

static func subject_targets(choices:Dictionary,action:Dictionary,preview:Dictionary={},kind:String="")->Dictionary:
    if action.is_empty():return {}
    var domains:Dictionary=choices if preview.is_empty() else preview
    var pool:Array=Choices.action_options(choices,action) if preview.is_empty() else Choices.next_options(preview)
    var result:Dictionary={}
    for candidate in pool:
        var subject:Variant=Choices.binding_subject(domains,candidate)
        if subject!=null and (kind.is_empty() or subject.kind==kind):result[subject.uuid]=candidate
    return result

static func object_targeting(choices:Dictionary,action:Dictionary,preview:Dictionary={})->bool:
    # Retain target mode after a completed prefix so an inventory click cannot
    # silently become Equip/Use while confirmation is outstanding.
    return not subject_targets(choices,action,preview,"object").is_empty() \
        or not subject_targets(choices,action,{},"object").is_empty()

static func hit_subject_kind(hit:Dictionary)->String:
    if hit.has("subject_kind"):return str(hit.subject_kind)
    if str(hit.get("id","")).is_empty():return ""
    return "creature" if hit.get("kind")=="actor" else "object"

static func target(domains: Dictionary, pool: Array, position: Array, identity: String = "",subject_kind:String="") -> Dictionary:
    if not identity.is_empty():
        for candidate in pool:
            var subject: Variant = Choices.binding_subject(domains,candidate)
            if subject != null and subject.uuid == identity and (subject_kind.is_empty() or subject.kind==subject_kind): return candidate
    for candidate in pool:
        if Choices.binding_subject(domains,candidate) == null and same_position(Choices.binding_position(domains,candidate),position): return candidate
    # Clicking a disclosed subject's ground contact is the same selection only
    # when this exact response offers one unambiguous binding there.
    if identity.is_empty():
        var at_cell:Dictionary={}
        for candidate in pool:
            if Choices.binding_subject(domains,candidate)==null or not same_position(Choices.binding_position(domains,candidate),position):continue
            if not at_cell.is_empty() and at_cell!=candidate:return {}
            at_cell=candidate
        return at_cell
    return {}

static func main_attack(choices: Dictionary, identity: String, preference: String) -> Dictionary:
    for row in actions(choices):
        if not row.get("performs_attack",false) or row.get("weapon_slot") != preference or not row.can_afford: continue
        if row.get("costs",[]).any(func(cost):return cost.cost_type in ["bonus_actions","reactions"]): continue
        var hit = target(choices,Choices.action_options(choices,row),[],identity)
        if not hit.is_empty(): return {"action":row,"target":hit,"selection":selection(row,[hit.index])}
    return {}

static func extend_selection(choices: Dictionary, action: Dictionary, prefix: Dictionary,
        preview: Dictionary, position: Array, identity: String = "", safe: bool = true, state: Dictionary = {},subject_kind:String="") -> Dictionary:
    # Only the current prefix's native continuation can authorize an append.
    # A computed empty continuation must never fall back to initial eligibility.
    var selected = prefix.duplicate(true)
    selected.prefer_safe = safe
    var domains = choices if preview.is_empty() else preview
    var options = Choices.action_options(choices,action) if preview.is_empty() else Choices.next_options(preview)
    var candidate = target(domains,options,position,identity,subject_kind)
    var subject:Variant=Choices.binding_subject(domains,candidate) if not candidate.is_empty() else null
    var body_selected:bool=not identity.is_empty() and subject!=null and subject.uuid==identity
    if not body_selected and Choices.preview_positions(preview).any(func(point):return same_position(point,position)):
        selected.extra_target_positions.append(position.duplicate())
        return {"selection":selected,"position":position}
    if candidate.is_empty():
        # Only the first aim uses discovery's region. A subsequent vertex must
        # be admitted by this exact prefix's Preview continuation, even empty.
        if prefix.get("target_indices",[]).is_empty() and prefix.get("extra_target_positions",[]).is_empty() and region_allows(choices,action,position,state):
            selected.extra_target_positions.append(position.duplicate())
            return {"selection":selected,"position":position}
        return {}
    selected.target_indices.append(candidate.index)
    return {"selection":selected,"target":candidate,"position":Choices.binding_position(domains,candidate)}

static func selection_complete(preview:Dictionary)->bool:
    # Upcast rows can retain their base projectile count. Only the current
    # server continuation proves that every selectable target has been chosen.
    return preview.get("can_confirm",false) and Choices.next_options(preview).is_empty() and Choices.preview_positions(preview).is_empty()

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
    var object:Dictionary=state.get("objects",{}).get(id,{})
    if object.get("contained_items") != null and object.get("item",{}).get("is_open")!=false:
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
