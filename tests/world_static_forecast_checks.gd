extends SceneTree
## Same actual recorded state through ordinary and forecast-assisted passive
## projection; fresh pose inputs must be consumed only when promoting the cut.
const Player=preload("res://play.gd")
const Preparation=preload("res://presentation/world_preparation.gd")
const Catalog=preload("res://source_catalog.gd")
const Characters=preload("res://presentation/characters.gd")
const Journal=preload("res://sdk/journal.gd")
const Fixtures=preload("res://tests/recording_fixtures.gd")
const Sources=preload("res://presentation/body_sources.gd")
var checks:int=0
var failures:Array=[]
var source_admission:Dictionary={}
class Host extends Player:
    func _ready()->void:
        set_process(false);set_process_unhandled_input(false)
        camera=Camera3D.new();add_child(camera);add_child(context_menu)
    func _process(_delta:float)->void:pass
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("STATIC_FORECAST_FAIL ",label)
func finished(job:Node)->void:
    while not job.worker_finished():await process_frame
    job.join()
func run()->void:
    var journal=Journal.new()
    var opened:Dictionary=journal.open(Fixtures.journal("gallery"),true,false)
    check(opened.ok and journal.replay(1).ok,"Actual recorded pre-door state reduces")
    if not opened.ok or journal.state.is_empty():finish();return
    Sources.invalidate()
    var host=Host.new();host.catalog_cache=Catalog.source_snapshot({});host.profile.recording=true
    var metadata:Dictionary=Catalog.read_file("catalog-index.json",host.catalog_cache)
    host.rig_config=Catalog.read_file(metadata.rig,host.catalog_cache)
    host.rigs=Characters.rigs(host.catalog_cache);root.add_child(host)
    host.timeline.accept({"kind":"initialization","state":journal.state,"sequence":1})
    host.world_revision=host.timeline.world_revision;host.world_prepare_epoch=host.timeline.initialization_revision
    host.world_quarter=host.quarter
    Preparation.WorldRows.update_rows(journal.state,host.catalog_cache,host.world_row_cache,{"full":true})
    host.scenery_visibility=Preparation.WorldRows.current_ids(journal.state,host.world_row_cache.boundaries,host.scenery_visible_cells)
    var actor_id:String=""
    for actor in journal.state.actors.values():
        if not Preparation.WorldRows.visible_actor(actor,journal.state):continue
        var resolved:Dictionary=Characters.resolve(actor,journal.state,host.catalog_cache)
        if resolved.ok and resolved.value!=null and host.rigs[resolved.value.rig].clips.has("Idle") and host.rigs[resolved.value.rig].clips.has("Run"):
            actor_id=actor.uuid;break
    check(not actor_id.is_empty(),"Actual visible actor owns both authored Idle and Run sources")
    if actor_id.is_empty():host.free();finish();return
    var target={"key":["fixture",1],"preparation_key":[host.timeline.initialization_revision,host.world_revision,"fixture"],
        "state":journal.state,"presentation_state":journal.state,"world_revision":host.world_revision,"display_ms":10.0,
        "actor_samples":{actor_id:{"clip":"Idle","source_seconds":0.0}},"actor_layers":[],"staged_actors":{},
        "changes":{"full":false,"tiles":{},"objects":{},"senses":false,"order":[]}}
    var original:PackedByteArray=var_to_bytes([host.timeline.state,host.world_row_cache])
    var captured:Dictionary=Preparation.capture_static(host,target)
    check(not captured.has("actor_samples") and not captured.has("existing_actors") and not captured.has("actor_loadouts"),
        "Static capture contains no actor pose, current layers or native binding operands")
    var child_count:int=host.get_child_count()
    var forecast:Dictionary={}
    var task:int=WorkerThreadPool.add_task(Preparation.derive_static.bind(captured,forecast))
    while not WorkerThreadPool.is_task_completed(task):await process_frame
    WorkerThreadPool.wait_for_task_completion(task)
    check(forecast.get("complete",false),"Static forecast finishes actual recorded rows/support/source inputs")
    check(host.get_child_count()==child_count and var_to_bytes([host.timeline.state,host.world_row_cache])==original,
        "Forecast creates no scene nodes and cannot mutate displayed/canonical owners")
    check(not forecast.static_result.has("actors") and not forecast.static_result.has("actor_members") and not forecast.static_result.has("actor_bindings"),
        "Forecast result owns no stale actor projection or optical bindings")
    var fresh:Dictionary=target.duplicate();fresh.actor_samples={actor_id:{"clip":"Run","source_seconds":0.125}}
    var promoted=Preparation.new();host.add_child(promoted);promoted.configure(host,fresh,false,forecast)
    await finished(promoted)
    check(promoted.result.get("complete",false),"Promotion completes fresh actor source derivation")
    var normal=Preparation.new();host.add_child(normal);normal.configure(host,fresh)
    await finished(normal)
    check(normal.result.get("complete",false),"Independent ordinary projection completes the same cut")
    if promoted.result.get("complete",false) and normal.result.get("complete",false):
        var cold:Dictionary=promoted.result.actor_worker_profile;var warm:Dictionary=normal.result.actor_worker_profile
        source_admission={"cold_loads":int(cold.get("category_resource_load_calls",0))+int(cold.get("clip_resource_load_calls",0)),
            "warm_loads":int(warm.get("category_resource_load_calls",0))+int(warm.get("clip_resource_load_calls",0)),
            "warm_shared_hits":int(warm.get("category_physical_cache_calls",0))+int(warm.get("clip_physical_cache_calls",0)),
            "cold_paths":{}}
        for kind in ["category","clip"]:
            source_admission.cold_paths.merge(cold.get(kind+"_resource_load_paths",{}))
        check(source_admission.cold_loads>0 and source_admission.warm_loads==0 and source_admission.warm_shared_hits>0,
            "Cold selected metadata loads on the worker; another snapshot borrows its physical Resources without reopening them")
        var selected_sources:Dictionary=promoted.result.source_files[Sources.KEY].loaded
        var ordinary_sources:Dictionary=normal.result.source_files[Sources.KEY].loaded
        check(not selected_sources.is_empty() and selected_sources.size()==ordinary_sources.size(),"Independent jobs admit the same finite selected body source set")
        for path in selected_sources:
            check(is_same(selected_sources[path],ordinary_sources.get(path)),"Independent worker snapshots share the exact physical Resource: "+path)
        check(is_same(promoted.result.row_patch,forecast.static_result.row_patch)
            and is_same(promoted.result.ground_support,forecast.static_result.ground_support),
            "Promotion adopts original prepared static results without reconstructing them")
        for field in ["row_patch","wanted","ground","packets","supports","visibility","visibility_changes","blood_rows","blood_index","environment_paths"]:
            check(promoted.result[field]==normal.result[field],"Forecast and ordinary static output parity: "+field)
        check(promoted.result.actor_members==normal.result.actor_members and promoted.result.actor_bindings==normal.result.actor_bindings,
            "Current actor membership and material/source binding operands match independent ordinary derivation")
        var prepared:Dictionary=promoted.result.actors[actor_id]
        check(prepared.source_sample.clip=="Run" and prepared.source_sample.source_seconds==0.125,
            "Promotion consumes current Run clock, not the earlier Idle forecast input")
        check(prepared.layers.any(func(layer):return layer.paths.has("Run")) and prepared.source_bindings.values().all(func(binding):return binding.path.contains("Run")),
            "Every selected new actor binding names the currently chosen authored clip")
    check(var_to_bytes([host.timeline.state,host.world_row_cache])==original,"Both preparation paths preserve the borrowed canonical/static base")
    promoted.free();normal.free();host.queue_free();await process_frame;await process_frame
    finish()
func finish()->void:
    var report={"checks":checks,"failures":failures,"source_admission":source_admission,"scope":"Actual recorded state: static forecast versus ordinary rows/support/sources/residue output; no native allocation during forecasting; exact prepared-result adoption and fresh Run actor clock/material inputs on promotion. Cold/warm worker source admission and shared physical Resource identity. No live latency or framebuffer claim."}
    FileAccess.open("res://generated/world_static_forecast_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("WORLD_STATIC_FORECAST_CHECKS ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
