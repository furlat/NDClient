extends RefCounted
## Exact disclosed spatial owners. No cast-name matching, area generation,
## future visibility, synthetic condition member or inferred retirement.

static func content_id(effect:Dictionary)->String:
    return str(effect.get("content_ref",{}).get("content_id",""))

static func admitted_cells(effect:Dictionary)->Array:
    var suppressed:Dictionary={}
    for suppression in effect.get("suppressions",[]):
        for position in suppression.get("positions",[]):suppressed[Vector2i(position[0],position[1])]=true
    return effect.get("positions",[]).filter(func(position):return not suppressed.has(Vector2i(position[0],position[1])))

## A native change is a mechanical observation of this exact spatial owner.
## Sensory membership changes alone are not interaction or retirement events.
static func observed_rows(node:Dictionary)->Array:
    var fact:Variant=node.get("fact")
    if node.get("canceled",false) or fact==null or fact.get("kind")!="spatial_effect_state":return []
    return [{"spatial_effect_uuid":str(fact.spatial_effect_uuid),"event_uuid":str(node.id),
        "lineage_uuid":str(node.lineage_id),"operation":fact.get("operation"),
        "interaction_operation":fact.get("interaction_operation"),
        "positions":fact.get("positions",[]),"removed_positions":fact.get("removed_positions",[]),
        "previous_state":fact.get("previous_state"),"state":fact.get("state"),
        "previous_pressed":fact.get("previous_pressed"),"pressed":fact.get("pressed")}]

## The source keeps its original constructed cells. Only a recorded permanent
## removal supplies a cell's private source age; sight loss and suppression do
## not manufacture entries in this list.
static func removal(owner:Dictionary,row:Dictionary)->Dictionary:
    var anchor:Variant=owner.source_effect.get("anchor_position")
    if anchor==null:anchor=owner.source_effect.positions[0]
    return {"cells":row.removed_positions.map(func(position):return [position[0]-anchor[0],position[1]-anchor[1]]),
        "source_seconds":maxf(0.0,float(row.at_ms)-float(owner.start_ms))/1000.0,
        "at_ms":row.at_ms,
        "event_uuid":row.event_uuid,"lineage_uuid":row.lineage_uuid,
        "operation":row.operation,"interaction_operation":row.interaction_operation}

## Only recorded retired cells may outlive current sensory membership, for
## the source's authored removal interval. Unseen cells gain no such lease.
static func presentation_cells(owner:Dictionary,at_ms:float,retention_ms:float)->Array:
    var result:Array=admitted_cells(owner.effect).duplicate() if owner.get("observed",true) else []
    for row in owner.get("spatial_observations",[]):
        if at_ms<float(row.at_ms) or at_ms>=float(row.at_ms)+retention_ms:continue
        for position in row.removed_positions:
            if position not in result:result.append(position)
    return result

## Neutral constructor operands clear only the supplied review topology and
## retirement. Actual membership is supplied through its declared setters;
## unchanged material, mask, noise and artistic birth settings remain sealed.
static func construction(identity:String,effect:Dictionary,cue:Dictionary,source_effect:Dictionary={},observed_removals:Array=[])->Dictionary:
    var descriptor:Dictionary=cue.get("constructor_input",{})
    if descriptor.get("kind")!="spatial_owner":
        return {"ready":false,"reason":"spatial_constructor_not_bound"}
    if str(descriptor.get("content_id",""))!=content_id(effect):
        return {"ready":false,"reason":"spatial_source_content_not_bound"}
    var capacity:int=int(cue.get("cell_capacity",0))
    var positions:Array=admitted_cells(effect)
    if capacity>0 and positions.size()>capacity:
        return {"ready":false,"reason":"spatial_source_cell_capacity_exceeded"}
    if descriptor.get("cell_input")=="cells":
        # This source constructs its native vegetation once from disclosed
        # topology. Visibility and temporary suppression remain AreaMask's
        # reversible admission; neither is evidence of permanent burning.
        var original:Array=source_effect.positions
        if positions.any(func(position):return position not in original):
            return {"ready":false,"reason":"spatial_source_topology_extension_not_bound"}
        var anchor:Variant=source_effect.get("anchor_position")
        if anchor==null:anchor=original[0]
        var local:Array=original.map(func(position):return [position[0]-anchor[0],position[1]-anchor[1]])
        return {"ready":true,"reason":"","operands":[{"component_path":descriptor.component_path,
            "input_field":descriptor.input_field,"values":{"cells":local,"observed_removals":[]}}],
            "source_anchor":anchor,"source_elevation_steps":source_effect.get("anchor_elevation_steps"),
            "source_cells":original,"observed_removals":observed_removals,
            "evidence":{"spatial_effect_uuid":identity,"content_id":content_id(effect),
                "observed_cell_count":positions.size(),"constructed_cells":original,"observed_removals":observed_removals}}
    return {"ready":true,"reason":"","operands":[{"component_path":descriptor.component_path,
        "input_field":descriptor.input_field,"values":{"surface_admitted":false,"admitted_cells":[],"retire_at_seconds":INF}}],
        "evidence":{"spatial_effect_uuid":identity,"content_id":content_id(effect),"observed_cell_count":positions.size()}}

static func presence(component:Dictionary,state:Dictionary)->Dictionary:
    if not component.get("spatial_owner",false) or str(component.get("spatial_effect_uuid","")).is_empty():
        return {"ready":false,"reason":"surface_spatial_owner_not_bound"}
    var effects:Dictionary=state.get("senses",{}).get("spatial_effects",{}) if state.get("senses")!=null else {}
    var identity:String=str(component.spatial_effect_uuid)
    if not effects.has(identity):return {"ready":true,"value":false,"reason":""}
    var effect:Dictionary=effects[identity]
    if content_id(effect)!=str(component.get("spatial_content_id","")):
        return {"ready":false,"reason":"surface_spatial_content_not_bound"}
    return {"ready":true,"value":not admitted_cells(effect).is_empty(),"reason":""}
