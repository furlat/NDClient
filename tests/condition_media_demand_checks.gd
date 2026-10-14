extends SceneTree
# Real recorded removal -> cold restored owner -> exact production required
# source demand/readiness. Resident publications below are explicit CPU-only
# records; the native phase fixture owns texture/pixel proof.
const Recording=preload("res://studio/recording.gd")
const Player=preload("res://play.gd")
const Media=preload("res://presentation/media_warmup.gd")
const Conditions=preload("res://presentation/conditions.gd")
var checks=0
var failures:Array=[]
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);print("CONDITION_DEMAND_FAIL ",label)
func publish(player:Node,path:String)->void:
    Media.published(player.media_warmup,{"path":path,"cpu_bytes":16,"gpu_bytes":16,"energy":1.0,"emission_centroid":Vector2.ZERO})
func plan(player:Node)->void:
    var groups:Array=[]
    if not player.timeline.current.is_empty():groups.append(player.timeline.current)
    for group in player.timeline.queue:
        if groups.size()>=2:break
        groups.append(group)
    var key=[player.timeline.initialization_revision,groups.map(func(group):return group.id),player.timeline.revision if groups.is_empty() else 0]
    var result={}
    Media._plan_sources({"key":key,"state":Media._snapshot(player.timeline.state),"groups":groups},result,player.catalog_cache)
    player._reset_media_epoch();player._adopt_media_plan(result);player._prepare_media()
func run()->void:
    var path=""
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--recording="):path=argument.trim_prefix("--recording=")
    if path.is_empty():push_error("Explicit --recording with terminal registered removal required");quit(2);return
    var index=Recording.read(path)
    check(index.get("ok",false),"Actual removal recording admits")
    if not index.get("ok",false):finish({"recording":path});return
    var selected={}
    for row in index.rows:
        if row.kind=="condition_exit":
            var metadata=Conditions.Authoring.load_data("catalog/condition_media.json",index.cache)
            if row.recipe.get("persistent",{}).get("layers",[]).any(func(layer):return metadata.get(layer.assetId,{}).get("removal_asset_id")!=null):selected=row;break
    check(not selected.is_empty(),"Real recorded owner has a registered removal phase")
    if selected.is_empty():finish({"recording":path});return
    var at=selected.start_ms+minf(75,(selected.end_ms-selected.start_ms)*.5)
    var timeline=Recording.restore(index,at)
    var held_state=timeline.state.duplicate(true)
    check(not timeline.state.actors[selected.owner.actor_uuid].conditions.any(func(condition):return condition.condition_uuid==selected.owner.id),"Canonical condition has actually been removed")
    var samples=timeline.component_samples(index.cache).filter(func(row):return row.get("condition_uuid")==selected.owner.id and row.kind=="registered_media")
    var phase_paths={}
    for row in samples:
        for phase in row.media_samples:phase_paths.merge(phase.media.paths)
    check(not phase_paths.is_empty(),"Cold restore still has authored registered release samples")
    var canonical=Media.plan(timeline.state,[],index.cache)
    var absent=phase_paths.keys().filter(func(source):return not canonical.required.has(source))
    check(not absent.is_empty(),"Canonical-only plan demonstrably omits retained release bytes")
    var player=Player.new();player.timeline=timeline;player.catalog_cache=index.cache
    player.world_revision=timeline.world_revision;player.world_prepare_epoch=timeline.initialization_revision
    plan(player)
    check(phase_paths.keys().all(func(source):return player.media_plan.required.has(source) and player.media_warmup.wanted.has(source)),"Production demand pins every currently sampled release source as required")
    check(phase_paths.keys().all(func(source):return player.media_warmup.cpu_required.has(source) and not player.media_warmup.gpu_only.has(source)),"Release media keeps original colour/alpha CPU role")
    check(not player._media_ready({}) and not player.playback_prepared(),"Cold Studio publication waits for release resources")
    var missing:String=absent[0]
    for source in player.media_warmup.wanted:
        if source!=missing:publish(player,source)
    check(not player._media_ready({}),"One missing release source still blocks prepared status")
    publish(player,missing)
    check(player._media_ready({}) and player.playback_prepared(),"Only complete source publication releases the cold restored scene")
    check(timeline.state==held_state,"Resource preparation/publication preserves the cold target-time canonical state")
    Media.published(player.media_warmup,{"path":missing,"cpu_bytes":16,"gpu_bytes":0})
    check(not player._media_ready({}),"Lost retained release residency blocks readiness again")
    publish(player,missing)
    var old_key=player.media_plan_key.duplicate(true)
    player.timeline.paused=false;player.timeline.advance(selected.end_ms-player.timeline.display_ms+.001)
    player.timeline.paused=true;player._prepare_media()
    check(timeline.display_ms>selected.end_ms,"Expiry check reaches the finite real removal end")
    var unchanged_key=player.media_plan_key==old_key
    check(unchanged_key,"Finite release expiry updates demand even while the actual idle plan key stays unchanged")
    check(not player.media_plan.required.has(missing) and not player.media_warmup.wanted.has(missing),"Expired presentation owner releases its supplemental required pins even at unchanged idle key")
    var expected=Recording.restore(index,timeline.display_ms)
    check(timeline.state==expected.state,"Resource readiness leaves exact subsequent canonical replay unchanged")
    player.install_playback(Recording.restore(index,at))
    plan(player)
    check(player.media_plan.required.has(missing),"A fresh earlier seek epoch restores release requirements")
    player.install_playback(Recording.restore(index,selected.end_ms+.001))
    plan(player)
    check(not player.media_condition_paths.has(missing),"A later replacement epoch cannot inherit the prior release owner's pins")
    var evidence={"recording":path,"condition":selected.owner.id,"sample_ms":at,"removal_ms":selected.start_ms,"expiry_ms":selected.end_ms,"release_paths":phase_paths.size(),"canonical_omissions":absent.size(),"unchanged_plan_key_at_expiry":unchanged_key,"scope":"Production required pin/readiness and cold restore lifecycle using actual recorded condition. Declared resident records; no GPU/PNG/pixel claim."}
    Media.close(player.media_warmup);player.component_renderer.close(player);player.context_menu.free();player.free()
    finish(evidence)
func finish(evidence:Dictionary)->void:
    evidence.checks=checks;evidence.failures=failures
    FileAccess.open("res://generated/condition_media_demand_checks.json",FileAccess.WRITE).store_string(JSON.stringify(evidence,"  "))
    print("CONDITION_DEMAND_CHECKS ",JSON.stringify(evidence));quit(0 if failures.is_empty() else 1)
