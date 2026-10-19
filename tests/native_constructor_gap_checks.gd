extends SceneTree
## Authored missing operands never execute Factory review fixtures.
const Use=preload("res://presentation/source/effect_use.gd")
const Records=preload("res://tools/presentation_build/ability_records.gd")
const Build=preload("res://tools/presentation_build/abilities.gd")
const Spells=preload("res://presentation/native_spell_authoring.gd")
const Actions=preload("res://presentation/native_action_authoring.gd")
const Native=preload("res://presentation/native_spell_renderer.gd")
const Sources=preload("res://presentation/native_presentation_sources.gd")
const Compiler=preload("res://presentation/compiler.gd")
const Journal=preload("res://sdk/journal.gd")
const Timeline=preload("res://presentation/timeline.gd")
const Compare=preload("res://tests/schema16_fold_vectors_checks.gd")
const ID="spell.circle_of_death"
const PATH="res://authoring/abilities/spells/spell.circle_of_death.tres"
var checks:int=0
var failures:Array=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("CONSTRUCTOR_GAP_FAIL "+label)
func run()->void:
    # Exercise the explicit missing-source policy independently of the actual
    # Circle binding, which now supplies its real constructor operands.
    var entry:Resource=load(PATH).duplicate(true)
    entry.effects[1].unbound_constructor_inputs=PackedStringArray(["application"])
    var policy:Resource=load("res://authoring/abilities/contexts/hit_flash.tres")
    var built:Dictionary=Build.documents({"spells":{ID:entry},"contexts":{"hit_flash":policy}},{"spells":{ID:PATH}})
    var record:Resource=built.native.records[ID]
    var selected:Dictionary=record.selection
    var phases:Array=Spells.phases(selected,{"prepare":100.0},1000.0,300.0,0,true)
    var missing:Array=phases.filter(func(row):return row.get("status")=="missing")
    check(phases.size()==2 and missing.size()==1,"An explicitly unbound receiver retains a missing row beside its available ground source")
    check(missing.all(func(row):return row.unbound_constructor_inputs==["application"] and row.reason=="native_constructor_inputs_unbound:application"),"The shared compiler carries the exact unbound source operand and reason")
    check(missing.all(func(row):return row.source.begins_with(selected.source+"/cues/") and row.duration_ms>0.0),"Missing cues retain their authored timeline and original source pointer")
    check(phases[0].get("status")!="missing" and phases[0].native_clip.id=="review/circle_of_death/whole/impact","The unaffected ground artwork remains available")
    check(Spells.effect_clips(selected).map(func(clip):return clip.id)==["review/circle_of_death/whole/impact"],"Selection does not warm known unusable constructor templates")
    var converted:Dictionary=Records.cue_from_effect(entry.effects[1],1)
    var restored:Resource=Records.effect_from_cue(converted,"test")
    check(Array(restored.unbound_constructor_inputs)==["application"] and not restored.extra.has("unbound_constructor_inputs"),"The requirement round-trips through the typed EffectUse field, not an ad-hoc extra")
    var use:Resource=Use.new();use.clip="fighter_action_surge_native";use.role="attached";use.at="event.start"
    use.unbound_constructor_inputs=PackedStringArray(["actual-owner"])
    var cue:Dictionary=Records.cue_from_effect(use,0)
    var binding:Dictionary={"source":"fixture::effects","effect_cues":[cue]}
    var action:Dictionary={"kind":"action","behavior_id":"action.fixture","source_entity_uuid":"actor"}
    var action_phases:Array=Actions.phases(binding,action,{}, {},{"event.start":50.0},{})
    check(action_phases.size()==1 and action_phases[0].status=="missing" and action_phases[0].reason=="native_constructor_inputs_unbound:actual-owner","The source-gap rule is shared by actions without a spell-name switch")
    var cache:Dictionary={"catalog/body_action_bindings.json":{"action.fixture":binding}}
    check(Actions.effect_clips("action.fixture",cache).is_empty(),"Action selection also excludes its explicitly unusable constructor")
    var native:RefCounted=Native.new()
    var known:Dictionary=missing[0].duplicate();known.id="known"
    native._missing(known,known.reason)
    check(native.issues.is_empty() and native.diagnostics.known.status=="missing" and native.diagnostics.known.unbound_constructor_inputs==["application"],"An expected authored gap stays red/inspectable without becoming a fatal runtime error")
    var admission:Dictionary=native.prepare([{"components":[known]}],{})
    check(admission.ready and native.handles.is_empty() and native._resource_cache.is_empty(),"Known missing cues never enter native resource or scene construction")
    native._missing({"id":"broken","status":"available"},"actual_runtime_program_error")
    check(native.issues==["broken: actual_runtime_program_error"],"A real runtime failure from an available cue remains fatal and visible")
    native._missing({"id":"unregistered","status":"missing"},"effect_not_in_package")
    check(native.issues.size()==2,"An unexpected missing resource is not reclassified as an accepted authoring gap")
    var directory:String=""
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--journal="):directory=arg.trim_prefix("--journal=")
    var real:Dictionary={"requested":not directory.is_empty()}
    if not directory.is_empty():
        real=recording(directory,record)
        check(real.get("completed",false),"The requested real recording check completed without an interrupted script")
    print(JSON.stringify({"checks":checks,"failures":failures,"real_recording":real,"scope":"Known typed source gaps, shared compilation/readiness/diagnostics; actual native output remains a separate gate"}))
    quit(0 if failures.is_empty() else 1)
func recording(directory:String,record:Resource)->Dictionary:
    var cache:Dictionary={}
    var admitted:Dictionary=Sources.admission(cache)
    var index:Resource=admitted.index.duplicate()
    index.spells=admitted.index.spells.duplicate();index.spells[ID]="in-memory typed Circle record"
    var loaded:Dictionary=admitted.loaded.duplicate();loaded[ID]=record
    cache[Sources.CACHE_KEY]=Sources.make_admission(index,loaded)
    var journal:RefCounted=Journal.new()
    var opened:Dictionary=journal.open(directory,true,false)
    check(opened.ok,"Open the real current-schema Circle journal")
    if not opened.ok:return {"requested":true,"error":opened}
    var files:Array=[]
    for name in DirAccess.get_files_at(directory):
        if name.ends_with(".json") and name.get_basename().is_valid_int():files.append(name)
    files.sort()
    var timeline:RefCounted=Timeline.new()
    var groups:Array=[];var duration:float=0.0
    for sequence in files.size():
        var raw:PackedByteArray=FileAccess.get_file_as_bytes(directory.path_join(files[sequence]))
        var decoded:Dictionary=journal.decode_record(sequence,raw)
        check(decoded.ok,"Decode real packet "+str(sequence))
        if not decoded.ok:return {"requested":true,"error":decoded}
        var before:Dictionary=journal.state
        var admitted_record:Dictionary=journal._consume_admitted(decoded.value,raw,true)
        check(admitted_record.ok,"Fold real packet "+str(sequence))
        if not admitted_record.ok:return {"requested":true,"error":admitted_record}
        if sequence==0:
            timeline.accept({"kind":"initialization","state":journal.state.duplicate(true),"sequence":0})
            continue
        var compiled:Dictionary=Compiler.compile_recorded(before,admitted_record.normalized,cache,journal.state,admitted_record.transitions)
        check(compiled.ok,"Compile real packet with the new typed source "+str(sequence))
        if not compiled.ok:return {"requested":true,"error":compiled}
        for group in compiled.value.groups:groups.append(group);duration+=float(group.duration_ms)
    var actors:int=0;var damage:int=0;var gaps:int=0
    for group in groups:
        for track in group.actor_tracks:
            if track.get("activity")=="cast":actors+=1
        for component in group.components:
            if component.get("kind")=="material_flash":damage+=1
            if not component.get("unbound_constructor_inputs",[]).is_empty():gaps+=1
    check(actors>0 and damage>0,"Actual cast and damage body/material presentation remains compiled beside missing VFX")
    check(gaps>0,"The actual recording retains missing receiver cues instead of silently dropping them")
    timeline.accept({"kind":"operation","groups":groups})
    timeline.advance(duration+1000.0)
    check(not timeline.busy() and Compare.difference(timeline.state,journal.state).is_empty(),"Missing receiver VFX cannot delay or alter the authoritative final state")
    return {"requested":true,"completed":true,"cast_tracks":actors,"damage_flash_components":damage,"missing_receiver_components":gaps,"operations":files.size()-1}
