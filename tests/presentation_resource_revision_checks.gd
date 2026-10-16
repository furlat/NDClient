extends SceneTree
## Resource preparation follows changed owners, independently of canonical time.
const Timeline=preload("res://presentation/timeline.gd")
const Renderer=preload("res://presentation/component_renderer.gd")
const Profile=preload("res://frame_profile.gd")
var checks:int=0
var failures:Array=[]

class Host extends Node:
    var timeline:RefCounted
    var component_renderer:RefCounted=Renderer.new()
    var profile:Dictionary=Profile.create()
    var quarter:int=0
    var native_spell_hit_material:bool=true

func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);printerr("RESOURCE_REVISION_FAIL ",label)

func observe(timeline:RefCounted,actor:Dictionary,at_ms:float)->void:
    timeline._observe_resource_owners({"actors":{"actor":actor}},at_ms)

func run()->void:
    var timeline=Timeline.new()
    timeline.state={"actors":{},"senses":{"spatial_effects":{}},"tiles":{},"objects":{}}
    var actor={"life_state":"alive","conditions":[]}
    observe(timeline,actor,0)
    check(timeline.resource_revision==0,"An ordinary actor does not own condition resources")
    var condition={"condition_uuid":"hidden","behavior_id":"condition.hidden","state":null}
    actor.conditions=[condition];observe(timeline,actor,10)
    check(timeline.resource_revision==1,"Condition admission changes the resource owner")
    var after:Dictionary=actor.duplicate();after.hp=5;after.position=[3,4]
    observe(timeline,after,20)
    check(timeline.resource_revision==1,"HP and position after-values retain unchanged condition resources")
    var updated:Dictionary=condition.duplicate();updated.state={"suppression_provider_uuids":["source"]}
    after.conditions=[updated];observe(timeline,after,30)
    check(timeline.resource_revision==2 and is_same(timeline.condition_owners.hidden.condition,updated),
        "Changed condition state invalidates preparation and retains its authoritative after-value")
    after.life_state="dead";observe(timeline,after,40)
    check(timeline.resource_revision==3,"Life state updates condition layer resources")
    after.conditions=[];observe(timeline,after,50)
    check(timeline.resource_revision==4 and timeline.condition_owners.hidden.end_ms==50,"Removal publishes its exact owner end clock")
    observe(timeline,after,60)
    check(timeline.resource_revision==4 and timeline.condition_owners.hidden.end_ms==50,"Repeated absent observation does not restart removal")
    after.conditions=[updated];observe(timeline,after,70)
    check(timeline.resource_revision==5 and is_inf(timeline.condition_owners.hidden.end_ms),"Same-reference reactivation invalidates finite removal")
    var effect={"positions":[[1,2]],"suppressions":[],"anchor_elevation_steps":0}
    timeline.state.senses.spatial_effects={"area":effect}
    timeline._observe_resource_owners({"set":{"senses":timeline.state.senses}},80)
    check(timeline.resource_revision==6,"A spatial effect owns a new resource input")
    timeline._observe_resource_owners({"set":{"senses":timeline.state.senses}},90)
    check(timeline.resource_revision==6,"Contact-only sensory commits keep exact optical effect resources")
    var moved:Dictionary=effect.duplicate();moved.positions=[[2,3]]
    timeline.state.senses.spatial_effects.area=moved
    timeline._observe_resource_owners({"set":{"senses":timeline.state.senses}},100)
    check(timeline.resource_revision==7,"Spatial footprint changes invalidate their resource input")
    timeline.state.senses.spatial_effects={}
    timeline._observe_resource_owners({"set":{"senses":timeline.state.senses}},110)
    check(timeline.resource_revision==8 and timeline.spatial_effect_owners.area.end_ms==110,"Spatial removal retains the exact end clock")
    timeline._observe_resource_owners({"set":{"senses":timeline.state.senses}},120)
    check(timeline.resource_revision==8,"Repeated spatial absence keeps settled resource ownership")
    timeline.state.senses.spatial_effects={"area":moved}
    timeline._observe_resource_owners({"set":{"senses":timeline.state.senses}},130)
    check(timeline.resource_revision==9 and is_inf(timeline.spatial_effect_owners.area.end_ms),"Spatial reactivation is an actual owner transition")

    var host=Host.new();root.add_child(host)
    host.timeline=timeline
    var renderer:RefCounted=host.component_renderer
    var scope:Array=renderer._resource_scope(host)
    timeline.revision+=1
    check(renderer._resource_scope(host)==scope,"An unrelated canonical revision reuses allocated presenters")
    timeline.resource_revision+=1
    check(renderer._resource_scope(host)!=scope,"Actual resource changes invalidate presenter readiness")
    scope=renderer._resource_scope(host);renderer.invalidate_preparation()
    check(renderer._resource_scope(host)!=scope,"Published world/actor membership retains its resource gate")
    scope=renderer._resource_scope(host);renderer.native_spells.preparation_revision+=1
    check(renderer._resource_scope(host)!=scope,"Native source completion retains its resource gate")
    scope=renderer._resource_scope(host);host.quarter=1
    check(renderer._resource_scope(host)!=scope,"Camera view changes retain their resource gate")
    scope=renderer._resource_scope(host);host.native_spell_hit_material=not host.native_spell_hit_material
    check(renderer._resource_scope(host)!=scope,"Material treatment changes retain their resource gate")
    renderer._optional_owner=[timeline.initialization_revision,timeline.resource_revision,timeline.group_start_ms,timeline.current,timeline.queue.duplicate()]
    timeline.revision+=1;host.profile.phases.clear()
    var allowance={"frame":Engine.get_process_frames(),"used_usec":0,"limit_usec":2000}
    renderer.prepare_optional(host,{},allowance)
    check(host.profile.phases.has("component_prepare_prefetch"),"Canonical-only progress keeps accepted future resource preparation running")
    timeline.resource_revision+=1;host.profile.phases.clear()
    renderer.prepare_optional(host,{},allowance)
    check(not host.profile.phases.has("component_prepare_prefetch"),"Changed resource ownership rejects an obsolete optional closure")
    timeline.condition_owners={};timeline.spatial_effect_owners={}
    timeline.current={"components":[{"id":"tail","kind":"feedback_text","start_ms":0.0,"duration_ms":100.0}]}
    timeline.display_ms=20;timeline.group_start_ms=0
    var resource_before:int=timeline.resource_revision
    timeline._retain_completed_presentation()
    check(timeline.retained_components.size()==1 and timeline.resource_revision>resource_before,"Retained presentation membership invalidates resources")
    timeline.current={};timeline.display_ms=100
    resource_before=timeline.resource_revision
    timeline.component_samples()
    check(timeline.retained_components.is_empty() and timeline.resource_revision==resource_before+1,"Tail expiry retires resource membership once")
    timeline.component_samples()
    check(timeline.resource_revision==resource_before+1,"Settled expiry does not invalidate every sample")
    renderer.audio.close();host.free()
    var report={"checks":checks,"failures":failures,"scope":"Actual immutable condition/spatial owners, removal/reactivation, canonical-vs-resource scope, native/member/view/material gates and retained-tail expiry."}
    FileAccess.open("res://.runtime/presentation-resource-revision-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("PRESENTATION_RESOURCE_REVISION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
