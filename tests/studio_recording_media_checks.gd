extends SceneTree
## Real admitted recordings: finite source closure, immutable history, budget compatibility.
const Recording=preload("res://studio/recording.gd")
const RecordingMedia=preload("res://studio/recording_media.gd")
const Media=preload("res://presentation/media_warmup.gd")
const EnvironmentMedia=preload("res://presentation/environment_media.gd")
const Catalog=preload("res://source_catalog.gd")
const Compiler=preload("res://presentation/compiler.gd")
const Player=preload("res://play.gd")
var checks=0
var failures:Array=[]
var evidence:Array=[]
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);print("STUDIO_RECORDING_MEDIA_FAIL ",label)
func run()->void:
    for name in ["hide-light-schema9-seed3/amber","hide-light-schema9-seed3/blue","dash-seed3/amber"]:
        var index=Recording.read("res://.runtime/studio-cases/"+name+"/journal")
        check(index.ok,name+" current recording admits")
        if not index.ok:continue
        var history=var_to_bytes([index.initialization,index.groups,index.rows,index.cache])
        var started=Time.get_ticks_usec()
        var worker=Thread.new();worker.start(RecordingMedia.plan.bind(index))
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
        check(actual.source_files.keys().all(func(path):return not str(path).begins_with("__")),name+" worker returns source documents without mutable derived caches")
        check(actual.source_files.has("catalog/rigs.json") and is_same(actual.source_files["catalog/rigs.json"],index.cache["catalog/rigs.json"]),name+" authored revision remains the immutable admitted source")
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
        # Dash includes real damage/residue frame preparation: its rendering
        # gate belongs to the native replay suite, not a headless PNG fixture.
        if name.begins_with("hide-light-"):await replay_demand(index,actual,name)
        var again=RecordingMedia.plan(index)
        check(actual==again and actual.revision==1,name+" immutable recording has stable plan identity data/revision")
        var full=Media.create();full.budget_bytes=total
        full.plan_cache=Catalog.source_snapshot(actual.source_files)
        full.encounter_override=actual
        Media.adopt_required(full,1)
        Media.demand(full,actual.priority)
        check(full.preload_selected==actual.paths and full.preload_skipped==0,name+" existing budget selector accepts full recording when it fits")
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
        check(not planned.is_empty() and full.plan_task<0 and full.optional_pending.is_empty(),name+" exact current-state metadata still completes without launching exhaustive optional rig-family work")
        Media.close(full)
        var capped=Media.create();capped.budget_bytes=0
        Media.adopt_encounter(capped,actual,1)
        Media.demand(capped,actual.priority)
        check(capped.preload_selected==actual.priority and capped.preload_skipped==actual.paths.size()-actual.priority.size(),name+" existing zero optional budget retains mandatory sources and skips future media")
        Media.close(capped)
        var narrow_cache=Catalog.source_snapshot(index.cache)
        var narrow=Media.plan(index.initialization.state,groups.slice(0,2),narrow_cache)
        var narrow_world=EnvironmentMedia.plan(index.initialization.state,groups.slice(0,2),narrow_cache)
        var first_two={}
        for paths in [narrow.required,narrow.upcoming,narrow_world.required,narrow_world.upcoming]:first_two.merge(paths)
        check(first_two.keys().all(func(path):return actual.paths.has(path)),name+" current two-group closure is retained in recording plan")
        evidence.append({"recording":name,"groups":groups.size(),"sources":actual.paths.size(),"first_two_groups_sources":first_two.size(),
            "future_only_sources":actual.paths.size()-first_two.size(),"environment_sources":actual.environment.size(),"fixture_sources":actual.fixtures.size(),
            "cpu_required":actual.cpu_required.size(),"gpu_only":actual.gpu_only.size(),"estimated_bytes":total,"metadata_ms":elapsed})
    var report={"checks":checks,"failures":failures,"evidence":evidence,"scope":"Real Hide/light Amber and Blue plus Dash journals. Worker-only exact shared source closure for all admitted groups, immutable histories, existing PNG header accounting and existing bounded selection. No textures/GPU and no native loading-performance claim."}
    FileAccess.open("res://generated/studio_recording_media_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("STUDIO_RECORDING_MEDIA ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)

func replay_demand(index:Dictionary,source:Dictionary,label:String)->void:
    var player=Player.new();player.external_playback=true;player.external_clock=true
    player.catalog_cache=Catalog.source_snapshot(source.source_files)
    player.media_warmup.encounter_override=source;player.media_warmup.budget_bytes=0
    player.install_playback(Recording.restore(index,0.0))
    player.world_revision=player.timeline.world_revision
    player.world_prepare_epoch=player.timeline.initialization_revision
    player._prepare_media()
    var ordinary:Dictionary=player.media_warmup.wanted.duplicate()
    var optional_before:Dictionary=player.media_warmup.preload_selected.duplicate()
    var plan=player.timeline.replay_plan(index.duration_ms)
    var state=var_to_bytes(player.timeline.state)
    check(plan.groups.size()>2,label+" actual replay target crosses more than two groups")
    check(not player._replay_media_ready(plan),label+" cold exact replay target blocks before media publication")
    var wanted={};var environment={}
    for group in plan.groups:
        wanted.merge(source.group_plans[group.id].character);wanted.merge(source.group_plans[group.id].environment)
        environment.merge(source.group_plans[group.id].environment)
    check(wanted.keys().all(func(path):return player.media_warmup.wanted.has(path)),label+" crossed groups promote exact closure with zero optional budget")
    check(player.media_warmup.preload_selected.size()<source.paths.size() or wanted.size()==source.paths.size(),label+" optional recording closure remains budget selected")
    var future:Array=wanted.keys().filter(func(path):return not ordinary.has(path))
    check(not future.is_empty() and future.all(func(path):return not optional_before.has(path)),label+" future-only sources were absent from optional preloading before the replay demand")
    player._prepare_media()
    check(wanted.keys().all(func(path):return player.media_warmup.wanted.has(path)),label+" regular next-frame preparation retains pending cumulative pins")
    check(player.media_warmup.plan_task<0,label+" crossed group metadata uses the recording worker plans without a new worker")
    var candidate={"replay":true,"replay_groups":plan.groups,"source_group_id":plan.groups.back().id}
    check(not player._prepared_world_sources_ready(candidate),label+" cumulative environment closure blocks while cold")
    var missing:String=environment.keys()[0]
    for path in player.media_warmup.wanted:
        if path!=missing:Media.published(player.media_warmup,{"path":path,"cpu_bytes":16,"gpu_bytes":16,"energy":1.0,"emission_centroid":Vector2.ZERO})
    check(not player._prepared_world_sources_ready(candidate) and not player._replay_media_ready(plan),label+" one missing cumulative environment source blocks both admissions")
    Media.published(player.media_warmup,{"path":missing,"cpu_bytes":16,"gpu_bytes":16,"energy":1.0,"emission_centroid":Vector2.ZERO})
    var deadline=Time.get_ticks_msec()+10000
    var prepared=player._replay_media_ready(plan)
    while not prepared and Time.get_ticks_msec()<deadline:
        await process_frame
        prepared=player._replay_media_ready(plan)
    check(player._prepared_world_sources_ready(candidate) and prepared,label+" full mandatory publication plus normal native resource preparation admits cumulative closure")
    check(var_to_bytes(player.timeline.state)==state,label+" media preparation never publishes future reducer state")
    player.timeline.replay_cancel_preparation();player._prepare_media()
    check(player.replay_media_groups.is_empty() and player.media_warmup.wanted==ordinary,label+" cancel restores only the actual current window demand")
    check(future.all(func(path):return not player.media_warmup.wanted.has(path)),label+" cancel releases every crossed-only mandatory pin")
    player._replay_media_ready(plan)
    # This fixture qualifies media/prefix ownership only; native scene admission
    # and simultaneous pane publication are exercised by the native replay suite.
    player.timeline.world_ready=func(_candidate):return true
    check(player.timeline.replay_prepare(plan) and player.timeline.replay_publish(plan),label+" admitted real cumulative prefix publishes after the media proof")
    player._prepare_media()
    deadline=Time.get_ticks_msec()+10000
    while not player.media_metadata_ready and Time.get_ticks_msec()<deadline:
        var completed=Media.poll_plan(player.media_warmup)
        if not completed.is_empty():player._adopt_media_plan(completed)
        player._prepare_media()
        await process_frame
    var final_cache=Catalog.source_snapshot(source.source_files)
    var final_actor=Media.plan(player.timeline.state,[],final_cache)
    var final_world=EnvironmentMedia.plan(player.timeline.state,[],final_cache)
    var final_required:Dictionary=final_actor.required.duplicate();final_required.merge(final_world.required);final_required.merge(player.media_condition_paths)
    check(player.replay_media_groups.is_empty() and player.media_warmup.wanted.keys().all(func(path):return final_required.has(path)) and player.media_warmup.wanted.size()==final_required.size(),label+" success releases cumulative pins and retains only final-state plus live condition closure")
    player.install_playback(Recording.restore(index,0.0));player._prepare_media()
    check(player.replay_media_groups.is_empty() and player.media_warmup.wanted==ordinary,label+" seek/reset cannot inherit the canceled replay closure")
    player.install_playback(Recording.restore(index,0.0))
    var fresh_plan=player.timeline.replay_plan(index.duration_ms)
    player._replay_media_ready(fresh_plan)
    check(player.replay_media_groups==fresh_plan.groups and wanted.keys().all(func(path):return player.media_warmup.wanted.has(path)),label+" first replay callback after a new epoch retains the full crossed closure")
    player.timeline.replay_cancel_preparation();player._prepare_media()
    Media.close(player.media_warmup);player.component_renderer.close(player)
    player.context_menu.free();player.free()
