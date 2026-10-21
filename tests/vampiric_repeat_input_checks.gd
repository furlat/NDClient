extends "res://tests/vampiric_touch_input_checks.gd"
## Genuine completed repeat plus private boundary controls, not new wire facts.
const Timeline=preload("res://presentation/timeline.gd")
const Compare=preload("res://tests/schema16_fold_vectors_checks.gd")
const Common=preload("res://tools/presentation_build/common.gd")
const ACTION="action.spell.vampiric_touch.strike"
const ACTION_PATH="res://authoring/abilities/actions/action.spell.vampiric_touch.strike.tres"
const OWNER="condition.spell.vampiric_touch"
const ORIGINAL="res://tests/fixtures/schema16/vampiric-positive"
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("VAMPIRIC_REPEAT_INPUT_FAIL ",label)
func repeat_graph(events:Array,before:Dictionary)->Dictionary:
    var graph:Dictionary=graph_for(events)
    graph.actor_inputs={}
    for node in events:graph.actor_inputs[node.id]=before.actors
    return graph
func negative_controls(events:Array,source:Dictionary,damage:Dictionary,before:Dictionary,descriptor:Dictionary,label:String)->void:
    for control in ["canceled","request","miss","foreign_behavior","zero","canceled_damage","requested_damage","foreign_source","foreign_target","detached","missing_owner","ambiguous_owner","foreign_actor"]:
        var copied:Array=events.duplicate(true)
        var node:Dictionary=copied.filter(func(row):return row.id==source.id)[0]
        var result:Dictionary=copied.filter(func(row):return row.id==damage.id)[0]
        var state:Dictionary=before.duplicate(true)
        var actor:Dictionary=state.actors[str(source.fact.source_entity_uuid)]
        match control:
            "canceled":node.canceled=true
            "request":node.phase="request"
            "miss":node.fact.attack_outcome="Miss"
            "foreign_behavior":node.fact.behavior_id=ID
            "zero":result.fact.applied_damage=0
            "canceled_damage":result.canceled=true
            "requested_damage":result.phase="request"
            "foreign_source":result.fact.source_entity_uuid=null
            "foreign_target":result.fact.target_entity_uuid=node.fact.source_entity_uuid
            "detached":result.parent_lineage=null
            "missing_owner":actor.conditions=actor.conditions.filter(func(member):return member.get("behavior_id")!=OWNER)
            "ambiguous_owner":actor.conditions.append(actor.conditions.filter(func(member):return member.get("behavior_id")==OWNER)[0].duplicate(true))
            "foreign_actor":actor.uuid=node.fact.target_entity_uuid
        check(not Results.spell_strike(node,descriptor,repeat_graph(copied,state)).ready,label+" private "+control+" cannot admit a repeated contact")
    var later:Dictionary=repeat_graph(events,before.duplicate(true))
    later.actor_inputs=later.actor_inputs.duplicate(true)
    later.actor_inputs[source.id][source.fact.source_entity_uuid].conditions=[]
    later.actor_inputs["later_private_cut"]={source.fact.source_entity_uuid:before.actors[source.fact.source_entity_uuid]}
    check(not Results.spell_strike(source,descriptor,later).ready,label+" a later owner cannot replace the original pre-row membership")
func run()->void:
    var spell:Resource=load(PATH);var action:Resource=load(ACTION_PATH)
    var uses:Array=action.effects.filter(func(cue):return cue.constructor_input.get("kind")=="spell_strike")
    check(uses.size()==1,"Exactly one authored repeated contact has the strike contract")
    if uses.size()!=1:quit(1);return
    var use:Resource=uses[0]
    var descriptor:Dictionary=use.constructor_input
    check(use.unbound_constructor_inputs.is_empty() and descriptor.kind=="spell_strike" \
        and descriptor.behavior_id==ACTION and descriptor.owner_condition_id==OWNER,"Production repeat names the actual action and condition grant")
    check(action.body.enabled==false and use.at=="event.start" and use.delay==0.0,"Finite contact uses the real result clock without fabricating a body marker")
    check(spell.effects[0].unbound_constructor_inputs.is_empty() and spell.effects[0].constructor_input.projection=="owner_activity" and spell.owner_cues==PackedInt32Array([3,4]),"Event-local windup is authored while the existing UUID lifecycle owns held/removal")
    var clip:Dictionary=Effects.clip(IMPACT);var report:Dictionary=Common.report()
    Build._check_constructor(use,"abilities/actions/"+ACTION,{IMPACT:clip},report)
    check(report.errors.is_empty(),"Exact repeat source policy is accepted offline: "+str(report.errors))
    for control in ["wrong_owner","missing_owner","wrong_clock","owner_inapplicable"]:
        var invalid:Resource=use.duplicate(true)
        match control:
            "wrong_owner":invalid.constructor_input.owner_condition_id="condition.concentrating"
            "missing_owner":invalid.constructor_input.erase("owner_condition_id")
            "wrong_clock":invalid.at="release"
            "owner_inapplicable":invalid.extra.input_policies.owner_input={"mode":"not_applicable","reason":"accepted_repeat_impact_does_not_consume_healing_condition_tick_inputs"}
        report=Common.report();Build._check_constructor(invalid,"abilities/actions/"+ACTION,{IMPACT:clip},report)
        check(not report.errors.is_empty(),"Offline "+control+" cannot bypass the selected source's grant contract")
    var built:Dictionary=Build.documents({"spells":{ID:spell},"actions":{ACTION:action},
        "contexts":{"hit_flash":load("res://authoring/abilities/contexts/hit_flash.tres")}},
        {"spells":{ID:PATH},"actions":{ACTION:ACTION_PATH}})
    var phase:Resource=load(Effects.choice(clip).approaches[0].source_phase)
    var sealed:PackedByteArray=var_to_bytes(phase.to_clip())
    for seat in ["amber","blue"]:inspect_original(ORIGINAL.path_join(seat),seat,built,phase,descriptor)
    check(var_to_bytes(phase.to_clip())==sealed,"Both audiences and controls preserve shared Factory material/source settings")
    print("VAMPIRIC_REPEAT_INPUTS ",JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence,
        "scope":"Actual accepted repeat and its exact positive damage/pre-row condition grant. Event-local activity only; native output, idle activity and windup remain separately qualified."}))
    quit(0 if failures.is_empty() else 1)
func inspect_original(directory:String,seat:String,built:Dictionary,phase:Resource,descriptor:Dictionary)->void:
    var journal:RefCounted=Journal.new();check(journal.open(directory,true,false).ok,seat+" original opens")
    var cache:Dictionary=cache_for(built.native.records[ID])
    var actions:Dictionary=Compiler.Authoring.load_data("catalog/body_action_bindings.json",cache).duplicate()
    actions.merge(built.docs["catalog/body_action_bindings.json"],true);cache["catalog/body_action_bindings.json"]=actions
    var timeline:RefCounted=Timeline.new();var duration:float=0.0;var projected_count:int=0;var compiled_count:int=0
    var files:PackedStringArray=DirAccess.get_files_at(directory);files.sort()
    for file in files:
        if file.get_basename().length()!=16 or not file.get_basename().is_valid_int():continue
        var sequence:int=int(file.get_basename());var raw:PackedByteArray=FileAccess.get_file_as_bytes(directory.path_join(file))
        var decoded:Dictionary=journal.decode_record(sequence,raw);check(decoded.ok,seat+" decode "+str(sequence));if not decoded.ok:return
        var before:Dictionary=journal.state;var folded:Dictionary=journal._consume_admitted(decoded.value,raw,true)
        check(folded.ok,seat+" independent fold "+str(sequence));if not folded.ok:return
        if sequence==0:
            timeline.accept({"kind":"initialization","state":journal.state.duplicate(true),"sequence":0});continue
        var immutable:PackedByteArray=var_to_bytes(folded.normalized)
        for native in folded.normalized.lineages:
            var lineage:Dictionary=Occurrences.group(native);var graph:Dictionary=repeat_graph(lineage.events,before)
            for node in lineage.events:
                if node.get("fact")==null or node.fact.get("behavior_id")!=ACTION:continue
                var projected:Dictionary=Results.spell_strike(node,descriptor,graph)
                check(projected.ready,seat+" actual repeat projects: "+str(projected.get("reason")));if not projected.ready:continue
                projected_count+=1
                var owner:Dictionary=projected.inputs.owner_input;var strike:Dictionary=projected.inputs.strike_input
                check(projected.node.fact.applied_damage==24 and strike.outcome=="critical" and strike.behavior_id==ACTION,seat+" actual Crit and 24 Necrotic are preserved")
                check(projected.node.id==strike.damage_fact_uuid and strike.attack_uuid==node.id,seat+" exact local damage and accepted-action occurrences stay distinct")
                var members:Array=before.actors[node.fact.source_entity_uuid].conditions.filter(func(member):return member.get("behavior_id")==OWNER)
                check(members.size()==1 and owner.condition_uuid==members[0].condition_uuid and owner.condition_id==OWNER,seat+" the one actual pre-row condition UUID is retained")
                check(owner.source_actor_uuid==node.fact.source_entity_uuid and owner.recipient_uuid==node.fact.source_entity_uuid \
                    and projected.values.recipient_uuid==node.fact.target_entity_uuid,seat+" caster grant and enemy optical recipient are separate")
                check(projected.evidence.owner_activity_occurrence==node.id and projected.evidence.owner_cut=="source_actor_before_row",seat+" activity evidence is confined to this completed strike")
                check(projected.values.condition.is_empty() and projected.values.tick.is_empty() and projected.values.healing.is_empty() \
                    and projected.values.item_uuid.is_empty(),seat+" unrelated fixture outcomes/item are cleared")
                var private_clip:Dictionary=Adapter.clip_with_inputs(phase,[{"component_path":descriptor.component_path,"input_field":"","values":projected.values}])
                var source:Node3D=load(private_clip.components[0].script).new();source.configure(private_clip.components[0].input)
                check(source.payload_admitted() and source.owner_admitted() and not source.healing_admitted(),seat+" sealed source admits actual repeat without fixture healing")
                source.set_owner_input({});check(not source.payload_admitted(),seat+" the same strike without its owner is refused by the actual source")
                source.free();negative_controls(lineage.events,node,projected.node,before,descriptor,seat)
                evidence.append({"seat":seat,"sequence":sequence,"projection":projected.evidence})
        var compiled:Dictionary=Compiler.compile_recorded(before,folded.normalized,cache,journal.state,folded.transitions)
        check(compiled.ok,seat+" ordinary compile "+str(sequence));if not compiled.ok:return
        for group in compiled.value.groups:
            duration+=group.duration_ms
            for component in group.components:
                if component.get("native_cue",{}).get("constructor_input",{}).get("behavior_id")!=ACTION or component.native_cue.constructor_input.get("kind")!="spell_strike":continue
                compiled_count+=1
                check(component.status=="available" and component.native_inputs.has("owner_input") and component.native_inputs.has("strike_input"),seat+" production action supplies both required factual packets")
                var damage_id:String=component.native_constructor_evidence.result_occurrence
                var tracks:Array=group.actor_tracks.filter(func(track):return track.source_event_uuid==damage_id)
                check(tracks.size()==1 and is_equal_approx(component.start_ms,tracks[0].start_ms) \
                    and component.source_event_uuid==damage_id,seat+" contact begins with the real recipient TakeDamage pose, independently of HP commit")
                check(is_equal_approx(component.duration_ms,440.0) and not component.get("persistent_owner",false),seat+" exact .44-second finite source creates no duplicate held owner")
        timeline.accept({"kind":"operation","groups":compiled.value.groups})
        check(var_to_bytes(folded.normalized)==immutable,seat+" projection/compile preserve original facts")
    check(projected_count==1 and compiled_count==1,seat+" one genuine repeat yields exactly one finite contact")
    timeline.advance(duration+1000.0)
    check(not timeline.busy() and Compare.difference(timeline.state,journal.state).is_empty(),seat+" replay drains to this audience's independent canonical fold")
