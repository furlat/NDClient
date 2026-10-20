extends "res://tests/vampiric_touch_input_checks.gd"
## Actual self healing and existing hand owner; no inferred drain arithmetic.
const Timeline=preload("res://presentation/timeline.gd")
const Recording=preload("res://studio/recording.gd")
const NativeSpells=preload("res://presentation/native_spell_authoring.gd")
const Compare=preload("res://tests/schema16_fold_vectors_checks.gd")
const ACTION_ID="action.spell.vampiric_touch.strike"
const ACTION_PATH="res://authoring/abilities/actions/action.spell.vampiric_touch.strike.tres"
const HEALING="bg3-36/vampiric-touch/vampiric_touch_native/healing"
const POSITIVE="res://tests/fixtures/schema16/vampiric-positive"
const HAND="condition_vampiric_touch_hand_persistent"
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("VAMPIRIC_HEALING_INPUT_FAIL ",label)
func healing_cache(built:Dictionary)->Dictionary:
    var cache:Dictionary=cache_for(built.native.records[ID])
    var admitted:Dictionary=Sources.admission(cache)
    var index:Resource=admitted.index.duplicate();index.conditions=admitted.index.conditions.duplicate()
    index.conditions.merge(built.native.conditions,true)
    cache[Sources.CACHE_KEY]=Sources.make_admission(index,admitted.loaded)
    var actions:Dictionary=Compiler.Authoring.load_data("catalog/body_action_bindings.json",cache).duplicate()
    actions.merge(built.docs["catalog/body_action_bindings.json"],true)
    cache["catalog/body_action_bindings.json"]=actions
    return cache
func negative_controls(events:Array,source:Dictionary,heal:Dictionary,descriptor:Dictionary,label:String)->void:
    for kind in ["canceled_source","request_source","canceled_heal","request_heal","zero","blocked","foreign_source","foreign_patient","undisclosed_donor","detached_ancestry","missing_parent"]:
        var copied:Array=events.duplicate(true)
        var owner:Dictionary=copied.filter(func(row):return row.id==source.id)[0]
        var result:Dictionary=copied.filter(func(row):return row.id==heal.id)[0]
        match kind:
            "canceled_source":owner.canceled=true
            "request_source":owner.phase="request"
            "canceled_heal":result.canceled=true
            "request_heal":result.phase="request"
            "zero":result.fact.actual_healing=0
            "blocked":result.fact.was_blocked=true
            "foreign_source":result.fact.source_entity_uuid=null
            "foreign_patient":result.fact.target_entity_uuid=owner.fact.target_entity_uuid
            "undisclosed_donor":owner.fact.target_entity_uuid=null
            "detached_ancestry":result.parent_lineage=null
            "missing_parent":result.parent_event=null
        check(Results.observed(owner,descriptor,graph_for(copied)).is_empty(),label+" private "+kind+" cannot admit a healing-return source")
func run()->void:
    var spell:Resource=load(PATH);var action:Resource=load(ACTION_PATH)
    var built:Dictionary=Build.documents({"spells":{ID:spell},"actions":{ACTION_ID:action},
        "contexts":{"hit_flash":load("res://authoring/abilities/contexts/hit_flash.tres")}},
        {"spells":{ID:PATH},"actions":{ACTION_ID:ACTION_PATH}})
    check(spell.owner_kind=="condition" and spell.owner_ids==PackedStringArray(["condition.spell.vampiric_touch"]) \
        and spell.owner_cues==PackedInt32Array([3,4]) and spell.excluded_cues.is_empty(),"Held and retire probes hand over to the exact existing UUID lifecycle, without exclusions")
    check(not spell.effects[0].unbound_constructor_inputs.is_empty() and spell.status=="partial", "Future owner before application remains an explicit windup gap")
    check(action.effects.size()==2 and not action.effects[1].unbound_constructor_inputs.is_empty() and action.status=="partial", "Native repeat action gets actual healing only; repeat-impact owner activity remains missing")
    var descriptor:Dictionary=spell.effects[2].constructor_input
    check(descriptor.projection=="healing_return" and action.effects[0].constructor_input==descriptor \
        and spell.effects[2].at=="cast" and spell.effects[2].delay==0.0,"First and repeat use the same observed-heal projection without a second authored delay")
    var selected:Dictionary=built.native.records[ID].selection
    check(NativeSpells.owned_cues(selected)==[3,4] and NativeSpells.effect_clips(selected).all(func(clip):return not str(clip.id).ends_with("/condition") and not str(clip.id).ends_with("/retire")),"Shared owner handover retires both independent probe sources")
    var phase:Resource=load(Effects.choice(Effects.clip(HEALING)).approaches[0].source_phase)
    var immutable:PackedByteArray=var_to_bytes(phase.to_clip())
    for seat in ["amber","blue"]:
        await inspect_healing(POSITIVE.path_join(seat),seat,true,descriptor,built,phase)
        await inspect_healing(Fixtures.journal("vampiric-touch",seat),seat,false,descriptor,built,phase)
        var index:Dictionary=Recording.read(POSITIVE.path_join(seat),{}, {},healing_cache(built))
        check(index.ok,seat+" existing UUID lifecycle compiles through ordinary Studio")
        if index.ok:
            var held:Array=index.rows.filter(func(row):return row.get("component",{}).get("lifecycle_key")==HAND)
            var ids:Dictionary={};var owner_ids:Dictionary={}
            for row in held:
                ids[row.component.id]=true;owner_ids[row.owner.condition.condition_uuid]=true
                check(row.component.persistent_owner and row.source_start_ms==row.owner.start_ms,seat+" hand source retains the original UUID start across split intervals")
            check(not held.is_empty() and ids.size()==1 and owner_ids.size()==1,seat+" one existing hand owner spans first cast, movement, repeat and removal")
            check(held.any(func(row):return row.lifecycle_phase=="removal" and not is_inf(row.owner.end_ms)),seat+" actual removal produces the same owner's finite source-close phase")
    check(var_to_bytes(phase.to_clip())==immutable,"All original views and private controls preserve the sealed healing source/material")
    print("VAMPIRIC_HEALING_INPUTS ",JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence,"scope":"Actual positive/zero first/repeat healing and exact existing UUID handover. Native pixels, performance, pre-application windup and repeat impact remain separate."}))
    quit(0 if failures.is_empty() else 1)
func inspect_healing(directory:String,seat:String,positive:bool,descriptor:Dictionary,built:Dictionary,phase:Resource)->void:
    var label:String=("positive/" if positive else "zero/")+seat
    var journal:RefCounted=Journal.new();check(journal.open(directory,true,false).ok,label+" original journal opens")
    var timeline:RefCounted=Timeline.new();var cache:Dictionary=healing_cache(built)
    var files:PackedStringArray=DirAccess.get_files_at(directory);files.sort()
    var count:int=0;var duration:float=0.0;var compiled_results:Array=[]
    for file in files:
        if file.get_basename().length()!=16 or not file.get_basename().is_valid_int():continue
        var sequence:int=int(file.get_basename());var raw:PackedByteArray=FileAccess.get_file_as_bytes(directory.path_join(file))
        var decoded:Dictionary=journal.decode_record(sequence,raw);check(decoded.ok,label+" decode "+str(sequence))
        if not decoded.ok:return
        var before:Dictionary=journal.state
        var folded:Dictionary=journal._consume_admitted(decoded.value,raw,true);check(folded.ok,label+" independent SDK fold "+str(sequence))
        if not folded.ok:return
        if sequence==0:
            timeline.accept({"kind":"initialization","state":journal.state.duplicate(true),"sequence":0});continue
        var immutable:PackedByteArray=var_to_bytes(folded.normalized)
        for native in folded.normalized.lineages:
            var lineage:Dictionary=Occurrences.group(native);var graph:Dictionary=graph_for(lineage.events)
            for node in lineage.events:
                if node.get("fact")==null or node.fact.get("behavior_id") not in [ID,ACTION_ID]:continue
                var observations:Array=Results.observed(node,descriptor,graph)
                check(observations.size()==(1 if positive else 0),label+" only an actual positive result admits this source: "+str(node.id))
                for observation in observations:
                    count+=1
                    var fact:Dictionary=observation.node.fact;var supplied:Dictionary=observation.inputs.healing_input
                    check(supplied.actual_healing==fact.actual_healing and supplied.actual_healing==(5 if node.fact.behavior_id==ID else 12) \
                        and not supplied.was_blocked,label+" exact original positive healing amount, never half-damage arithmetic")
                    check(observation.target_uuid==node.fact.target_entity_uuid and observation.values.recipient_uuid==node.fact.target_entity_uuid \
                        and supplied.recipient_uuid==node.fact.source_entity_uuid,label+" enemy optical recipient remains distinct from the actually healed caster")
                    check(supplied.healing_fact_uuid==str(observation.node.id) and supplied.parent_event_uuid==str(observation.node.parent_event) \
                        and observation.values.activation_event_uuid==str(observation.node.parent_event),label+" actual HealFact parent owns activation, not final cast/action occurrence")
                    check(observation.values.owner.is_empty() and observation.values.strike.is_empty() and observation.values.tick.is_empty() \
                        and observation.values.condition.is_empty() and observation.values.item_uuid.is_empty(),label+" private constructor clears all successful review owners/results/item identities")
                    var clip:Dictionary=Adapter.clip_with_inputs(phase,[{"component_path":descriptor.component_path,"input_field":"","values":observation.values}])
                    var source:Node3D=load(clip.components[0].script).new();source.configure(clip.components[0].input)
                    check(source.healing_admitted() and not source.owner_admitted() and not source.payload_admitted(),label+" actual sealed branch admits healing independently of held/repeat impact")
                    check(clip.components[0].input.material==phase.to_clip().components[0].input.material,label+" sealed material remains unchanged")
                    source.free();negative_controls(lineage.events,node,observation.node,descriptor,label)
                    evidence.append({"seat":seat,"behavior":node.fact.behavior_id,"projection":observation.evidence})
        var compiled:Dictionary=Compiler.compile_recorded(before,folded.normalized,cache,journal.state,folded.transitions)
        check(compiled.ok,label+" production compile "+str(sequence));if not compiled.ok:return
        timeline.accept({"kind":"operation","groups":compiled.value.groups})
        for group in compiled.value.groups:
            duration+=float(group.duration_ms)
            for component in group.components:
                if component.get("native_clip",{}).get("id")!=HEALING:continue
                compiled_results.append(component)
                check(component.status=="available" and component.native_inputs.has("healing_input") and not component.get("persistent_owner",false),label+" real first/repeat setter receives the finite observed-healing packet")
                var commits:Array=group.commits.filter(func(commit):return str(commit.get("event_uuid",""))==str(component.source_event_uuid))
                check(commits.size()==1 and is_equal_approx(component.start_ms,commits[0].at_ms),label+" healing begins at its own actual result clock with no second release delay")
                check(is_equal_approx(component.duration_ms,460.0),label+" original .46-second source duration is retained")
        check(var_to_bytes(folded.normalized)==immutable,label+" compilation and private controls preserve original native operands")
    check(count==(2 if positive else 0) and compiled_results.size()==count,label+" both real first/repeat heals appear exactly once; zero produces none")
    timeline.advance(duration+1000.0)
    check(not timeline.busy() and Compare.difference(timeline.state,journal.state).is_empty(),label+" complete replay drains to independent canonical state without holds")
