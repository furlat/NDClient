extends SceneTree
## Real component identities, passive stand-ins for already-created native
## resources. Rendering/source pixels are qualified by the native suites.
const Recording=preload("res://studio/recording.gd")
const Native=preload("res://presentation/native_spell_renderer.gd")
const Hits=preload("res://presentation/native_spell_hits.gd")
const Admission=preload("res://presentation/native_source_admission.gd")
const Profile=preload("res://frame_profile.gd")
class Lighting extends RefCounted:
    func sample_handles(_handles:Dictionary)->void:pass
class World extends Node3D:
    var timeline:RefCounted
    var camera:Camera3D
    var profile:Dictionary=Profile.create()
    var source_lighting=Lighting.new()
    var visual_actors:Dictionary={}
    var playbacks:Dictionary={}
    var catalog_cache:Dictionary={}
var checks:int=0
var failures:Array=[]
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);printerr(label)
func run()->void:
    var index=Recording.read("res://.runtime/gallery-sorcerer-20261015-seed3-door/amber/journal")
    check(index.ok,"Actual Gallery source recording admits")
    if not index.ok:quit(1);return
    var world=World.new();root.add_child(world)
    world.camera=Camera3D.new();world.add_child(world.camera)
    world.camera.position=Vector3(5,5,5);world.camera.look_at(Vector3.ZERO)
    world.timeline=Recording.restore(index,0.0)
    var native_component:Dictionary={};var hit_component:Dictionary={}
    for item in index.groups:
        for component in item.group.components:
            if native_component.is_empty() and Native.accepts(component):native_component=component
            if hit_component.is_empty() and component.has("native_hit"):hit_component=component
    check(not native_component.is_empty() and not hit_component.is_empty(),"Actual recorded spell and applied hit provide ownership identities")
    var native=Native.new();var hits=Hits.new()
    var rows:Array=[{"components":[native_component]}]
    var budget={"used_usec":2000,"limit_usec":2000}
    var canonical:Dictionary=world.timeline.state.duplicate(true)
    var loads_before:int=Admission.loads_started
    var result=native.prepare(rows,index.cache,world,[],budget)
    check(not result.ready and native.handles.is_empty() and native.required_images.is_empty(),"Missing required source remains pending when the shared admission allowance is exhausted")
    check(Admission.loads_started==loads_before and native._resource_cache.is_empty(),"Spent allowance does not enter Factory preparation or request a new source resource")
    var hit_cache:Dictionary={}
    result=hits.prepare(world,[hit_component],hit_cache,[],budget)
    check(not result.ready and hits.records.is_empty() and hit_cache.is_empty() and Admission.loads_started==loads_before,
        "Missing required hit remains pending without resource admission or a private material constructor")
    result=native.prepare([],index.cache,world,rows,budget)
    check(result.ready and native.handles.is_empty() and native.required_images.is_empty(),"Unprepared optional source cannot block current readiness or acquire image pins when frame budget is spent")
    var source=Node3D.new();source.hide();native._owner.add_child(source)
    var prepared={"root":source,"component":native_component}
    native.handles[native_component.id]=prepared
    result=native.prepare([],index.cache,world,rows,budget,false)
    check(result.ready and is_same(native.handles[native_component.id],prepared) and not source.visible,"Required-only pass retains a hidden prepared future source")
    # A different owner can be loading a future shader resource while this
    # already constructed occurrence becomes current. That is not a reason to
    # pause playback or replace the existing instance.
    var future_path:String="res://.runtime/native-prefetch-future.tres"
    FileAccess.open(future_path,FileAccess.WRITE).store_string('[gd_resource type="Resource" format=3]\n[resource]\nresource_name = "future admission"\n')
    var future_cache:Dictionary={}
    Admission.prepare([future_path],future_cache)
    check(not Admission.loading_path.is_empty(),"Future owner starts one real asynchronous resource load")
    check(Native.Effects.prepare([],{}).ready,"Empty current constructor demand stays ready during an unrelated load")
    result=native.prepare(rows,index.cache,world,[],budget)
    check(result.ready and is_same(native.handles[native_component.id],prepared),"Promotion to required reuses the same source instance without another constructor")
    native.sample(world,[],0.0)
    check(native.handles.has(native_component.id) and is_instance_valid(source),"Received queue retains the prepared source across an inactive frame")
    result=hits.prepare(world,[],{},[hit_component],budget)
    check(result.ready and hits.records.is_empty(),"Optional hit preparation cannot block current group or bypass spent shared allowance")
    var viewport=SubViewport.new();world.add_child(viewport)
    var surface={"viewport":viewport,"ready":true,"closed":false}
    var record={"surface":surface};var key=Hits._key(hit_component)
    hits.records[key]=record
    result=hits.prepare(world,[],{},[hit_component],budget,false)
    check(result.ready and is_same(hits.records[key],record),"Required-only hit pass retains its admitted optional surface")
    result=hits.prepare(world,[hit_component],{},[],budget)
    check(result.ready and is_same(hits.records[key],record),"Required hit promotion reuses the same private surface")
    hits.active[key]=true
    hits.prepare(world,[],{},[],budget)
    check(hits.records.has(key) and not surface.closed,"Still-active hit survives leaving the preparation window")
    hits.active.clear();hits.prepare(world,[],{},[],budget)
    check(not hits.records.has(key) and surface.closed and viewport.is_queued_for_deletion(),"Cancelled inactive hit releases exactly its own surface")
    check(world.timeline.state==canonical,"Preparation and promotion preserve canonical reducer state")
    # Explicit cancellation removes received ownership; no event is simulated.
    world.timeline.queue=[];world.timeline.current={};world.timeline.condition_owners={};world.timeline.spatial_effect_owners={};world.timeline.revision+=1
    native.sample(world,[],0.0)
    check(native.handles.is_empty() and not is_instance_valid(source),"Cancelled received owner retires its prepared source on normal sampling")
    native.close(world);hits.close();world.queue_free()
    while not Admission.loading_path.is_empty():
        Admission.prepare([],future_cache)
        await process_frame
    await process_frame;await process_frame
    var report={"checks":checks,"failures":failures,"native_id":native_component.id,"hit_id":hit_component.id,"scope":"Actual recording occurrence IDs through required/optional preparation, promotion and cancellation; passive preconstructed resource ownership, no native-pixel claim."}
    FileAccess.open("res://.runtime/native-prefetch-ownership-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("NATIVE_PREFETCH_OWNERSHIP ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
