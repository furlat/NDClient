extends SceneTree
## Real admitted recordings: finite source closure, immutable history, budget compatibility.
const Recording=preload("res://studio/recording.gd")
const RecordingMedia=preload("res://studio/recording_media.gd")
const Media=preload("res://presentation/media_warmup.gd")
const EnvironmentMedia=preload("res://presentation/environment_media.gd")
const Catalog=preload("res://source_catalog.gd")
const Compiler=preload("res://presentation/compiler.gd")
const BodySources=preload("res://presentation/body_sources.gd")
const NativeSources=preload("res://presentation/native_presentation_sources.gd")
var checks=0
var failures:Array=[]
var evidence:Array=[]
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);print("STUDIO_RECORDING_MEDIA_FAIL ",label)
func run()->void:
    var recordings:Array=[]
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--recording="):recordings.append(arg.trim_prefix("--recording="))
    check(not recordings.is_empty(),"Usage: --recording=<journal-directory> (repeat for additional real recordings)")
    for name in recordings:
        var index=Recording.read(name)
        check(index.ok,name+" current recording admits")
        if not index.ok:continue
        # Pin the actual typed source owners before a worker borrows the cache.
        # The immutable admission shell is a source input, not a mutable planner
        # index or an alias for the retired catalog/rigs.json document.
        var admitted_sources:Dictionary=Catalog.source_snapshot(index.cache)
        var history=var_to_bytes([index.initialization,index.groups,index.rows,index.cache])
        var started=Time.get_ticks_usec()
        var worker=Thread.new()
        var dispatched:Error=worker.start(RecordingMedia.plan.bind(index))
        check(dispatched==OK,name+" one metadata worker starts: "+error_string(dispatched))
        if dispatched!=OK:continue
        var actual:Dictionary=worker.wait_to_finish()
        var elapsed=(Time.get_ticks_usec()-started)/1000.0
        check(var_to_bytes([index.initialization,index.groups,index.rows,index.cache])==history,name+" worker leaves admitted states, groups, rows and source cache unchanged")
        var groups:Array=index.groups.map(func(item):return item.group)
        var cache=Catalog.source_snapshot(index.cache)
        var actors=Media.plan(index.initialization.state,groups,cache)
        var world=EnvironmentMedia.plan(index.initialization.state,groups,cache)
        var exact={}
        for paths in [actors.required,actors.upcoming,world.required,world.upcoming]:exact.merge(paths)
        check(actual.paths.size()==exact.size() and actual.paths.keys().all(func(path):return exact.has(path)),name+" finite closure equals shared required/upcoming planners across ALL admitted groups")
        check(actual.paths.keys().all(func(path):return actual.paths[path]==Catalog.media_path(path)),name+" source paths resolve through the existing catalog")
        var priority:Dictionary=actors.required.duplicate();priority.merge(world.required)
        check(actual.priority.size()==priority.size() and actual.priority.keys().all(func(path):return priority.has(path) and actual.priority[path]==actual.paths[path]),name+" exact first-group sources keep priority")
        var environment:Dictionary=world.required.duplicate();environment.merge(world.upcoming)
        check(actual.environment==environment and actual.fixtures==world.fixtures,name+" original environment and animated-fixture roles survive")
        var cpu:Dictionary=actors.cpu_required.duplicate();cpu.merge(environment)
        var gpu:Dictionary=actors.gpu_only.duplicate()
        for path in cpu:gpu.erase(path)
        check(actual.cpu_required==cpu and actual.gpu_only==gpu,name+" original CPU masks and GPU-only companions retain exact roles")
        check(actual.errors.is_empty() and actual.estimate_summary.unknown==0,name+" all exact PNG header estimates resolve without hidden errors")
        var total=0
        for path in actual.paths:
            var estimated:Dictionary=actual.estimates[path]
            check(estimated.has("bytes") and actual.estimate_bytes.get(path)==estimated.get("bytes"),name+" existing byte estimate retained: "+path)
            total+=int(estimated.get("bytes",0))
        check(total==actual.estimate_summary.bytes and total>0,name+" total retained CPU/GPU bytes match per-source estimates")
        var typed_keys:Array=[BodySources.KEY,NativeSources.CACHE_KEY]
        check(actual.source_files.keys().all(func(path):return (path is String and (path.ends_with(".json") or path.begins_with(Catalog.ENVIRONMENT)) and not path.begins_with("__")) \
            or path in typed_keys or path in ["native_references_validated","native_authoring_errors"]),name+" worker returns only admitted documents/typed owners, never mutable derived planner caches")
        for key in typed_keys:
            var before:Dictionary=admitted_sources[key]
            var after:Dictionary=actual.source_files[key]
            check(before.index!=null and is_same(before.index,after.index) and after.is_read_only() and after.loaded.is_read_only(),name+" typed source revision remains the same immutable admitted Resource: "+key)
            for path in before.loaded:
                check(after.loaded.has(path) and is_same(before.loaded[path],after.loaded[path]),name+" worker retains an already admitted physical metadata Resource: "+path)
        check(not actual.source_files[BodySources.KEY].index.rigs.is_empty(),name+" actual typed body index supplies the registered rig inventory")
        var prefix:Dictionary=index.initialization.state.duplicate(true)
        var group_cache=Catalog.source_snapshot(index.cache)
        check(actual.group_plans.size()==groups.size(),name+" each admitted group owns an exact prefix closure")
        for group in groups:
            var group_actors=Media.plan(prefix,[group],group_cache)
            var group_world=EnvironmentMedia.plan(prefix,[group],group_cache)
            var closure:Dictionary=actual.group_plans[group.id]
            check(closure.character==group_actors.required and closure.environment==group_world.required,name+" exact character/environment closure at admitted group prefix "+group.id)
            check(closure.errors==group_actors.errors and closure.fixtures==group_world.fixtures,name+" group errors and fixture preprocessing retained "+group.id)
            var group_cpu:Dictionary=group_actors.cpu_required.duplicate();group_cpu.merge(group_world.required)
            var group_gpu:Dictionary=group_actors.gpu_only.duplicate()
            for path in group_cpu:group_gpu.erase(path)
            check(closure.cpu_required==group_cpu and closure.gpu_only==group_gpu,name+" exact group CPU/GPU roles "+group.id)
            for commit in group.commits:Compiler.apply_delta(prefix,commit.delta)
        # Replay admission now includes native startup and component preparation.
        # It requires the real Studio scene; metadata receipts cannot certify it.
        var again=RecordingMedia.plan(index)
        check(actual==again and actual.revision==1,name+" immutable recording has stable plan identity data/revision")
        var full=Media.create();full.budget_bytes=total
        full.plan_cache=Catalog.source_snapshot(actual.source_files)
        full.encounter_override=actual
        Media.adopt_required(full,1)
        Media.demand(full,actual.priority,actual.environment,actual.fixtures,actual.gpu_only,actual.cpu_required)
        var selection_deadline=Time.get_ticks_msec()+20000
        while Media.diagnostics(full).selection_pending and Time.get_ticks_msec()<selection_deadline:
            Media.prepare_optional(full)
            await process_frame
        check(full.preload_selected==actual.paths and Media.preload_progress(full).skipped==0,name+" existing budget selector accepts full recording when it fits")
        check(full.boot_paths==actual.priority and full.resident.is_empty() and not Media.ready(full,actual.priority),name+" metadata creates no textures or readiness and startup pins only current exact sources")
        Media.adopt_required(full,2)
        check(full.encounter==actual and full.boot_paths.is_empty() and not full.boot_complete,name+" reverse seek retains the exact recording source set but resets current-state readiness")
        Media.adopt_encounter(full,{"paths":{}},2)
        check(full.encounter==actual,name+" generic optional families cannot replace the selected recording source set")
        Media.request_plan(full,[2,[]],index.initialization.state,[])
        var deadline=Time.get_ticks_msec()+30000;var planned={}
        while planned.is_empty() and Time.get_ticks_msec()<deadline:
            planned=Media.poll_plan(full)
            if planned.is_empty():await process_frame
        check(not planned.is_empty() and full.plan_thread==null and full.optional_pending.is_empty(),name+" exact current-state metadata still completes without launching exhaustive optional rig-family work")
        Media.close(full)
        var capped=Media.create();capped.budget_bytes=0
        Media.adopt_encounter(capped,actual,1)
        Media.demand(capped,actual.priority,actual.environment,actual.fixtures,actual.gpu_only,actual.cpu_required)
        deadline=Time.get_ticks_msec()+30000
        while Media.diagnostics(capped).selection_pending and Time.get_ticks_msec()<deadline:
            Media.prepare_optional(capped)
            await process_frame
        check(capped.preload_selected==actual.priority and Media.preload_progress(capped).skipped==actual.paths.size()-actual.priority.size(),name+" existing zero optional budget retains mandatory sources and skips future media")
        Media.close(capped)
        var narrow_cache=Catalog.source_snapshot(index.cache)
        var narrow=Media.plan(index.initialization.state,groups.slice(0,2),narrow_cache)
        var narrow_world=EnvironmentMedia.plan(index.initialization.state,groups.slice(0,2),narrow_cache)
        var first_two={}
        for paths in [narrow.required,narrow.upcoming,narrow_world.required,narrow_world.upcoming]:first_two.merge(paths)
        check(first_two.keys().all(func(path):return actual.paths.has(path)),name+" current two-group closure is retained in recording plan")
        evidence.append({"recording":name,"groups":groups.size(),"sources":actual.paths.size(),"first_two_groups_sources":first_two.size(),
            "future_only_sources":actual.paths.size()-first_two.size(),"environment_sources":actual.environment.size(),"fixture_sources":actual.fixtures.size(),
            "cpu_required":actual.cpu_required.size(),"gpu_only":actual.gpu_only.size(),"estimated_bytes":total,"metadata_ms":elapsed,
            "body_source_index":actual.source_files[BodySources.KEY].index.resource_path,"native_source_index":actual.source_files[NativeSources.CACHE_KEY].index.resource_path})
    var report={"checks":checks,"failures":failures,"evidence":evidence,"scope":"Explicit admitted journals. Worker-only exact source closure for all groups, immutable histories, PNG header accounting and bounded selection. No texture publication, native replay admission or performance claim.","unqualified":["Cumulative replay admission, cancellation and publication require real scene acceptance (studio_replay_native_checks)."]}
    FileAccess.open("res://generated/studio_recording_media_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("STUDIO_RECORDING_MEDIA ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
