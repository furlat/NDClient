extends SceneTree
## Actual disclosed condition application selects a finite source; labelled
## unit controls below never stand in for a recorded rule outcome.
const Recording=preload("res://studio/recording.gd")
const Journal=preload("res://sdk/journal.gd")
const Conditions=preload("res://presentation/conditions.gd")
const Persistent=preload("res://presentation/native_persistent.gd")
const Spells=preload("res://presentation/native_spell_authoring.gd")
const Effects=preload("res://presentation/effect_package.gd")
const CASES="res://tests/fixtures/schema16/body-scale/cases.json"
const ID="condition.spell.enlarge_reduce"
var checks:int=0
var failures:Array=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("CONDITION_APPLICATION_SOURCE_FAIL ",label)
func run()->void:
    var spell:Resource=load("res://authoring/abilities/spells/spell.enlarge_reduce.tres")
    check(Array(spell.excluded_cues)==[0,1],"Duplicate cast ring and inspection-only sustain are explicitly excluded")
    var source:Resource=load("res://authoring/abilities/conditions/"+ID+".tres")
    check(source.effects.size()==2 and source.effects.all(func(use):return use.at=="application" and use.source_end==.72 and use.duration_policy=="authored"),"One typed finite source per actual size selector")
    for mode in ["enlarge","reduce"]:
        var clip_id:String=("enlarge_reduce_reduce_native" if mode=="reduce" else "enlarge_reduce_native")+"/application"
        var clip:Dictionary=Effects.clip(clip_id)
        var native:Dictionary=clip.approaches.filter(func(approach):return approach.kind=="native")[0]
        var phase:Resource=load(native.source_phase)
        var input:Dictionary=phase.to_clip().components[0].input
        check(clip.inputs.is_empty() and input.direction==(-1.0 if mode=="reduce" else 1.0) and input.duration_seconds==.72,mode+": sealed finite source has the actual opposite direction and no fabricated inputs")
    var cases:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(CASES))
    for case in cases.cases:
        var mode:String="reduce" if case.id.ends_with("reduce_lifecycle") else "enlarge"
        for view in case.perspectives:original(view,mode)
    print("CONDITION_APPLICATION_SOURCES ",JSON.stringify({"checks":checks,"failures":failures,"scope":"Both original faction journals for actual Enlarge/Reduce application, finite source lifetime, unchanged body scale/marker ownership and canonical seek/removal. Native output and visual acceptance are separate gates."}))
    quit(0 if failures.is_empty() else 1)
func original(view:Dictionary,mode:String)->void:
    var label:String=mode+"/"+str(view.id)
    var expected:RefCounted=Journal.new();var opened:Dictionary=expected.open(view.journal,true,true)
    var index:Dictionary=Recording.read(view.journal)
    check(opened.ok and index.ok,label+": independent original and ordinary Studio index open")
    if not opened.ok or not index.ok:return
    var immutable:PackedByteArray=var_to_bytes([index.initialization,index.groups,index.rows])
    var lives:Array=index.rows.filter(func(row):return row.kind=="condition" and row.get("owner",{}).get("condition",{}).get("behavior_id")==ID)
    check(lives.size()==1,label+": exactly one actual size owner")
    if lives.size()!=1:return
    var owner:Dictionary=lives[0].owner
    check(not owner.initial and owner.condition.state.size_change==mode and is_finite(float(owner.end_ms)),label+": actual later admission/selector/removal, not an initial condition")
    var clip_id:String=("enlarge_reduce_reduce_native" if mode=="reduce" else "enlarge_reduce_native")+"/application"
    var at:float=owner.start_ms+360.0
    var during:RefCounted=Recording.restore(index,at)
    var native:Array=during.component_samples(index.cache).filter(func(sample):return sample.get("condition_uuid")==owner.id and sample.get("condition_authored",false))
    check(native.size()==1,label+": one matching finite application, no opposite-direction sibling")
    if native.size()==1:
        var sample:Dictionary=native[0]
        check(sample.source_id==clip_id and sample.start_ms==owner.start_ms and sample.absolute_start_ms==owner.start_ms and is_equal_approx(sample.duration_ms,720.0) and is_equal_approx(sample.native_cue.end,.72),label+": finite source uses actual owner start and original .72s window")
        check(not sample.native_cue.has("lifecycle") and is_equal_approx(sample.age_ms,360.0),label+": source advances through its finite frames instead of holding the first frame")
        var original_sample:PackedByteArray=var_to_bytes(sample)
        var initial:Dictionary=sample.duplicate();initial.initial=true
        check(Persistent.authored_samples(initial,index.cache).is_empty(),label+": labelled initial-owner control never invents an application")
        var unknown:Dictionary=sample.duplicate();unknown.condition=sample.condition.duplicate(true);unknown.condition.state.size_change=null
        check(Persistent.authored_samples(unknown,index.cache).is_empty(),label+": labelled missing-selector control cannot default to Enlarge")
        var expired:Dictionary=sample.duplicate();expired.age_ms=720.0
        check(Persistent.authored_samples(expired,index.cache).is_empty(),label+": application retires at its exact finite end while the condition remains")
        check(var_to_bytes(sample)==original_sample,label+": private controls leave the original source/member unchanged")
    var factor:float=.75 if mode=="reduce" else 1.175
    check(is_equal_approx(Conditions.material(owner.actor_uuid,during.component_samples(index.cache)).body_scale.factor,factor),label+": existing body adjustment still applies once")
    var later:RefCounted=Recording.restore(index,minf(owner.end_ms-.01,owner.start_ms+800.0))
    check(not later.component_samples(index.cache).any(func(sample):return sample.get("condition_uuid")==owner.id and sample.get("condition_authored",false)),label+": sustained condition does not replay the finite ring")
    var tracks:Array=index.rows.filter(func(row):return row.kind=="native_effect" and row.get("component",{}).get("condition_uuid")==owner.id and row.component.get("condition_authored",false))
    check(not tracks.is_empty() and tracks.all(func(row):return row.component.source_id==clip_id and row.label.begins_with("Application") and row.start_ms>=owner.start_ms and row.end_ms<=owner.start_ms+720.0),label+": Studio exposes only the finite application interval and correct source")
    check(index.groups.all(func(group):return not group.group.components.any(func(component):return component.get("native_spell",false) and component.get("spell_id")=="enlarge_reduce")),label+": original cast does not duplicate the condition-owned source")
    var before:RefCounted=Recording.restore(index,maxf(0.0,owner.start_ms-.01))
    check(not before.condition_owners.has(owner.id),label+": reverse seek before actual admission has no future owner")
    var looped:RefCounted=Recording.restore(index,at)
    check(looped.component_samples(index.cache).any(func(sample):return sample.get("condition_uuid")==owner.id and sample.get("condition_authored",false) and sample.source_id==clip_id and is_equal_approx(sample.age_ms,360.0)),label+": loop reconstructs the same actual application clock")
    var final:RefCounted=Recording.restore(index,index.presentation_end_ms+1000.0)
    check(final.state==expected.state and Conditions.material(owner.actor_uuid,final.component_samples(index.cache)).body_scale=={"factor":1.0,"owners":[]},label+": actual removal restores neutral scale and independent canonical endpoint")
    check(var_to_bytes([index.initialization,index.groups,index.rows])==immutable,label+": selection/seek never mutates original evidence")
