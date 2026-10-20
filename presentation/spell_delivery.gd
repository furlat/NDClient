extends RefCounted
const Occurrences=preload("res://presentation/occurrences.gd")
## Select a visual delivery from a real spell occurrence. Geometry and recipient
## counts come from facts; the catalog only selects which source roles display.
const Authoring=preload("res://presentation/authoring.gd")
const PropagationInputs=preload("res://presentation/propagation_inputs.gd")

static func ancestor(node:Dictionary,graph:Dictionary)->Dictionary:
    var parent:Variant=node.get("parent_lineage")
    while parent!=null and graph.nodes.has(parent):
        var candidate:Dictionary=graph.nodes[parent]
        if candidate.get("fact")!=null and candidate.fact.kind=="spell":return candidate
        parent=candidate.get("parent_lineage")
    return {}

static func cast_key(node:Dictionary,_graph:Dictionary)->String:
    var resolution:Dictionary=node.get("resolution_record",{})
    return str(resolution.lineage) if resolution.get("lineage")!=null else node.lineage_id

static func selected_for(selected:Dictionary,fact:Dictionary)->Dictionary:
    var result=selected.duplicate()
    var delivery:Dictionary=selected.get("delivery",{})
    var effect:Dictionary=delivery.get("effects",{}).get(str(fact.get("effect_id","")),{})
    result.delivery=effect if not effect.is_empty() else delivery
    var roles:Array=result.delivery.get("roles",[])
    if not roles.is_empty():
        result.staging=selected.staging.duplicate()
        result.staging.cues=selected.staging.cues.filter(func(cue):return cue.role in roles)
    return result

static func owns_delivery(node:Dictionary,_graph:Dictionary,selection:Dictionary,has_applications:bool)->bool:
    if not Occurrences.application(node) and selection.get("staging",{}).get("cues",[]).any(func(cue):return cue.get("scope")=="cast"):return true
    return _inherited_delivery(node,selection,has_applications)

static func _inherited_delivery(node:Dictionary,selection:Dictionary,has_applications:bool)->bool:
    var scope:String=selection.get("delivery",{}).get("scope","application")
    if scope=="area":return not Occurrences.application(node)
    return Occurrences.application(node) or not has_applications

static func for_occurrence(selection:Dictionary,node:Dictionary,has_applications:bool)->Dictionary:
    var cues:Array=selection.staging.cues
    if not cues.any(func(cue):return not str(cue.get("scope","")).is_empty()):return selection
    var application:bool=Occurrences.application(node)
    var inherited:bool=_inherited_delivery(node,selection,has_applications)
    var result:Dictionary=selection.duplicate()
    result.staging=selection.staging.duplicate()
    result.staging.cues=cues.filter(func(cue):return application if cue.get("scope")=="application" else not application if cue.get("scope")=="cast" else inherited)
    # Explicit recipient scope uses the real recipient, while the carrier's
    # area piece keeps the disclosed area origin and footprint.
    if application:
        result.delivery=selection.get("delivery",{}).duplicate()
        result.delivery.scope="application"
    return result

static func aim_position(fact:Dictionary,graph:Dictionary)->Variant:
    var geometry:Dictionary=fact.get("area_geometry",{}) if fact.get("area_geometry")!=null else {}
    var origin:Variant=fact.get("source_position")
    if origin==null:origin=graph.positions.get(fact.source_entity_uuid)
    if origin!=null and geometry.get("direction")!=null:return [origin[0]+geometry.direction[0],origin[1]+geometry.direction[1]]
    var target:Variant=fact.get("target_position")
    if target==null:target=graph.positions.get(fact.get("target_entity_uuid"))
    return fact.get("aoe_position") if target==null else target

static func endpoints(fact:Dictionary,graph:Dictionary,state:Dictionary,selection:Dictionary)->Dictionary:
    var source:Variant=fact.get("source_position")
    if source==null:source=graph.positions.get(fact.source_entity_uuid)
    var target:Variant=fact.get("target_position")
    var geometry:Dictionary=fact.get("area_geometry",{}) if fact.get("area_geometry")!=null else {}
    if selection.get("delivery",{}).get("scope")=="area" and fact.get("aoe_position")!=null:target=fact.aoe_position
    if target==null:target=graph.positions.get(fact.get("target_entity_uuid"))
    if target==null and fact.get("aoe_position")!=null:target=fact.aoe_position
    # A self spell has no separate recipient. Do not invent a target for a
    # projectile whose real recipient is outside the disclosed view.
    var needs_target:bool=selection.staging.cues.any(func(cue):return cue.role in ["flight","impact","strike"] or cue.get("attachment","").begins_with("recipient"))
    if target==null and not needs_target:target=source
    if target==null and fact.get("target_entity_uuid")==fact.source_entity_uuid:target=source
    if source==null or target==null:return {}
    var source_height:float=graph.contacts.get(fact.source_entity_uuid,{}).get("from_elevation_feet",0)
    var target_height:float=graph.contacts.get(fact.get("target_entity_uuid"),{}).get("from_elevation_feet",source_height)
    if fact.get("target_base_height_steps")!=null:target_height=float(fact.target_base_height_steps)*5.0
    elif fact.get("aoe_position")!=null:
        target_height=float(state.tiles.get("%d,%d"%target,{}).get("elevation_steps",source_height/5.0))*5.0
    var result:Dictionary={"from_position":source,"to_position":target,"from_elevation_feet":source_height,"to_elevation_feet":target_height,
        "area_geometry":geometry,"aim_position":aim_position(fact,graph),"resolved_area_positions":fact.get("resolved_area_positions"),"ground_target":fact.get("target_entity_uuid")==null or selection.get("delivery",{}).get("scope")=="area",
        "target_kind":fact.get("target_kind","creature")}
    if not PropagationInputs.descriptor(selection).is_empty():
        result.propagation=fact.get("propagation",{})
        if result.propagation!=null and not result.propagation.is_empty():
            result.from_position=result.propagation.source.position
            result.to_position=result.propagation.target.position
            result.from_elevation_feet=float(result.propagation.source.base_height_steps)*5.0
            result.to_elevation_feet=float(result.propagation.target.base_height_steps)*5.0
    return result

static func travel_ms(selected:Dictionary,recipe:Dictionary,points:Dictionary,cache:Dictionary)->float:
    var propagation:Dictionary=PropagationInputs.descriptor(selected)
    if not propagation.is_empty():return PropagationInputs.travel_ms(points.get("propagation",{}),propagation)
    if not selected.staging.cues.any(func(cue):return cue.role=="flight"):return 0.0
    var config:Dictionary=recipe.get("projectile",{}) if recipe.get("projectile")!=null else {}
    var distance=Vector2(points.from_position[0]-points.to_position[0],points.from_position[1]-points.to_position[1]).length()*float(Authoring.load_data("catalog/rig.json",cache).TILE_W)
    return maxf(config.get("minimumTravelDurationMs",150),distance/maxf(1,config.get("speedPxPerSecond",800))*1000)
