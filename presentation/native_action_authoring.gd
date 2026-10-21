extends RefCounted
## The existing Factory phase compiler, on an action's actual body markers.
## Domain facts remain actions; no spell declaration or gameplay is invented.
const Phases=preload("res://presentation/native_spell_authoring.gd")
const Audio=preload("res://presentation/audio_cues.gd")
const Authoring=preload("res://presentation/authoring.gd")
const Effects=preload("res://presentation/effect_package.gd")

## Immutable source candidates for a disclosed choice; no synthetic event,
## constructor, owner clock or outcome is created during selection.
static func effect_clips(behavior:String,cache:Dictionary)->Array:
    var result:Array=[];var seen:Dictionary={}
    var binding:Dictionary=Authoring.load_data("catalog/body_action_bindings.json",cache).get(behavior,{})
    for cue in binding.get("effect_cues",[]):
        if not cue.get("unbound_constructor_inputs",[]).is_empty():continue
        var clip:Dictionary=Effects.for_cue(cue,behavior,str(cue.role))
        if clip.is_empty():continue
        # Candidate preparation must select the same resource-authored
        # approach, source bank and opacity inputs as the played occurrence.
        clip=Effects.occurrence_clip({"native_clip":clip,"native_cue":cue})
        var identity:String=Effects.key(clip)
        if seen.has(identity):continue
        if not cue.get("constructor_input",{}).is_empty():clip.requires_constructor_input=true
        seen[identity]=true;result.append(clip)
    return result

static func descendant(candidate:Dictionary,owner:Dictionary,graph:Dictionary)->bool:
    var parent:Variant=candidate.get("parent_lineage")
    while parent!=null:
        if str(parent)==str(owner.lineage_id):return true
        var node:Dictionary=graph.get("nodes",{}).get(str(parent),{})
        if node.is_empty():return false
        parent=node.get("parent_lineage")
    return false

## Projection packets are observed operands, not inferred outcomes. Factory
## fields named *_uuid carry the actual native occurrence encoded as a string;
## the component still retains occurrence and lineage separately.
static func inputs(node:Dictionary,binding:Dictionary,phase:Dictionary,graph:Dictionary,observations:Array=[])->Dictionary:
    var result={"values":{},"gaps":[],"evidence":{}}
    var required:Array=phase.native_clip.get("inputs",[])
    if "owner_projection" not in required and "activation_projection" not in required:return result
    var actor:String=str(node.fact.source_entity_uuid)
    var heals:Array=[];var applications:Array=[];var removals:Dictionary={}
    var row_order:int=0
    var events:Array=observations if not observations.is_empty() else graph.get("nodes",{}).values()
    for candidate in events:
        if candidate.get("canceled",false):continue
        for cue in graph.get("condition_cues",{}).get(candidate.id,[]):
            row_order+=1
            if cue.phase=="removal" and cue.actor_uuid==actor:
                if not removals.has(cue.condition.condition_uuid):removals[cue.condition.condition_uuid]=[]
                removals[cue.condition.condition_uuid].append({"node":candidate,"order":row_order})
            if descendant(candidate,node,graph) and cue.phase=="application" and cue.actor_uuid==actor \
                    and cue.condition.behavior_id in binding.get("applies_conditions",[]):
                applications.append({"node":candidate,"cue":cue,"order":row_order})
        if not descendant(candidate,node,graph):continue
        var fact:Dictionary=candidate.get("fact",{}) if candidate.get("fact")!=null else {}
        if fact.get("kind")=="heal" and fact.get("source_entity_uuid")==actor and fact.get("target_entity_uuid")==actor \
                and fact.get("actual_healing",0)>0 and not fact.get("was_blocked",true) and fact.get("source_condition_uuid")==null:
            heals.append(candidate)
    var descriptor:Dictionary=phase.native_cue.get("owner_projection",{})
    var linked_child:Dictionary={}
    if not descriptor.is_empty():
        var pairs:Array=[]
        for child in applications:
            if child.cue.condition.behavior_id!=descriptor.child_behavior_id:continue
            var raw:Variant=child.cue.condition.get("state")
            var state:Dictionary=raw if raw is Dictionary else {}
            var parent_id:Variant=state.get(str(descriptor.parent_field))
            if parent_id==null:continue
            for parent in applications:
                if parent.cue.condition.condition_uuid==parent_id and parent.cue.condition.behavior_id==descriptor.parent_behavior_id \
                    and parent.order<child.order:pairs.append({"parent":parent,"child":child})
        if pairs.size()==1:
            applications=[pairs[0].parent];linked_child=pairs[0].child
        else:
            applications=[];result.gaps.append("native_condition_parent_link_unavailable")
    if descriptor.is_empty() and heals.size()==1 and "owner_projection" in required:
        var heal:Dictionary=heals[0]
        # The native parent occurrence may be an earlier version of the same
        # action lineage. Preserve it; do not manufacture a UUID or replace an
        # intervening native parent with the action's final fact occurrence.
        if heal.get("parent_lineage")==node.lineage_id and heal.get("parent_event")!=null:
            var identity:String=str(heal.parent_event)
            result.values.owner_projection={"actor_id":actor,"actor_uuid":actor,"action_uuid":identity,
                "behavior_id":node.fact.behavior_id,"admitted":true,"begin_seconds":0.0,
                "healing":{"observed_completion":true,"event_uuid":str(heal.id),"parent_event_uuid":identity,
                    "source_entity_uuid":heal.fact.source_entity_uuid,"target_entity_uuid":heal.fact.target_entity_uuid,
                    "actual_healing":heal.fact.actual_healing,"was_blocked":heal.fact.was_blocked}}
            result.evidence={"action_occurrence":str(node.id),"action_lineage":str(node.lineage_id),
                "heal_occurrence":str(heal.id),"heal_lineage":str(heal.lineage_id),"native_action_parent_occurrence":identity}
        else:result.gaps.append("native_healing_parent_observation_unavailable")
    elif applications.size()==1:
        var application:Dictionary=applications[0]
        var condition:Dictionary=application.cue.condition
        result.evidence={"condition_uuid":condition.condition_uuid,"behavior_id":condition.behavior_id,
            "application_occurrence":str(application.node.id),"action_occurrence":str(node.id),"action_lineage":str(node.lineage_id)}
        var removed:Dictionary={}
        for candidate in removals.get(condition.condition_uuid,[]):
            if candidate.order>application.order:removed=candidate.node;break
        result.values.owner_projection={"actor_id":actor,"actor_uuid":actor,"owner_uuid":condition.condition_uuid,
            "behavior_id":condition.behavior_id,"admitted":true,"suppressed":false,"begin_seconds":0.0,
            "removed_seconds":-1.0}
        if not removed.is_empty() and graph.get("starts",{}).has(removed.id):
            result.values.owner_projection.removed_seconds=maxf(0.0,(float(graph.starts[removed.id])-float(phase.start_ms))/1000.0)
            result.evidence.removal_occurrence=str(removed.id)
        if not linked_child.is_empty():
            var child:Dictionary=linked_child.cue.condition
            var child_state:Dictionary=child.state
            result.values.owner_projection[str(descriptor.child_input)]={"owner_uuid":str(child.condition_uuid),
                "behavior_id":str(child.behavior_id),"parent_owner_uuid":str(child_state[str(descriptor.parent_field)]),
                "admitted":true,"suppressed":not child_state.get("suppression_provider_uuids",[]).is_empty()}
            result.evidence.child_condition_uuid=str(child.condition_uuid)
            result.evidence.child_application_occurrence=str(linked_child.node.id)
            for candidate in removals.get(child.condition_uuid,[]):
                if candidate.order<=linked_child.order or not graph.get("starts",{}).has(candidate.node.id):continue
                var removed_seconds:float=maxf(0.0,(float(graph.starts[candidate.node.id])-float(phase.start_ms))/1000.0)
                var parent_end:float=float(result.values.owner_projection.removed_seconds)
                result.values.owner_projection.removed_seconds=removed_seconds if parent_end<0.0 else minf(parent_end,removed_seconds)
                break
        # -1 is the delivered class source's explicit unknown-removal sentinel,
        # including the finite activation adapter. No clip/round expiry is inferred.
        if "activation_projection" in required:
            result.values.activation_projection={"actor_id":actor,"action_uuid":str(node.id),"behavior_id":node.fact.behavior_id,
                "admitted":true,"parent_owner_uuid":condition.condition_uuid,"begin_seconds":0.0}
    elif applications.size()>1:result.gaps.append("native_condition_parent_link_unavailable")
    else:result.gaps.append("native_owner_projection_observation_unavailable")
    for input in ["owner_projection","activation_projection"]:
        if input in required and not result.values.has(input) and result.gaps.is_empty():result.gaps.append("native_"+input+"_observation_unavailable")
    return result

static func anchor(at:String,recipe:Dictionary,track:Dictionary,markers:Dictionary,cache:Dictionary)->Variant:
    if at in ["action_start","event.start","cast","cast_start"]:return markers.get("event.start")
    if markers.has(at):return markers[at]
    var name:String=at.trim_prefix("body.")
    for marker in recipe.get("anchors",[]):
        if marker.name!=name or track.is_empty():continue
        var clip:Dictionary=Authoring.rigs(cache).get(track.rig,{}).get("clips",{}).get(track.clip,{})
        if clip.is_empty():return null
        var direction:String="reverse" if track.source_end_seconds<track.source_start_seconds else "forward"
        var times:Array=Audio.source_frame_times(track,float(marker.frame),float(clip.fps),int(clip.frames),direction)
        return times[0] if not times.is_empty() else null
    return markers.get("body.contact") if name in ["release","contact"] else null

static func phases(binding:Dictionary,fact:Dictionary,recipe:Dictionary,track:Dictionary,markers:Dictionary,cache:Dictionary)->Array:
    var result:Array=[]
    for original in binding.get("effect_cues",[]):
        var cue:Dictionary=original.duplicate()
        var authored_at:String=str(cue.get("at","event.start"))
        var index:int=int(cue.source_index)
        var pointer:String=str(binding.source)+"/"+str(index)
        var at:Variant=anchor(authored_at,recipe,track,markers,cache)
        if at==null:
            result.append({"start_ms":float(markers.get("event.start",0.0)),"duration_ms":0.0,"status":"missing",
                "reason":"native_action_anchor_unavailable","source":pointer,"native_cue":cue,"native_clip":{}})
            continue
        # The phase compiler's release is this cue's authored action anchor.
        # It still owns source clocks, particle tails and ordinary placement.
        cue.at="release"
        var selected={"id":str(cue.get("selection",fact.behavior_id)),"source":str(binding.source),"source_bounds":{},"palette":{},
            "staging":{"decorative_light_multiplier":float(cue.get("light_multiplier",0.0))}}
        var phase:Dictionary=Phases._phase(selected,cue,{"prepare":float(markers.get("event.start",at))},float(at),0.0,0)
        phase.erase("spell_id")
        phase.source=pointer;phase.source_id=str(fact.behavior_id)+".native."+str(cue.role)
        phase.ability_id=fact.behavior_id;phase.ability_kind=fact.kind
        phase.timing_source=pointer+"/at";phase.timing_selector=authored_at
        phase.native_cue.authored_at=authored_at
        result.append(phase)
    return result
