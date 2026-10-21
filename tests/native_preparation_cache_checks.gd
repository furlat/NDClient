extends SceneTree
const Recording=preload("res://studio/recording.gd")
const Renderer=preload("res://presentation/component_renderer.gd")
const Native=preload("res://presentation/native_spell_renderer.gd")
const Conditions=preload("res://presentation/conditions.gd")
const Profile=preload("res://frame_profile.gd")
const Fixtures=preload("res://tests/recording_fixtures.gd")
class Spy extends RefCounted:
    var preparation_revision:int=0
    var components:Array=[]
    var optional:Array=[]
    var blocked:Dictionary={}
    func prepare(groups:Array,_cache:Dictionary,_world:Node=null,_prefetch:Array=[],_budget:Dictionary={},_allow_optional:bool=true,_optical:Array=[])->Dictionary:
        components=[]
        for group in groups:components.append_array(group.get("components",[]))
        optional=[]
        for group in _prefetch:optional.append_array(group.get("components",[]))
        return {"ready":not components.any(func(component):return blocked.has(component.id)),"errors":[]}
class HitSpy extends RefCounted:
    func prepare(_world:Node,_components:Array,_cache:Dictionary,_prefetch:Array=[],_budget:Dictionary={},_allow_optional:bool=true)->Dictionary:return {"ready":true,"issues":[]}
class BloodSpy extends RefCounted:
    var deposit_create_usec:int=0
    var light_page_create_usec:int=0
    var blocked:Dictionary={}
    var requested:Dictionary={}
    func prepare(_world:Node,_groups:Array,_budget:Dictionary={})->bool:
        var ready:bool=true
        for group in _groups:
            var id:String=group.get("id","")
            requested[id]=true
            if blocked.has(id):ready=false
        return ready
class World extends "res://play.gd":
    func _ready()->void:
        set_process(false);set_process_unhandled_input(false)
        camera=Camera3D.new();add_child(camera);add_child(context_menu)
        rig_config=Characters._read("catalog/rig.json",catalog_cache)
class Playback extends Node:
    var clip:String="Idle"
var checks=0
var failures:Array=[]
var owner_cases:Array=[]
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);printerr(label)
func reference(groups:Array,timeline:RefCounted,cache:Dictionary)->Array:
    var native_groups:Array=groups.duplicate()
    for group in [timeline.current]:
        if not group.is_empty() and not native_groups.any(func(item):return item.get("id")==group.id):native_groups.append(group)
    var retained:Array=timeline.retained_components.map(func(item):return item.component)
    if not retained.is_empty():native_groups.append({"components":retained})
    var owners=timeline.condition_owners.duplicate(true)
    var areas=timeline.spatial_effect_owners.duplicate(true)
    var result:Array=Conditions.samples(owners,timeline.display_ms,cache)
    result.append_array(Conditions.NativePersistent.spatial_samples(areas,timeline.display_ms,cache))
    var at:float=timeline.group_start_ms
    for group in native_groups:
        at=maxf(at,float(group.get("preview_start_ms",at)))
        for commit in group.get("commits",[]):
            Conditions.observe(owners,commit.delta.get("actors",{}),at+commit.at_ms)
            if commit.delta.get("set",{}).has("senses"):Conditions.NativePersistent.observe_spatial(areas,commit.delta.set.senses.get("spatial_effects",{}),at+commit.at_ms)
            result.append_array(Conditions.samples(owners,at+commit.at_ms,cache))
            result.append_array(Conditions.NativePersistent.spatial_samples(areas,at+commit.at_ms,cache))
        at+=group.get("duration_ms",0.0)
    for group in native_groups:result.append_array(group.get("components",[]))
    return result
func inputs(components:Array)->Dictionary:
    var result={}
    for component in components:
        if component.get("native_spell",false):
            var cue:Dictionary=component.get("native_cue",{}).duplicate()
            cue.erase("initial");cue.erase("owner_end_seconds")
            result[component.id]=[component.native_clip,component.get("cast_recipe",{}),component.get("actor_uuid"),component.get("target_uuid"),cue,component.get("optical",{}),component.get("finish_profile",{}),component.get("resolved_area_positions",[])]
        elif component.has("native_hit"):result[component.id]=component.native_hit
    return result

func scheduled_admission(index:Dictionary)->void:
    var cases=0
    for item in index.groups:
        var later:Array=item.group.get("components",[]).filter(func(component):return component.get("native_spell",false) and component.start_ms>20 and component.get("status")=="available")
        if later.is_empty():continue
        later.sort_custom(func(a,b):return a.start_ms<b.start_ms)
        var late:Dictionary=later[0]
        for world_boundary in [false,true]:
            var world=World.new();root.add_child(world)
            world.timeline=Recording.restore(index,maxf(0,item.start_ms-0.001))
            world.timeline.current={};world.timeline.queue=[item.group]
            world.timeline.display_ms=item.start_ms;world.timeline.group_start_ms=item.start_ms;world.timeline.commit_index=0
            world.timeline.paused=false
            if world_boundary:world.timeline.world_ready=func(_candidate):return true
            var renderer=Renderer.new();var spy=Spy.new()
            renderer.native_spells=spy;renderer.native_hits=HitSpy.new();renderer.blood=BloodSpy.new()
            renderer.epoch=world.timeline.initialization_revision
            spy.blocked[late.id]=true
            world.timeline.media_ready=func(group):return renderer.prepare([group],index.cache,world,{"frame":Engine.get_process_frames(),"used_usec":0,"limit_usec":1000000},false,world.timeline.media_target_ms).ready
            world.timeline.advance(1.0)
            check(not world.timeline.waiting_for_media and world.timeline.current.get("id")==item.group.id,"Real cast starts while a later cue is unavailable; world boundary="+str(world_boundary))
            check(spy.optional.any(func(component):return component.id==late.id),"Later authoritative cue remains in background preparation")
            var due=item.start_ms+late.start_ms
            for step in 1000:
                if world.timeline.display_ms>=due-1:break
                world.timeline.advance(minf(5,due-1-world.timeline.display_ms))
            var before=world.timeline.display_ms
            var state=var_to_bytes(world.timeline.state)
            var trace_revision=world.timeline.trace_revision
            world.timeline.advance(2.0)
            check(world.timeline.waiting_for_media and world.timeline.display_ms==before,"Missing due cue blocks before its scheduled use")
            check(var_to_bytes(world.timeline.state)==state and world.timeline.trace_revision==trace_revision,"Missing due cue publishes no state/log/event changes")
            spy.blocked.clear();world.timeline.advance(2.0)
            check(not world.timeline.waiting_for_media,"Prepared cue releases the same boundary")
            var expected=Recording.restore(index,world.timeline.display_ms)
            check(world.timeline.state==expected.state,"Resumed actual cast keeps authoritative event order")
            # Replay explicitly proves all supplied sources, regardless of time.
            spy.blocked[late.id]=true
            check(not renderer.prepare([item.group],index.cache,world,{"frame":Engine.get_process_frames(),"used_usec":0,"limit_usec":1000000},false).ready,"Full replay preparation still waits for later cues")
            renderer.audio.close();world.free()
        cases+=1
        if cases>=6:break
    check(cases>0,"Real recording exercises scheduled cue admission")
func old_images(renderer:RefCounted,world:World)->Dictionary:
    var wanted={}
    if renderer.handles.is_empty():return wanted
    for visual in world.visual_actors.values():
        for entry in visual.entries:
            if entry.role=="shadow" or not entry.actor_layer.get("effect",{}).is_empty():continue
            var path:String=entry.get("texture_path","")
            if path.is_empty():continue
            var paths=Native.Support.required_paths(path,entry.actor_layer.slot,world.catalog_cache)
            if not paths.is_empty():wanted[paths.solid]=true
    for handle in renderer.handles.values():
        var component:Dictionary=handle.component
        for id in [component.actor_uuid,component.target_uuid]:
            var visual:Dictionary=world.visual_actors.get(id,{})
            if visual.is_empty():continue
            var clips:Array=["Idle"]
            if id==component.actor_uuid:clips.append(component.cast_recipe.get("actionClip",""))
            if world.playbacks.has(id):clips.append(world.playbacks[id].clip)
            for entry in visual.entries:
                if entry.role=="shadow" or not entry.actor_layer.get("effect",{}).is_empty():continue
                for clip in clips:
                    var path:String=entry.actor_layer.paths.get(clip,"")
                    if path.is_empty():continue
                    wanted[path]=true # Exact requested socket pose owns its colour even without optical maps.
                    for value in Native.Support.required_paths(path,entry.actor_layer.slot,world.catalog_cache).values():wanted[value]=true
    return wanted

func owner_values(path:String,label:String,spatial:bool)->void:
    var index=Recording.read(path)
    check(index.ok,label+" real lifecycle recording admits")
    if not index.ok:return
    compiled_requirements(index,true)
    var owners:Dictionary={};var change:Dictionary={}
    for item in index.groups:
        for commit in item.group.get("commits",[]):
            var previous=owners.duplicate(true)
            var at:float=item.start_ms+commit.at_ms
            if spatial:
                if commit.delta.get("set",{}).has("senses"):
                    Conditions.NativePersistent.observe_spatial(owners,commit.delta.set.senses.get("spatial_effects",{}),at)
            else:Conditions.observe(owners,commit.delta.get("actors",{}),at)
            for id in owners:
                if not previous.has(id) or owners[id]==previous[id]:continue
                var selected:Dictionary=Conditions.NativePersistent.spatial_selection(owners[id].effect,index.cache) if spatial else Renderer.NativeAuthoring.condition(str(owners[id].condition.behavior_id),index.cache)
                if selected.is_empty():continue
                change={"id":id,"before":previous[id],"after":owners[id].duplicate(true),"at":at}
                break
            if not change.is_empty():break
        if not change.is_empty():break
    check(not change.is_empty(),label+" contains an actual same-UUID native owner value change")
    if change.is_empty():return
    var world=World.new();root.add_child(world);world.timeline=Recording.Timeline.new();world.timeline.display_ms=change.at
    var target:Dictionary=world.timeline.spatial_effect_owners if spatial else world.timeline.condition_owners
    target[change.id]=change.before.duplicate(true)
    var renderer=Renderer.new();var spy=Spy.new()
    renderer.native_spells=spy;renderer.native_hits=HitSpy.new();renderer.blood=BloodSpy.new()
    renderer.epoch=world.timeline.initialization_revision
    renderer.prepare([],index.cache,world)
    var original=spy.components
    var saved=original.duplicate(true)
    target[change.id].clear();target[change.id].merge(change.after,true)
    renderer.prepare([],index.cache,world)
    check(inputs(spy.components)==inputs(reference([],world.timeline,index.cache)),label+" changed owner supplies exact current native source/shape operands")
    check(original==saved,label+" previously prepared rows remain independent of changed live owner")
    target[change.id]=change.before.duplicate(true)
    renderer.prepare([],index.cache,world)
    check(inputs(spy.components)==inputs(original),label+" restoring disclosed owner restores its source inputs")
    owner_cases.append({"case":label,"id":change.id,"at_ms":change.at,"spatial":spatial})
    renderer.audio.close();world.free()

func compiled_requirements(index:Dictionary,require_persistent:bool=false)->void:
    var count=0
    for item in index.groups:
        check(item.group.has("native_requirements"),"Every compiled group owns its preparation requirements")
        var keys={}
        for row in item.group.native_requirements:
            count+=1
            check(row.preparation_at_ms>=0 and row.preparation_at_ms<=item.group.duration_ms,"Required source/shape belongs to an exact local cut")
            check(not row.has("age_ms") and not row.has("absolute_start_ms") and not row.has("initial") and not row.get("native_cue",{}).has("owner_end_seconds"),"Compiled preparation operands cannot replace live occurrence clocks")
            check(not keys.has(row.preparation_key),"Distinct source/shape cut has one preparation identity")
            keys[row.preparation_key]=true
    if require_persistent:check(count>0,"Actual lifecycle recording exercises compiled persistent native requirements")

func run()->void:
    var directory=Fixtures.journal("gallery")
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--recording="):directory=argument.trim_prefix("--recording=")
    var index=Recording.read(directory)
    check(index.ok,"Actual Gallery recording admitted")
    if not index.ok:quit(1);return
    compiled_requirements(index)
    scheduled_admission(index)
    owner_values(Fixtures.journal("shield","blue"),"Shield",false)
    owner_values(Fixtures.journal("web"),"Web",true)
    var native_count=0;var hit_count=0;var clips={}
    for item in index.groups:
        for component in item.group.components:
            if component.get("native_spell",false):native_count+=1;clips[component.native_clip.id]=true
            if component.has("native_hit"):hit_count+=1
    var world=World.new();root.add_child(world);var renderer=Renderer.new();var spy=Spy.new()
    renderer.native_spells=spy;renderer.native_hits=HitSpy.new();renderer.blood=BloodSpy.new()
    for at in [0.0,3350.0,5183.1,6000.0,10165.2,12000.0,25000.0,42000.0]:
        world.timeline=Recording.restore(index,at);renderer.epoch=world.timeline.initialization_revision
        var owners=world.timeline.condition_owners.duplicate(true);var areas=world.timeline.spatial_effect_owners.duplicate(true)
        var groups:Array=[world.timeline.current] if not world.timeline.current.is_empty() else world.timeline.queue.slice(0,1)
        var expected=inputs(reference(groups,world.timeline,index.cache))
        renderer.prepare(groups,index.cache,world)
        check(inputs(spy.components)==expected,"Exact required preparation input at "+str(at))
        var retained=groups.duplicate(true)
        renderer.prepare(groups,index.cache,world)
        check(groups==retained,"Repeated readiness does not mutate compiler-owned requirements at "+str(at))
        check(inputs(spy.components)==expected,"Reused inputs preserve source identity at "+str(at))
        renderer.prepare(world.timeline.queue.slice(0,2),index.cache,world)
        renderer.prepare(groups,index.cache,world)
        check(groups==retained,"Alternating current/lookahead queries keep compiler inputs immutable at "+str(at))
        check(inputs(spy.components)==expected,"Alternating preparation preserves original source inputs at "+str(at))
        check(owners==world.timeline.condition_owners and areas==world.timeline.spatial_effect_owners,"Preparation leaves authoritative owner snapshots unchanged at "+str(at))
        world.timeline.revision+=1
        renderer.prepare(groups,index.cache,world)
        check(inputs(spy.components)==expected,"Unrelated canonical revision keeps identical source inputs at "+str(at))
    var future_wait_cases=0
    for item in index.groups:
        if item.group.duration_ms<20 or future_wait_cases>=6:continue
        var at:float=item.start_ms+item.group.duration_ms*.5
        world.timeline=Recording.restore(index,at);renderer.epoch=world.timeline.initialization_revision
        spy.blocked={}
        if world.timeline.current.is_empty():continue
        var group:Dictionary=world.timeline.current
        renderer.blood.blocked={};renderer.blood.requested={}
        renderer.prepare([group],index.cache,world)
        if spy.optional.is_empty():continue
        for component in spy.optional:spy.blocked[component.id]=true
        for future_group in renderer._native_prefetch([group],world):
            if future_group.get("id","")!=group.id:renderer.blood.blocked[future_group.id]=true
        check(renderer.prepare([group],index.cache,world).ready,"Slow optional sources cannot gate current group at "+str(at))
        renderer.prepare_optional(world,index.cache,{"frame":Engine.get_process_frames(),"used_usec":0,"limit_usec":1000000})
        for id in renderer.blood.blocked:check(renderer.blood.requested.has(id),"Already received future blood gets preparation time")
        renderer.blood.blocked[group.id]=true
        check(not renderer.prepare([group],index.cache,world).ready,"An unprepared current blood receiver still gates its own event")
        renderer.blood.blocked.erase(group.id)
        var before:float=world.timeline.display_ms
        var step=minf(10.0,(world.timeline.group_start_ms+group.duration_ms-before)*.5)
        if step<=0:continue
        world.timeline.media_ready=func(request):return renderer.prepare([request],index.cache,world).ready
        world.timeline.paused=false;world.timeline.advance(step);world.timeline.paused=true
        var expected=Recording.restore(index,before+step)
        check(not world.timeline.waiting_for_media and is_equal_approx(world.timeline.display_ms,before+step),"Current real playback advances while future source is unready at "+str(at))
        check(world.timeline.state==expected.state,"Canonical ordered commits match the same real recording while prefetch waits at "+str(at))
        var future_inputs:Dictionary=inputs(reference(renderer._native_prefetch([group],world),world.timeline,index.cache))
        check(spy.optional.all(func(component):return future_inputs.has(component.id)),"Optional occurrences belong to the received preparation horizon at "+str(at))
        future_wait_cases+=1
    spy.blocked={}
    renderer.blood.blocked={}
    check(future_wait_cases>0,"Actual Gallery includes a nonempty future-source wait qualification")
    var native=Native.new()
    var table:Dictionary={"records":preload("res://tests/built_body_records.gd").records({})}
    var selected:Array=[]
    for path in table.records:
        if table.records[path].has("reference") and not table.records[path].slots.is_empty():selected.append(path)
        if selected.size()==3:break
    check(selected.size()==3,"Three actual delivered optical source paths exist")
    for i in 3:
        var path:String=selected[i];var slot:String=table.records[path].slots[0]
        world.visual_actors[str(i)]={"entries":[{"role":"actor","texture_path":path,"actor_layer":{"slot":slot,"paths":{"Idle":selected[0],"Magic1":selected[1],"Run":selected[2]}}}]}
        var playback=Playback.new();world.playbacks[str(i)]=playback
    var source_component:Dictionary={}
    for item in index.groups:
        for component in item.group.components:
            if component.get("native_spell",false) and "weapon_binding" not in component.native_clip.get("inputs",[]) and Native.Inputs.geometry_interests(component).is_empty():
                source_component=component;break
        if not source_component.is_empty():break
    check(not source_component.is_empty(),"Actual current source without measured geometry channels isolates the retained socket-source image contract")
    if source_component.is_empty():renderer.audio.close();world.free();quit(1);return
    var image_component:Dictionary=source_component.duplicate();image_component.actor_uuid="0";image_component.target_uuid="1"
    image_component.cast_recipe={"actionClip":"Magic1"}
    for i in 5:native.handles[str(i)]={"component":image_component}
    for change in 5:
        if change==1:world.playbacks["0"].clip="Run"
        elif change==2:world.visual_actors["0"].entries[0].texture_path=selected[2]
        elif change==3:native.handles.clear()
        elif change==4:var alternate:Dictionary=image_component.duplicate();alternate.actor_uuid="2";alternate.cast_recipe={"actionClip":"Run"};native.handles["new"]={"component":alternate}
        native._required_ids={}
        for id in native.handles:native._required_ids[id]=native.handles[id].component
        native._image_requirements(world)
        check(native.required_images==old_images(native,world),"Exact optical demand matches old full traversal after change "+str(change))
        var retained=native.required_images
        native._image_requirements(world)
        check(is_same(retained,native.required_images),"Unchanged optical demand retains its owner "+str(change))
    for playback in world.playbacks.values():playback.free()
    renderer.audio.close();world.free()
    var report={"checks":checks,"failures":failures,"recording_native_occurrences":native_count,"recording_native_hit_occurrences":hit_count,"recording_unique_clips":clips.keys(),"owner_value_cases":owner_cases,"scope":"Compiled preparation-only inputs, due admission and input immutability; actual Shield/Web same-owner value changes; actual delivered optical path parity. No rendered-pixel claim."}
    FileAccess.open("res://.runtime/native-preparation-cache-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("NATIVE_PREPARATION_CACHE ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
