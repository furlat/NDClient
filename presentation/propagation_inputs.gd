extends RefCounted
## Directed optical links from disclosed native applications. No recipient
## search, inferred jumps, damage attribution or particle-density fabrication.
const Occurrences=preload("res://presentation/occurrences.gd")
const Placement=preload("res://placement.gd")

static func descriptor(selected:Dictionary)->Dictionary:
    for cue in selected.get("staging",{}).get("cues",[]):
        var value:Dictionary=cue.get("constructor_input",{})
        if value.get("kind")=="propagation_links":return value
    return {}

static func travel_ms(link:Dictionary,binding:Dictionary)->float:
    if link.is_empty():return 0.0
    var a:Dictionary=link.source;var b:Dictionary=link.target
    var delta:=Vector3(float(b.position[0])-float(a.position[0]),
        (float(b.base_height_steps)-float(a.base_height_steps))*Placement.HEIGHT_UNIT,float(b.position[1])-float(a.position[1]))
    return maxf(float(binding.minimum_travel_seconds),delta.length()/float(binding.speed_tiles_per_second))*1000.0

static func project(node:Dictionary,binding:Dictionary,graph:Dictionary)->Dictionary:
    if node.get("canceled",false):return {"ready":false,"reason":"propagation_application_canceled"}
    if not Occurrences.application(node):return {"ready":false,"reason":"propagation_application_not_disclosed"}
    var resolution:Dictionary=node.resolution_record
    var cast:Dictionary=graph.get("nodes",{}).get(str(resolution.lineage),{})
    if cast.is_empty() or cast.get("canceled",false) or cast.get("fact")==null or cast.fact.get("kind")!="spell":
        return {"ready":false,"reason":"propagation_cast_not_disclosed"}
    var link:Dictionary=node.fact.get("propagation",{}) if node.fact.get("propagation")!=null else {}
    if link.is_empty():return {"ready":false,"reason":"propagation_link_not_disclosed"}
    if str(link.application_id)!=str(resolution.application_id):return {"ready":false,"reason":"propagation_application_identity_mismatch"}
    if link.source.kind!="creature" or link.target.kind!="creature":return {"ready":false,"reason":"propagation_non_actor_endpoint_not_bound"}
    if str(link.target.uuid)!=str(node.fact.target_entity_uuid):
        return {"ready":false,"reason":"propagation_endpoint_identity_mismatch"}
    var index:int=int(graph.get("application_indices",{}).get(str(resolution.application_id),-1))
    if index<0:return {"ready":false,"reason":"propagation_membership_not_disclosed"}
    var primary:bool=index==0
    var predecessor:Dictionary={}
    if primary:
        if str(link.source.uuid)!=str(cast.fact.source_entity_uuid):return {"ready":false,"reason":"propagation_endpoint_identity_mismatch"}
    else:
        # Native membership, exact retained source/target contacts and the same
        # cast resolution prove the predecessor. No nearest-actor graph or
        # flattening of seat-local occurrence indices supplies this relation.
        var matches:Array=graph.nodes.values().filter(func(candidate):return not candidate.get("canceled",false) \
            and candidate.get("fact")!=null and candidate.fact.kind=="spell" and candidate.fact.get("propagation")!=null \
            and Occurrences.application(candidate) and str(candidate.resolution_record.lineage)==str(resolution.lineage) \
            and int(graph.get("application_indices",{}).get(str(candidate.resolution_record.application_id),-1))==0 \
            and candidate.fact.propagation.target==link.source)
        if matches.size()!=1:return {"ready":false,"reason":"propagation_predecessor_not_disclosed"}
        predecessor=matches[0]
    var launch:float=float(binding.source_launch)
    return {"ready":true,"reason":"","primary":primary,"predecessor":predecessor,
        "values":{"edges":[{"from":0,"to":1,"delay":launch}],"endpoint_count":2,"charge_coil":primary},
        "link":link,"inputs":{"link_edges":[{"from":0,"to":1,"delay":launch}]},
        "evidence":{"cast_occurrence":str(cast.id),"cast_lineage":str(resolution.lineage),
            "application_occurrence":str(node.id),"application_lineage":str(node.lineage_id),"application_id":str(link.application_id),
            "source_uuid":str(link.source.uuid),"target_uuid":str(link.target.uuid),"rule_caster_uuid":str(cast.fact.source_entity_uuid),
            "predecessor_application_id":str(predecessor.get("resolution_record",{}).get("application_id","")),
            "predecessor_occurrence":str(predecessor.get("id","")),"endpoint_source":"native_application_propagation"}}

## Native geometry uses painted sockets, not grid centres. Its exact arrival
## is mapped onto the already scheduled compiler contact by the existing
## source clock. Neither a shared cue nor the native program is retimed.
static func optical_contact(component:Dictionary,rows:Array,transform:Transform3D)->float:
    var binding:Dictionary=component.native_cue.get("constructor_input",{})
    var inverse:Transform3D=transform.affine_inverse()
    var a:Vector3=inverse*rows[0].point;var b:Vector3=inverse*rows[1].point
    return float(binding.source_launch)+maxf(float(binding.minimum_travel_seconds),a.distance_to(b)/float(binding.speed_tiles_per_second))

## An optical area source draws its disclosed declaration, independently of
## gameplay recipient membership. Edges/timing remain authored source data.
static func area_project(node:Dictionary,binding:Dictionary)->Dictionary:
    var fact:Variant=node.get("fact")
    if node.get("canceled",false) or node.get("phase")!="completion" or fact==null or fact.get("kind")!="spell" \
        or fact.get("source_entity_uuid")==null or Occurrences.application(node):
        return {"ready":false,"reason":"electric_area_cast_not_observed"}
    var geometry:Dictionary=fact.get("area_geometry",{}) if fact.get("area_geometry")!=null else {}
    if geometry.get("shape")!=binding.get("area_shape") or fact.get("resolved_area_positions")==null:
        return {"ready":false,"reason":"electric_area_geometry_not_disclosed"}
    if geometry.shape=="line" and (geometry.get("origin")==null or geometry.get("direction")==null \
        or Vector2(geometry.direction[0],geometry.direction[1]).is_zero_approx() or float(geometry.get("length_feet",0.0))<=0.0):
        return {"ready":false,"reason":"electric_declared_line_not_disclosed"}
    if geometry.shape=="sphere" and (geometry.get("center")==null or fact.get("aoe_position")!=geometry.center):
        return {"ready":false,"reason":"electric_declared_center_not_disclosed"}
    var edges:Array=binding.edges.duplicate(true)
    return {"ready":true,"reason":"","values":{"edges":edges,"endpoint_count":2,"contact_schedule":[],
        "charge_coil":bool(binding.charge_coil)},"inputs":{"link_edges":edges},
        "evidence":{"cast_occurrence":str(node.id),"cast_lineage":str(node.lineage_id),
            "source_uuid":str(fact.source_entity_uuid),"area_geometry":geometry.duplicate(true),
            "resolved_area_positions":fact.resolved_area_positions,"endpoint_source":"native_declared_area_geometry"}}

## Coordinate conversion for explicitly authored optical area endpoints. The
## public line already supplies its extent; this never solves occupied cells.
static func area_endpoint(component:Dictionary,authored:Dictionary,points:Dictionary)->Dictionary:
    var geometry:Dictionary=component.get("area_geometry",{})
    var point:Vector3
    if authored.get("area_point")=="line_end" and geometry.get("shape")=="line" \
        and geometry.get("origin")!=null and geometry.get("direction")!=null:
        var direction:=Vector2(geometry.direction[0],geometry.direction[1])
        if direction.is_zero_approx() or float(geometry.get("length_feet",0.0))<=0.0:
            return {"ready":false,"reason":"electric_declared_line_not_disclosed"}
        var end:=Vector2(geometry.origin[0],geometry.origin[1])+direction.normalized()*float(geometry.length_feet)/5.0
        point=Vector3(end.x,points.hand.y,end.y)
    elif authored.get("area_point") in ["segment_start","segment_end"] and geometry.get("shape")=="wall_assembly" \
        and geometry.get("path",{}).get("form")=="segment" and geometry.path.get("start")!=null and geometry.path.get("end")!=null:
        var position:Array=geometry.path.start if authored.area_point=="segment_start" else geometry.path.end
        point=Vector3(position[0],points.ground.y,position[1])
    elif authored.get("area_point")=="center" and geometry.get("shape")=="sphere" and geometry.get("center")!=null:
        point=Vector3(geometry.center[0],points.ground.y,geometry.center[1])
    else:return {"ready":false,"reason":"authored_area_endpoint_not_disclosed"}
    var offset:Array=authored.get("offset_cells",[0.0,0.0,0.0])
    return {"ready":true,"point":point+Vector3(offset[0],offset[1],offset[2])}
