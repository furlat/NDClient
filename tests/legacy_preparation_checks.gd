extends SceneTree
## Actual recorded class source; renderer publication contract, not pixel parity.
const Recording=preload("res://studio/recording.gd")
const Renderer=preload("res://presentation/component_renderer.gd")
const Profile=preload("res://frame_profile.gd")
class NativeStub extends RefCounted:
    var ready=true
    var issues:Array=[]
    var witnesses:Array=[]
    func prepare(_groups:Array,_cache:Dictionary,_world:Node,_future:Array,_budget:Dictionary,_optional:bool,_optical:Array)->Dictionary:return {"ready":true,"errors":[]}
    func sample(_world:Node,_samples:Array,_seconds:float)->void:pass
    func close(_world:Node)->void:pass
class HitsStub extends RefCounted:
    var ready=true
    var issues:Array=[]
    func prepare(_world:Node,_samples:Array,_cache:Dictionary,_future:Array,_budget:Dictionary,_optional:bool)->Dictionary:return {"ready":true,"issues":[]}
    func close()->void:pass
class BloodStub extends RefCounted:
    var ready=true
    var deposit_create_usec=0
    var light_page_create_usec=0
    var sample_phases:Dictionary={}
    func prepare(_world:Node,_groups:Array,_budget:Dictionary)->bool:return true
    func sample(_world:Node,_samples:Array,_changes:Dictionary)->void:pass
    func close(_world:Node)->void:pass
class World extends Node3D:
    var timeline:RefCounted
    var profile=Profile.create()
    var source_lighting:RefCounted
    var visual_actors:Dictionary={}
    var actor_entries:Array=[]
    var catalog_cache:Dictionary={}
    var presentation_errors:Array=[]
    var draw_order_dirty=false
    var world_changes:Dictionary={}
    var camera:Camera3D
    var playback_speed=1.0
    var light_cap_enabled=false
    var light_cap=1.0
var checks=0
var failures:Array=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr(label)
func budget()->Dictionary:return {"frame":Engine.get_process_frames(),"used_usec":0,"limit_usec":1000000}
func run()->void:
    var index=Recording.read("res://.runtime/studio-cases/action_economy-seed3-v2/amber/journal")
    check(index.ok,"Actual class action recording admits")
    if not index.ok:quit(1);return
    var component:Dictionary={}
    for item in index.groups:
        for row in item.group.components:
            if row.kind=="native_effect" and not row.get("native_spell",false) and not row.has("weapon_pose"):component=row.duplicate();break
        if not component.is_empty():break
    check(not component.is_empty(),"Actual recording supplies a selected legacy native source")
    if component.is_empty():quit(1);return
    # Keep the real source, seed and palette; only cue/placement make the
    # renderer boundary independent of actor mesh and display-driver tests.
    component.start_ms=100.0;component.duration_ms=500.0
    component.attachment="ground";component.position=[0,0]
    var group={"id":"legacy-publication","components":[component],"duration_ms":700.0,"commits":[]}
    var world=World.new();root.add_child(world)
    world.camera=Camera3D.new();world.add_child(world.camera)
    world.camera.position=Vector3(0,4,8);world.camera.look_at(Vector3.ZERO)
    world.timeline=Recording.restore(index,0.0);world.timeline.current=group
    world.timeline.queue=[];world.timeline.group_start_ms=0.0;world.timeline.display_ms=0.0
    world.timeline.state.tiles["0,0"]={"elevation_steps":0}
    world.catalog_cache=index.cache
    var record=Renderer.NativeSources.source_record(component.source_id,world.catalog_cache)
    # Synchronous fixture setup isolates the preparation/publication contract;
    # global threaded loading and draw fences have their own native suite.
    for path in record.get("preload_paths",[record.get("script",record.get("scene",""))]):world.catalog_cache[path]=load(path)
    var renderer=Renderer.new();renderer.native_spells=NativeStub.new();renderer.native_hits=HitsStub.new();renderer.blood=BloodStub.new()
    renderer.epoch=world.timeline.initialization_revision
    var saved=world.timeline.state.duplicate(true)
    var early=renderer.prepare([group],world.catalog_cache,world,budget(),false,99.0)
    check(early.ready and renderer.handles.is_empty(),"Not-yet-due class cue needs no presenter")
    var charge=budget()
    var due=renderer.prepare([group],world.catalog_cache,world,charge,false,100.0)
    check(due.ready and renderer.handles.has(component.id),"Due preparation owns the complete hidden presenter")
    check(world.actor_entries.is_empty() and not world.draw_order_dirty,"Preparation publishes no draw membership")
    check(world.timeline.state==saved and world.timeline.display_ms==0.0,"Preparation changes no displayed state or time")
    if renderer.handles.has(component.id):
        var presenter=renderer.handles[component.id].node
        check(presenter.sampled_age<0 and presenter.requested_age<0,"Prepared source has no simulated or drawn age")
        check(not presenter.is_visible_in_tree(),"Prepared presenter stays hidden")
        check(charge.get("required_legacy_constructors",0)==1,"Construction is charged to preparation")
        renderer.sample(world,[])
        check(renderer.handles.has(component.id),"Old displayed frame does not retire an unpublished due presenter")
        var again=budget();renderer.prepare([group],world.catalog_cache,world,again,false,100.0)
        check(renderer.handles[component.id].node==presenter and again.get("required_legacy_constructors",0)==0,"Retry retains its prepared instance without reconstruction")
        world.timeline.display_ms=125.0
        var sample=component.duplicate();sample.age_ms=25.0;sample.absolute_start_ms=100.0
        var sample_budget=budget();renderer.sample(world,[sample],1.0/60.0,sample_budget)
        check(not world.actor_entries.is_empty() and presenter.is_visible_in_tree(),"Displayed cue publishes prepared draw membership")
        check(is_equal_approx(presenter.requested_age,Renderer.NativeSources.source_age_ms(sample,25.0)/1000.0),"First published sample uses the original source age")
        check(sample_budget.get("required_legacy_constructors",0)==0,"Publication performs no legacy constructor")
        renderer.sample(world,[])
        check(renderer.handles.is_empty() and world.actor_entries.is_empty(),"Displayed retirement releases the occurrence and membership")
        renderer.prepare([group],world.catalog_cache,world,budget(),false,100.0)
        world.timeline.current={}
        renderer.prepare([],world.catalog_cache,world,budget(),false,125.0)
        check(renderer.handles.is_empty(),"Cancelled unpublished cue releases its private presenter")
    check(world.presentation_errors.is_empty(),"Recorded class source has no presentation errors")
    renderer.close(world);world.queue_free();await process_frame
    print("LEGACY_PREPARATION ",JSON.stringify({"checks":checks,"failures":failures,"scope":"Real recorded class source and renderer publication; headless, no pixel or frame-budget qualification."}))
    quit(0 if failures.is_empty() else 1)
