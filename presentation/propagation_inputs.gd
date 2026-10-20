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
