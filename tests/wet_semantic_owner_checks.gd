extends SceneTree
## Real null-behavior Wet admission/hold. Retirement and alternate-key values
## below are explicitly private controls, never claimed as recorded events.
const Catalog=preload("res://source_catalog.gd")
const Conditions=preload("res://presentation/conditions.gd")
const Persistent=preload("res://presentation/native_persistent.gd")
const Recording=preload("res://studio/recording.gd")
const Journal=preload("res://sdk/journal.gd")
const Compare=preload("res://tests/schema16_fold_vectors_checks.gd")
const Build=preload("res://tools/presentation_build/abilities.gd")
const Common=preload("res://tools/presentation_build/common.gd")
const Effects=preload("res://presentation/effect_package.gd")
const KEY="unbound:dnd.spatial.environmental_conditions.Wet"
const OWNER="dede53e7-00f4-44ab-a4b1-e9a7bbf785e3"
const ACTOR="c1f08c54-c62e-451b-a532-92c3527a52f1"
const CLIP="bg3-36/create-or-destroy-water/rain-wet"
const ROOT="res://tests/fixtures/schema16/water-source-provider/"
var checks:int=0
var failures:Array=[]
var evidence:Array=[]
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);printerr("WET_SEMANTIC_OWNER_FAIL ",label)
func run()->void:
    constructor_controls()
    resolver_controls()
    for seat in ["amber","blue"]:original(seat)
    print("WET_SEMANTIC_OWNERS ",JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence,
        "scope":"Actual null-behavior Wet source/UUID ownership and canonical Studio admission/hold; no original removal, native pixels or visual acceptance claim."}))
    quit(0 if failures.is_empty() else 1)
func constructor_controls()->void:
    var source:Resource=load("res://authoring/abilities/conditions/semantic.wet.tres")
    var use:Resource=source.effects[0]
    var original:PackedByteArray=var_to_bytes([use.extra,use.at,use.delay,use.role])
    var clips:Dictionary={CLIP:Effects.clip(CLIP)}
    var where:String="abilities/conditions/"+KEY
    var report:Dictionary=Common.report()
    Build._check_constructor(use,where,clips,report)
    check(report.errors.is_empty(),"Actual production Wet declaration passes the offline constructor policy")
    for invalid in ["recipient_geometry","unknown_boolean_input"]:
        var changed:Resource=use.duplicate(true)
        changed.extra=use.extra.duplicate(true);changed.extra.membership_input=invalid
        report=Common.report();Build._check_constructor(changed,where,clips,report)
        check(not report.errors.is_empty(),"Offline membership policy rejects a non-boolean or undeclared input: "+invalid)
    report=Common.report()
    Build._check_constructor(use,"abilities/spells/spell.create_or_destroy_water",clips,report)
    check(not report.errors.is_empty(),"A finite spell cannot claim the actual condition membership clock")
    var delayed:Resource=use.duplicate(true);delayed.delay=.1
    report=Common.report();Build._check_constructor(delayed,where,clips,report)
    check(not report.errors.is_empty(),"Offline membership policy rejects a delayed condition setter")
    var released:Resource=use.duplicate(true);released.at="release"
    report=Common.report();Build._check_constructor(released,where,clips,report)
    check(not report.errors.is_empty(),"Offline membership policy requires owner_start rather than spell release")
    check(var_to_bytes([use.extra,use.at,use.delay,use.role])==original,"Offline negative controls preserve the actual shared Wet effect")
func resolver_controls()->void:
    var cache:Dictionary={}
    check(Catalog.condition_key({"behavior_id":null,"state":{"semantic_key":KEY}})==KEY,"Exact public semantic key is retained for a null behavior")
    check(Catalog.condition_key({"behavior_id":"condition.poisoned","state":{"semantic_key":KEY}})=="condition.poisoned","Non-null behavior takes precedence over a different semantic key")
    check(Catalog.condition_key({"behavior_id":"","state":{"semantic_key":KEY}})=="","Even an empty non-null behavior is preserved verbatim")
    check(Catalog.condition_key({"behavior_id":null,"state":null})=="" and Catalog.condition_key({}).is_empty(),"Absent semantic identity remains absent")
    var unknown:String="private:unrecognized-null-behavior"
    check(Catalog.condition_key({"behavior_id":null,"state":{"semantic_key":unknown}})==unknown,"Unknown public semantic identity is not renamed by resemblance")
    check(Conditions.recipe({"behavior_id":null,"state":{"semantic_key":unknown}},cache).is_empty(),"Unknown null-behavior source cannot borrow Wet's recipe")
    var wet:Dictionary=Conditions.recipe({"behavior_id":null,"state":{"semantic_key":KEY}},cache)
    check(not wet.is_empty() and wet.get("persistent",{}).get("nativeEffects",[]).size()==1,"Actual production build has one exact authored semantic source")
func original(seat:String)->void:
    var directory:String=ROOT+seat+"/journal"
    var expected:RefCounted=Journal.new();var opened:Dictionary=expected.open(directory,true,true)
    check(opened.ok,seat+" original SDK journal independently folds")
    if not opened.ok:return
    var original_state:PackedByteArray=var_to_bytes(expected.state)
    var member:Dictionary={}
    for actor in expected.state.actors.values():
        for condition in actor.get("conditions",[]):
            if condition.condition_uuid==OWNER:member=condition
    check(not member.is_empty(),seat+" original actual Wet UUID is still admitted at the final cursor")
    if member.is_empty():return
    check(member.behavior_id==null and member.state.semantic_key==KEY and member.condition_uuid==OWNER,
        seat+" authoring resolution does not rewrite behavior, semantic key or condition UUID")
    var index:Dictionary=Recording.read(directory)
    check(index.ok,seat+" ordinary Studio compiles the original recording")
    if not index.ok:return
    var immutable:PackedByteArray=var_to_bytes([index.initialization,index.groups,index.rows])
    var rows:Array=index.rows.filter(func(row):return row.kind=="native_effect" \
        and row.get("component",{}).get("condition_uuid")==OWNER \
        and row.component.get("native_clip",{}).get("id")==CLIP)
    check(not rows.is_empty(),seat+" real Wet membership has a native Studio hold track")
    if rows.is_empty():return
    var identities:Dictionary={}
    for row in rows:
        var component:Dictionary=row.component;identities[component.id]=true
        check(row.owner.id==OWNER and component.actor_uuid==ACTOR and component.target_uuid==ACTOR \
            and component.condition_uuid==OWNER and component.condition.behavior_id==null,
            seat+" actual UUID and recipient own every native track, not an invented condition ID")
        check(component.persistent_owner and component.condition_authored and component.native_inputs.wet_presence==true,
            seat+" admitted original lifetime supplies true wet_presence")
        check(component.native_cue.entity_geometry.actor=="target" and component.native_cue.membership_input=="wet_presence",
            seat+" runoff receives the actual recipient geometry and authored setter")
        check(row.coverage.rendered=="not_witnessed" and row.coverage.prepared=="not_examined",
            seat+" source/track coverage is not presented as native output proof")
    check(identities.size()==1,seat+" split inspection spans retain one actual Wet occurrence")
    var first:Dictionary=rows[0]
    var at:float=minf(first.end_ms-.01,first.start_ms+100.0)
    var restored:RefCounted=Recording.restore(index,at)
    var samples:Array=restored.component_samples(index.cache).filter(func(row):return row.get("condition_uuid")==OWNER \
        and row.get("native_clip",{}).get("id")==CLIP)
    check(samples.size()==1 and samples[0].native_inputs.wet_presence==true,
        seat+" seek into actual admitted hold restores the same single true membership")
    if not samples.is_empty():private_controls(samples[0],index.cache,seat)
    var before:RefCounted=Recording.restore(index,maxf(0.0,first.start_ms-.01))
    check(not before.condition_owners.has(OWNER),seat+" pre-admission seek cannot publish the future Wet owner")
    var final:RefCounted=Recording.restore(index,index.presentation_end_ms+1000.0)
    check(Compare.difference(final.state,expected.state).is_empty(),seat+" final replay equals the original independent canonical fold")
    check(final.condition_owners.has(OWNER) and is_inf(final.condition_owners[OWNER].end_ms),
        seat+" this original has no Wet retirement and none is inferred")
    check(var_to_bytes(expected.state)==original_state and var_to_bytes([index.initialization,index.groups,index.rows])==immutable,
        seat+" source selection, controls and seek preserve original canonical/indexed data")
    evidence.append({"seat":seat,"condition_uuid":OWNER,"actor_uuid":ACTOR,"semantic_key":KEY,"native_source":CLIP,
        "original_removal":false,"track_spans":rows.size()})
func private_controls(sample:Dictionary,cache:Dictionary,seat:String)->void:
    var original:PackedByteArray=var_to_bytes(sample)
    var local_cache:Dictionary=cache.duplicate()
    var retired:Dictionary=sample.duplicate();retired.removal_age_ms=0.0
    var closed:Array=Persistent.authored_samples(retired,local_cache)
    check(closed.size()==1 and closed[0].condition_uuid==OWNER and closed[0].native_inputs.wet_presence==false,
        seat+" private retirement projection supplies false for the same UUID without an invented removal event")
    var alternate:Dictionary=sample.duplicate()
    alternate.condition=sample.condition.duplicate(true)
    alternate.condition.state.semantic_key="private:independent-null-behavior-source"
    alternate.recipe=sample.recipe.duplicate()
    alternate.recipe._resource_source="private:null-behavior-source-B"
    alternate.source="private:null-behavior-source-B"
    var other:Array=Persistent.authored_samples(alternate,local_cache)
    check(local_cache.has("condition-native:"+KEY) and local_cache.has("condition-native:"+alternate.condition.state.semantic_key),
        seat+" two labelled private null-behavior operands retain separate immutable source cache keys")
    check(other.size()==1 and other[0].source!=sample.source and other[0].source.begins_with("private:null-behavior-source-B"),
        seat+" another null-behavior source cannot reuse Wet's cached provenance")
    check(var_to_bytes(sample)==original,seat+" private retirement/source-key controls leave the real sample unchanged")
