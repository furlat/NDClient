extends RefCounted
## A manifestation accent belongs to an actually disclosed actor admission.
## Actor rendering owns the separate body. Neither visibility loss nor an old
## review preset supplies a terminal event, suppression rule or summoned body.
const Actions=preload("res://presentation/native_action_authoring.gd")
const Characters=preload("res://presentation/characters.gd")

static func observed(owner:Dictionary,descriptor:Dictionary,graph:Dictionary,commits:Array)->Array:
    if owner.get("canceled",false) or owner.get("phase")!="completion" or owner.get("fact")==null:return []
    if owner.fact.get("kind")!="spell" or owner.get("resolution_record",{}).get("application_id")!=null:return []
    var cuts:Dictionary={}
    for commit in commits:
        if commit.has("event_uuid"):cuts[str(commit.event_uuid)]=commit.delta
    var result:Array=[]
    for node in graph.get("nodes",{}).values():
        if node.get("canceled",false) or node.get("phase")!="completion" or node.get("fact")==null \
            or not Actions.descendant(node,owner,graph):continue
        var fact:Dictionary=node.fact
        if fact.get("kind")!="spatial" or fact.get("change_type")!="entity_entered":continue
        var creation:Dictionary=fact.get("creation",{}) if fact.get("creation")!=null else {}
        if creation.get("birth_occurrence")==null or fact.get("entity_uuid")==null:continue
        var identity:String=str(fact.entity_uuid)
        var body:Dictionary={}
        for record in graph.get("body_records",[]):
            if str(record.actor_uuid)==identity and record.get("birth")!=null \
                and int(record.occurrence)<=int(node.occurrence):body=record
        if body.is_empty() or Characters.content_id(body.birth.get("creature_content_ref"))!=str(descriptor.creature_id):continue
        var cut:Dictionary=cuts.get(str(node.id),{})
        var actor:Dictionary=cut.get("actors",{}).get(identity,{})
        if actor.is_empty() or actor.get("last_visual_position")!=fact.get("position"):continue
        var contact:Dictionary=graph.get("contacts",{}).get(identity,{})
        if not contact.has("from_elevation_feet"):continue
        var height:float=float(contact.from_elevation_feet)
        # The birth occurrence and the later body disclosure occurrence are
        # distinct public identities, especially in the opposing seat.
        var binding:Dictionary={"actor_uuid":identity,"birth_occurrence":str(creation.birth_occurrence),
            "admission_occurrence":str(node.id),"body_occurrence":str(body.occurrence),
            "source_occurrence":str(owner.id),"source_lineage":str(owner.lineage_id),
            "creature_id":str(descriptor.creature_id)}
        var evidence:Dictionary=binding.merged({"admission_lineage":str(node.lineage_id),
            "native_parent_occurrence":str(node.parent_event),"position_source":"canonical_actor_admission",
            "birth_identity":"public_creation_birth_occurrence_string","terminal":"not_observed",
            "suppression":"schema16_has_no_active_optical_suppression"})
        var values:Dictionary={"owner_uuid":identity,"birth_event_uuid":str(creation.birth_occurrence),
            "initial_state":{"owner_uuid":identity,"birth_admitted":false,"observed":false,"suppressed":false},
            "review_states":[]}
        result.append({"node":node,"target_uuid":identity,"values":values,"evidence":evidence,
            "binding":binding,"position":fact.position,"elevation_feet":height})
    return result

## Current optical permission uses only the published actor and its actual
## renderer display membership. Withdrawal hides the accent; it cannot replay
## the birth or fabricate the independently unobserved terminal phase.
static func packet(component:Dictionary,state:Dictionary,displayed:bool)->Dictionary:
    var binding:Dictionary=component.get("native_actor_birth",{})
    if binding.is_empty():return {"ready":false,"reason":"actor_birth_not_observed"}
    var identity:String=str(binding.actor_uuid)
    var actor:Dictionary=state.get("actors",{}).get(identity,{})
    var present:bool=actor.get("present",false)
    return {"ready":true,"reason":"","value":{"owner_uuid":identity,"birth_admitted":present,
        "observed":present and displayed,"suppressed":false}}
