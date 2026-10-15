extends SceneTree
const Recording=preload("res://studio/recording.gd")
const Renderer=preload("res://presentation/component_renderer.gd")
const Native=preload("res://presentation/native_spell_renderer.gd")
const Conditions=preload("res://presentation/conditions.gd")
const Profile=preload("res://frame_profile.gd")
class Spy extends RefCounted:
    var components:Array=[]
    var optional:Array=[]
    var blocked:Dictionary={}
    func prepare(groups:Array,_cache:Dictionary,_world:Node=null,_prefetch:Array=[],_budget:Dictionary={},_allow_optional:bool=true)->Dictionary:
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
    func prepare(_world:Node,_groups:Array)->bool:
        var ready:bool=true
        for group in _groups:
            var id:String=group.get("id","")
            requested[id]=true
            if blocked.has(id):ready=false
        return ready
class World extends Node:
    var timeline:RefCounted
    var profile:Dictionary=Profile.create()
    var visual_actors:Dictionary={}
    var playbacks:Dictionary={}
    var catalog_cache:Dictionary={}
class Playback extends Node:
    var clip:String="Idle"
var checks=0
var failures:Array=[]
var closure_timing:Dictionary={}
var owner_cases:Array=[]
var closure_oracle:Script
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
        if component.get("native_spell",false):result[component.id]=[component.native_clip,component.get("cast_recipe",{}),component.get("actor_uuid"),component.get("target_uuid"),component.get("native_cue",{}),component.get("optical",{}),component.get("finish_profile",{}),component.get("resolved_area_positions",[])]
        elif component.has("native_hit"):result[component.id]=component.native_hit
    return result
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
                    for value in Native.Support.required_paths(path,entry.actor_layer.slot,world.catalog_cache).values():wanted[value]=true
    return wanted

func owner_values(path:String,label:String,spatial:bool)->void:
    var index=Recording.read(path)
    check(index.ok,label+" real lifecycle recording admits")
    if not index.ok:return
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
    var world=World.new();world.timeline=Recording.Timeline.new();world.timeline.display_ms=change.at
    var target:Dictionary=world.timeline.spatial_effect_owners if spatial else world.timeline.condition_owners
    target[change.id]=change.before.duplicate(true)
    var renderer=Renderer.new()
    var first=renderer._native_closure([],world,index.cache)
    var saved_key:Array=first.key.duplicate(true)
    # Mutate the existing dictionary using the second actual disclosed value:
    # revision, UUID, collection identities and compiled group list stay equal.
    target[change.id].clear();target[change.id].merge(change.after,true)
    var second=renderer._native_closure([],world,index.cache)
    check(not is_same(first,second),label+" changed owner values rebuild required sources without relying on revision or IDs")
    check(first.key==saved_key,label+" in-place owner mutation cannot rewrite a retained cache key")
    check(inputs(second.components)==inputs(reference([],world.timeline,index.cache)),label+" exact native cue/lifecycle/optical/footprint inputs equal full derivation")
    target[change.id]=change.before.duplicate(true)
    check(is_same(first,renderer._native_closure([],world,index.cache)),label+" restoring exact owner values reuses the still-bounded matching record")
    owner_cases.append({"case":label,"id":change.id,"at_ms":change.at,"spatial":spatial})
    renderer.audio.close();world.free()

func time_closure(index:Dictionary)->void:
    var world=World.new();world.timeline=Recording.restore(index,7320.345)
    var renderer=Renderer.new()
    var groups:Array=[world.timeline.current] if not world.timeline.current.is_empty() else []
    var retained_components:Array=world.timeline.retained_components.map(func(item):return item.component)
    if not retained_components.is_empty():groups.append({"components":retained_components})
    groups=renderer._native_prefetch(groups,world)
    var first=renderer._native_closure(groups,world,index.cache)
    var cold:Array=[];var original_cold:Array=[]
    var previous:RefCounted=closure_oracle.new() if closure_oracle!=null else null
    for repeat in 12:
        renderer._native_prepare_records=[]
        if previous!=null:previous._native_prepare_records=[]
        var started:int=Time.get_ticks_usec()
        var expected:Array=previous._native_closure(groups,world,index.cache).components if previous!=null else reference(groups,world.timeline,index.cache)
        original_cold.append(Time.get_ticks_usec()-started)
        started=Time.get_ticks_usec();first=renderer._native_closure(groups,world,index.cache)
        cold.append(Time.get_ticks_usec()-started)
        check(inputs(first.components)==inputs(expected),"Cold native-only preparation preserves original source inputs "+str(repeat))
    if previous!=null:previous.audio.close()
    var old:Array=[];var reused:Array=[]
    for repeat in 24:
        world.timeline.revision+=1
        var started:int=Time.get_ticks_usec();var expected=reference(groups,world.timeline,index.cache)
        old.append(Time.get_ticks_usec()-started)
        started=Time.get_ticks_usec();var actual=renderer._native_closure(groups,world,index.cache)
        reused.append(Time.get_ticks_usec()-started)
        check(is_same(first,actual) and inputs(actual.components)==inputs(expected),"Unrelated revision preserves exact future closure inputs "+str(repeat))
    old.sort();reused.sort();cold.sort();original_cold.sort()
    closure_timing={"groups":groups.size(),"iterations":24,"original_median_us":old[12],"reused_median_us":reused[12],
        "uncached_median_us":cold[6],"original_uncached_median_us":original_cold[6],"cold_oracle":closure_oracle!=null,
        "original_max_us":old.back(),"reused_max_us":reused.back(),"scope":"Isolated headless derivation; no native frame-time claim."}
    renderer.audio.close();world.free()

func run()->void:
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--closure-oracle="):closure_oracle=load(argument.trim_prefix("--closure-oracle="))
    var index=Recording.read("res://.runtime/gallery-sorcerer-20261015-seed3-door/amber/journal")
    check(index.ok,"Actual Gallery recording admitted")
    if not index.ok:quit(1);return
    time_closure(index)
    owner_values("res://.runtime/studio-spells-20261015/shield-seed3/blue/journal","Shield",false)
    owner_values("res://.runtime/studio-spells-20261015/web-seed2/amber/journal","Web",true)
    var native_count=0;var hit_count=0;var clips={}
    for item in index.groups:
        for component in item.group.components:
            if component.get("native_spell",false):native_count+=1;clips[component.native_clip.id]=true
            if component.has("native_hit"):hit_count+=1
    var world=World.new();var renderer=Renderer.new();var spy=Spy.new()
    renderer.native_spells=spy;renderer.native_hits=HitSpy.new();renderer.blood=BloodSpy.new()
    for at in [0.0,3350.0,5183.1,6000.0,10165.2,12000.0,25000.0,42000.0]:
        world.timeline=Recording.restore(index,at);renderer.epoch=world.timeline.initialization_revision
        renderer._native_prepare_key=[];renderer._native_prepare_records=[]
        var owners=world.timeline.condition_owners.duplicate(true);var areas=world.timeline.spatial_effect_owners.duplicate(true)
        var groups:Array=[world.timeline.current] if not world.timeline.current.is_empty() else world.timeline.queue.slice(0,1)
        var expected=inputs(reference(groups,world.timeline,index.cache))
        renderer.prepare(groups,index.cache,world)
        check(inputs(spy.components)==expected,"Exact required preparation input at "+str(at))
        var retained=renderer._native_prepare_groups
        renderer.prepare(groups,index.cache,world)
        check(is_same(retained,renderer._native_prepare_groups),"Repeated readiness reuses passive lookahead at "+str(at))
        check(inputs(spy.components)==expected,"Reused inputs preserve source identity at "+str(at))
        renderer.prepare(world.timeline.queue.slice(0,2),index.cache,world)
        renderer.prepare(groups,index.cache,world)
        check(is_same(retained,renderer._native_prepare_groups),"Alternating current/lookahead queries retain both closures at "+str(at))
        check(inputs(spy.components)==expected,"Alternating preparation preserves original source inputs at "+str(at))
        check(owners==world.timeline.condition_owners and areas==world.timeline.spatial_effect_owners,"Preparation leaves authoritative owner snapshots unchanged at "+str(at))
        world.timeline.revision+=1
        renderer.prepare(groups,index.cache,world)
        check(is_same(retained,renderer._native_prepare_groups),"Unrelated canonical revision keeps identical resource ownership at "+str(at))
    var future_wait_cases=0
    for item in index.groups:
        if item.group.duration_ms<20 or future_wait_cases>=6:continue
        var at:float=item.start_ms+item.group.duration_ms*.5
        world.timeline=Recording.restore(index,at);renderer.epoch=world.timeline.initialization_revision
        renderer._native_prepare_records=[];spy.blocked={}
        if world.timeline.current.is_empty():continue
        var group:Dictionary=world.timeline.current
        renderer.blood.blocked={};renderer.blood.requested={}
        renderer.prepare([group],index.cache,world)
        if spy.optional.is_empty():continue
        for component in spy.optional:spy.blocked[component.id]=true
        for future_group in renderer._native_prefetch([group],world):
            if future_group.get("id","")!=group.id:renderer.blood.blocked[future_group.id]=true
        check(renderer.prepare([group],index.cache,world).ready,"Slow optional sources cannot gate current group at "+str(at))
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
        check(spy.optional.size()<=Renderer.NATIVE_PREFETCH_OCCURRENCES,"Optional occurrence admission stays bounded at "+str(at))
        future_wait_cases+=1
    spy.blocked={}
    renderer.blood.blocked={}
    check(future_wait_cases>0,"Actual Gallery includes a nonempty future-source wait qualification")
    var native=Native.new()
    var table:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://generated/character_geometry.json"))
    var selected:Array=[]
    for path in table.records:
        if table.records[path].has("reference") and not table.records[path].slots.is_empty():selected.append(path)
        if selected.size()==3:break
    check(selected.size()==3,"Three actual delivered optical source paths exist")
    for i in 3:
        var path:String=selected[i];var slot:String=table.records[path].slots[0]
        world.visual_actors[str(i)]={"entries":[{"role":"actor","texture_path":path,"actor_layer":{"slot":slot,"paths":{"Idle":selected[0],"Magic1":selected[1],"Run":selected[2]}}}]}
        var playback=Playback.new();world.playbacks[str(i)]=playback
    for i in 5:native.handles[str(i)]={"component":{"actor_uuid":"0","target_uuid":"1","cast_recipe":{"actionClip":"Magic1"}}}
    for change in 5:
        if change==1:world.playbacks["0"].clip="Run"
        elif change==2:world.visual_actors["0"].entries[0].texture_path=selected[2]
        elif change==3:native.handles.clear()
        elif change==4:native.handles["new"]={"component":{"actor_uuid":"2","target_uuid":"1","cast_recipe":{"actionClip":"Run"}}}
        native._required_ids=native.handles.duplicate()
        native._image_requirements(world)
        check(native.required_images==old_images(native,world),"Exact optical demand matches old full traversal after change "+str(change))
        var retained=native.required_images
        native._image_requirements(world)
        check(is_same(retained,native.required_images),"Unchanged optical demand retains its owner "+str(change))
    for playback in world.playbacks.values():playback.free()
    renderer.audio.close();world.free()
    var report={"checks":checks,"failures":failures,"recording_native_occurrences":native_count,"recording_native_hit_occurrences":hit_count,"recording_unique_clips":clips.keys(),"owner_value_cases":owner_cases,"closure_timing":closure_timing,"scope":"Actual Gallery preparation-input parity and input immutability; actual Shield/Web same-owner value changes; actual delivered optical path parity. No rendered-pixel claim."}
    FileAccess.open("res://.runtime/native-preparation-cache-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("NATIVE_PREPARATION_CACHE ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
