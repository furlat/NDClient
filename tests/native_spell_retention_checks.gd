extends SceneTree
const Fixtures=preload("res://tests/recording_fixtures.gd")
## Retention decisions on actual compiled recordings. No source construction,
## native rendering, playback cadence or authoritative state is changed here.
const Recording=preload("res://studio/recording.gd")
const Native=preload("res://presentation/native_spell_renderer.gd")
class World extends Node:
    var timeline:RefCounted
var checks=0
var failures:Array=[]
var cases:Array=[]
var timings:Dictionary={}

func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);printerr("NATIVE_RETENTION_FAIL ",label)

func reference(world:Node,handles:Dictionary)->Dictionary:
    var result:Dictionary={};var owners:Dictionary={}
    var queued:Array=world.timeline.queue.duplicate()
    if not world.timeline.current.is_empty():queued.append(world.timeline.current)
    for group in queued:
        for component in group.get("components",[]):
            if Native.accepts(component):result[component.id]=true
        for commit in group.get("commits",[]):
            for actor in commit.delta.get("actors",{}).values():
                for condition in actor.get("conditions",[]):owners[condition.condition_uuid]=true
            for id in commit.delta.get("set",{}).get("senses",{}).get("spatial_effects",{}):owners[id]=true
    for id in world.timeline.condition_owners:owners[id]=true
    for id in world.timeline.spatial_effect_owners:owners[id]=true
    for id in handles:
        var component:Dictionary=handles[id].component
        if owners.has(component.get("condition_uuid",component.get("spatial_effect_uuid"))):result[id]=true
    return result

func retained(handles:Dictionary,ids:Dictionary,active:Dictionary)->Array:
    return handles.keys().filter(func(id):return ids.has(id) or active.has(id))

func recording(path:String,label:String,benchmark:bool=false)->void:
    var index=Recording.read(path)
    check(index.ok,label+" actual recording admits")
    if not index.ok:return
    var world=World.new();var renderer=Native.new()
    var constructed:Dictionary={};var native_count=0;var persistent_count=0
    for item in index.groups:
        for component in item.group.get("components",[]):
            if Native.accepts(component):constructed[component.id]={"component":component};native_count+=1
    world.timeline=Recording.restore(index,0)
    if benchmark:
        var original:Array=[];var shortcut:Array=[]
        for repeat in 40:
            world.timeline.revision+=1
            var start:int=Time.get_ticks_usec();reference(world,{})
            original.append(Time.get_ticks_usec()-start)
            start=Time.get_ticks_usec();renderer._queued_ids(world)
            shortcut.append(Time.get_ticks_usec()-start)
        original.sort();shortcut.sort()
        timings={"case":label,"iterations":40,"queued_groups":world.timeline.queue.size(),
            "original_scan_median_us":original[20],"empty_handle_median_us":shortcut[20],
            "original_scan_max_us":original.back(),"empty_handle_max_us":shortcut.back(),
            "scope":"Headless isolated retention calls; not a native frame-time measurement."}
    # Gather actual condition/area samples as well as transient source phases.
    var moments:Array=[0.0]
    for item in index.groups:
        moments.append(item.start_ms+item.group.duration_ms*.5)
        moments.append(item.start_ms+item.group.duration_ms+.001)
    var states:Array=[]
    for at in moments:
        var timeline=Recording.restore(index,at)
        var active:Dictionary={}
        for component in timeline.component_samples(index.cache):
            if not Native.accepts(component):continue
            active[component.id]=component
            if component.get("persistent_owner",false):
                constructed[component.id]={"component":component};persistent_count+=1
        states.append({"timeline":timeline,"active":active})
    for sample in states:
        world.timeline=sample.timeline
        var before_owners:Dictionary=world.timeline.condition_owners.duplicate(true)
        var before_areas:Dictionary=world.timeline.spatial_effect_owners.duplicate(true)
        renderer.handles={}
        check(retained(renderer.handles,renderer._queued_ids(world),sample.active)==retained(renderer.handles,reference(world,{}),sample.active),
            label+" empty native ownership retains exactly no constructed instances")
        renderer.handles=constructed.duplicate()
        var expected:Dictionary=reference(world,renderer.handles)
        check(retained(renderer.handles,renderer._queued_ids(world),sample.active)==retained(renderer.handles,expected,sample.active),label+" first constructed instances retain exact queued/current/persistent owners")
        check(retained(renderer.handles,renderer._queued_ids(world),sample.active)==retained(renderer.handles,expected,sample.active),label+" unchanged owners preserve cached retention decisions")
        var id:String=str(renderer.handles.keys()[0]) if not renderer.handles.is_empty() else ""
        if not id.is_empty():
            renderer.handles.erase(id)
            check(retained(renderer.handles,renderer._queued_ids(world),sample.active)==retained(renderer.handles,reference(world,renderer.handles),sample.active),label+" removing an instance preserves all remaining ownership")
        # The live prefetch owns only a few near-future instances. Check these
        # subsets too, including stale past instances and persistent owners.
        var ids:Array=constructed.keys()
        for first in [0,maxi(0,ids.size()/2),maxi(0,ids.size()-3)]:
            renderer.handles={}
            for selected in ids.slice(first,first+3):renderer.handles[selected]=constructed[selected]
            check(retained(renderer.handles,renderer._queued_ids(world),sample.active)==retained(renderer.handles,reference(world,renderer.handles),sample.active),label+" bounded prefetch retains/frees exact original instances")
        check(before_owners==world.timeline.condition_owners and before_areas==world.timeline.spatial_effect_owners,
            label+" retention never mutates canonical condition/area ownership")
    cases.append({"case":label,"moments":states.size(),"native_phases":native_count,"persistent_samples":persistent_count})
    # These are passive handle records, deliberately without native roots.
    renderer.handles.clear();renderer.close();world.free()

func run()->void:
    recording(Fixtures.journal("gallery"),"Gallery",true)
    for name in ["shield","web"]:
        for seat in ["amber","blue"]:recording(Fixtures.journal(name,seat),name+"/"+seat)
    var report={"checks":checks,"failures":failures,"cases":cases,"timings":timings,
        "scope":"Unchanged transient, current, queued, condition and spatial-owner retention on actual recordings; zero-instance work shortcut. No source/art/cadence change or GPU performance claim."}
    FileAccess.open("res://generated/native_spell_retention_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("NATIVE_RETENTION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
