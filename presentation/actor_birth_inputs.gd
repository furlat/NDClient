extends RefCounted
## A manifestation accent belongs to an actually disclosed actor admission.
## Actor rendering owns the separate body. Neither visibility loss nor an old
## review preset supplies a terminal event, suppression rule or summoned body.
const Actions=preload("res://presentation/native_action_authoring.gd")
const Characters=preload("res://presentation/characters.gd")
const Authoring=preload("res://presentation/authoring.gd")
const Phases=preload("res://presentation/native_spell_authoring.gd")

static func observed(owner:Dictionary,descriptor:Dictionary,graph:Dictionary,commits:Array)->Array:
    if owner.get("canceled",false) or owner.get("phase")!="completion" or owner.get("fact")==null:return []
    if owner.fact.get("kind")!="spell" or owner.get("resolution_record",{}).get("application_id")!=null:return []
    var cuts:Dictionary={}
    for commit in commits:
        if commit.has("event_uuid"):cuts[str(commit.event_uuid)]=commit.delta
    var creatures:Array=descriptor.get("creature_ids",[])
    if creatures.is_empty() and not str(descriptor.get("creature_id","")).is_empty():creatures=[str(descriptor.creature_id)]
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
        if body.is_empty():continue
        var creature:String=Characters.content_id(body.birth.get("creature_content_ref"))
        if creature not in creatures:continue
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
            "creature_id":creature}
        var evidence:Dictionary=binding.merged({"admission_lineage":str(node.lineage_id),
            "native_parent_occurrence":str(node.parent_event),"position_source":"canonical_actor_admission",
            "birth_identity":"public_creation_birth_occurrence_string","terminal":"not_observed",
            "suppression":"schema16_has_no_active_optical_suppression"})
        var values:Dictionary={"owner_uuid":identity,"birth_event_uuid":str(creation.birth_occurrence),"form":creature,
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

## A witnessed terminal cut owns a finite ground accent after actor absence.
## Its original birth event and current displayed body are not source operands.
static func terminal_phases(node:Dictionary,graph:Dictionary,cache:Dictionary)->Array:
    if node.get("canceled",false) or node.get("phase")!="completion" or node.get("fact")==null:return []
    var fact:Dictionary=node.fact
    if fact.get("kind")!="spatial" or fact.get("change_type")!="entity_left" \
        or not fact.get("terminal_departure",false) or fact.get("terminal_cause")==null \
        or str(fact.terminal_cause).is_empty() or fact.get("entity_uuid")==null or fact.get("position")==null \
        or fact.get("commit_occurrence")==null:return []
    var identity:String=str(fact.entity_uuid)
    var actor:Dictionary=graph.get("actor_inputs",{}).get(node.id,{}).get(identity,{})
    if actor.get("manifestation")==null:return []
    var creature:String=Characters.content_id(actor.get("creature_content_ref"))
    var contact:Dictionary=graph.get("terminal_inputs",{}).get(str(node.id),{})
    var result:Array=[]
    for original in Authoring.load_data("catalog/entity_lifecycle_media.json",cache).get("nativeEffects",[]):
        var binding:Dictionary=original.get("constructor_input",{})
        if binding.get("kind")!="actor_terminal" or creature not in binding.get("creature_ids",[]):continue
        var start:float=float(graph.get("committed_at",{}).get(str(node.id),graph.starts.get(node.id,0.0)))
        var cue:Dictionary=original.duplicate(true);cue.at="release"
        var selected:Dictionary={"id":"entity_lifecycle","source":str(original.source),"staging":{},"source_bounds":{},"palette":{}}
        var phase:Dictionary=Phases._phase(selected,cue,{"prepare":start},start,0.0,0)
        phase.erase("spell_id")
        phase.source=str(original.source);phase.source_id="entity.terminal."+str(original.source_index)
        phase.timing_selector=str(original.at);phase.native_cue.authored_at=str(original.at)
        phase.merge({"native_spell":true,"actor_uuid":identity,"target_uuid":identity,"ground_target":true,
            "from_position":fact.position,"to_position":fact.position,"cast_recipe":{"enabled":false},
            "native_constructor_inputs":[],"native_actor_terminal":{
                "entity_uuid":identity,"creature_id":creature,"position":fact.position,
                "terminal_occurrence":int(fact.commit_occurrence),"observation_occurrence":int(node.occurrence),
                "terminal_cause":str(fact.terminal_cause),"terminal_started_at_seconds":0.0},
            "native_constructor_evidence":{"actor_uuid":identity,"creature_id":creature,
                "commit_occurrence":int(fact.commit_occurrence),"observation_occurrence":int(node.occurrence),
                "source_index":contact.get("source_index"),"position_source":"witnessed_terminal_fact",
                "birth_required":false,"body_required":false}},true)
        if not contact.has("elevation_feet"):
            phase.status="missing";phase.reason="witnessed_terminal_ground_support_not_disclosed"
        else:
            phase.from_elevation_feet=contact.elevation_feet;phase.to_elevation_feet=contact.elevation_feet
            phase.native_actor_terminal.elevation_feet=contact.elevation_feet
        result.append(phase)
    return result

static func terminal_packet(component:Dictionary)->Dictionary:
    var binding:Dictionary=component.get("native_actor_terminal",{})
    return {"kind":"spatial","change_type":"entity_left","terminal_departure":true,
        "entity_uuid":str(binding.entity_uuid),"terminal_cause":str(binding.terminal_cause),
        "terminal_occurrence":int(binding.terminal_occurrence),
        "terminal_started_at_seconds":float(binding.terminal_started_at_seconds)}
