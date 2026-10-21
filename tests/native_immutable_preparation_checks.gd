extends SceneTree
## Production admission of the delivered immutable bank; no source prototypes,
## fixture outcomes or hidden actor state are shared by preparation.
const Effects=preload("res://presentation/effect_package.gd")
const Admission=preload("res://presentation/native_source_admission.gd")
const Baked=preload("res://presentation/baked_effect.gd")
var checks:int=0
var failures:Array=[]
var evidence:Array=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("IMMUTABLE_PREPARATION_FAIL "+label)
func run()->void:
    var owner:Node3D=Node3D.new();root.add_child(owner)
    var cache:Dictionary={};var clips:Array=[]
    for id in ["sorcerer_quickened_native","sorcerer_twinned_native","sorcerer_distant_native"]:clips.append(Effects.clip(id))
    var prepared:Dictionary={"ready":false,"errors":[]}
    var requested:Array=[clips[0]]
    var expanded:bool=false
    var expansion:Dictionary={}
    var recorded_clip:Dictionary=Effects.clip("spells/acid_splash/default/travel").duplicate(false)
    recorded_clip.approach_id="recorded-0"
    var recorded:Variant=null
    var deadline:int=Time.get_ticks_msec()+45000
    while (not expanded or not prepared.ready or not recorded is Resource) and prepared.errors.is_empty() and Time.get_ticks_msec()<deadline:
        prepared=Effects.prepare(requested,cache)
        if not expanded:
            var active:Dictionary=Admission._source_job
            if not active.is_empty() and is_same(active.owner,cache) and not active.draining and not active.job.complete:
                var missing:Array=[]
                for sibling in clips.slice(1):
                    for path in Effects.resource_paths(sibling):
                        if not cache.has(path) and path not in missing:missing.append(path)
                check(not missing.is_empty(),"Same-owner expansion adds actual uncached sibling resource paths")
                expansion={"source_preparer":active.preparation.resource_path,"source_at":active.job.at,
                    "same_cache_owner":is_same(active.owner,cache),"source_unfinished":not active.job.complete,
                    "additional_clips":clips.slice(1).map(func(clip):return clip.id),"uncached_paths":missing}
                requested=clips;expanded=true;prepared.ready=false
                # Exercise the existing independent recorded queue at the same
                # source-owner boundary, without constructing another owner.
                recorded=Baked.ready_for(recorded_clip,0,true)
        elif not recorded is Resource:
            recorded=Baked.ready_for(recorded_clip,0,true)
        await process_frame
    check(expanded,"Required-source expansion begins while the same cache owns an actual unfinished immutable job")
    check(recorded is Resource,"Concurrent original recorded resource completes its existing loader/upload lane")
    evidence.append({"same_owner_expansion":expansion,"recorded_clip":recorded_clip.id,
        "recorded_path":recorded.resource_path if recorded is Resource else "",
        "scope":"Actual retained required source plus uncached sibling resources and original recorded load; no frame-cost or general mixed-lane race claim"})
    check(prepared.ready and prepared.errors.is_empty(),"Selected production clips complete immutable admission: "+str(prepared))
    var paths:Array=[]
    for job in cache.get("native_immutable_jobs",{}).values():
        check(job.complete and job.error.is_empty(),"Source preparation completes without constructing an occurrence")
        for entry in job.pending:check(not entry.has("input"),"Completed discovery discards its private operands")
        for path in job.requested_paths:
            if path not in paths:paths.append(path)
    check(paths.size()==3,"Only the three requested native source assemblies are prepared")
    if prepared.ready:
        for clip in clips:
            var handles:Array=[];var costs:Array=[]
            for iteration in 2:
                var start:int=Time.get_ticks_usec()
                var handle:Dictionary=Effects.make(owner,clip,1<<19,iteration)
                costs.append((Time.get_ticks_usec()-start)/1000.0)
                check(handle.error.is_empty(),str(clip.id)+": prepared native occurrence constructs")
                if not handle.error.is_empty():Effects.close(handle);continue
                handles.append(handle)
                Effects.sample(handle,.4)
                var scans:int=handle.occurrence.binding_stats.material_scans
                for pose in 100:
                    Effects.set_input(handle,"recipient_geometry",{"actor_uuid":"contract-actor","ready":false,"origin":Vector3(float(pose),0,0),"points":[],"gpu_geometry_key":[pose]})
                check(handle.occurrence.binding_stats.material_scans==scans,str(clip.id)+": changing geometry packets do not recursively rediscover unchanged materials")
            if handles.size()==2:
                check(handles[0].occurrence!=handles[1].occurrence,str(clip.id)+": occurrences stay private")
                check(handles[0].occurrence.clock!=handles[1].occurrence.clock,str(clip.id)+": clocks stay private")
                Effects.sample(handles[0],.8)
                check(is_equal_approx(handles[1].occurrence.previous_age,.4),str(clip.id)+": one owner clock cannot advance another")
            evidence.append({"clip":clip.id,"construction_ms":costs,"scope":"Actual production EffectPackage prepare/make; timing fixture excludes player world and GPU first draw"})
            for handle in handles:Effects.close(handle)
            await process_frame
    owner.queue_free();await process_frame;await process_frame
    var result={"checks":checks,"failures":failures,"evidence":evidence,"prepared_resources":paths}
    FileAccess.open("res://.runtime/native-immutable-preparation.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
    print(JSON.stringify(result));quit(0 if failures.is_empty() else 1)
