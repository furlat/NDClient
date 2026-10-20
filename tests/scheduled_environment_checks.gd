extends SceneTree
const Fixtures=preload("res://tests/recording_fixtures.gd")
## Actual received Fireballs through Play's environment gate and both Timeline paths.
const Journal=preload("res://sdk/journal.gd")
const Compiler=preload("res://presentation/compiler.gd")
const Media=preload("res://presentation/media_warmup.gd")
const Player=preload("res://play.gd")
var checks=0
var failures:Array=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("SCHEDULED_ENVIRONMENT_FAIL ",label)
func qualify(before:Dictionary,groups:Array,world_path:bool,sequence:int)->void:
    var player=Player.new()
    player.timeline.accept({"kind":"initialization","state":before.duplicate(true),"sequence":sequence-1})
    player._reset_media_epoch()
    player.world_revision=player.timeline.world_revision
    var ids:Array=groups.map(func(group):return group.id)
    var prepared={}
    Media._plan_sources({"key":[player.timeline.initialization_revision,ids,0],"state":before,"groups":groups},prepared,{})
    player._adopt_media_plan(prepared)
    player.timeline.accept({"kind":"operation","groups":groups,"sequence":sequence})
    player._prepare_media()
    var schedule:Dictionary=player.media_group_plans[groups[0].id].environment_timeline
    check(not schedule.changes.is_empty(),"Actual Fireball has a later environment source: "+str(sequence))
    if schedule.changes.is_empty():player.context_menu.free();player.free();return
    var change:Dictionary=schedule.changes[0]
    var at:float=change.at_ms
    var missing:String=change.paths.keys().filter(func(path):return not schedule.initial.has(path))[0]
    check(at>0 and not schedule.initial.has(missing),"Missing path is first used after cast start")
    for path in player.media_environment_required:player.media_warmup.ready_paths[path]=true
    player.media_warmup.ready_paths.erase(missing)
    var wanted:Dictionary=player.media_warmup.wanted.duplicate()
    check(wanted.has(missing),"Full received source stays demanded while readiness is deferred")
    player.timeline.media_ready=func(group):return player._environment_sources_ready(group,player.timeline.media_target_ms)
    if world_path:player.timeline.world_ready=func(_candidate):return true
    player.timeline.advance(0)
    check(not player.timeline.current.is_empty() and not player.timeline.waiting_for_media,"Missing future source does not block cast activation")
    player.timeline.advance(at-.01)
    for turn in 3:
        if not world_path or player.timeline.pending_world.is_empty():break
        player.timeline.advance(0)
    check(player.timeline.display_ms<at and not player.timeline.waiting_for_media,"Windup precedes the actual environment first use")
    var clock:float=player.timeline.display_ms
    var state:PackedByteArray=var_to_bytes(player.timeline.state)
    var trace:PackedByteArray=var_to_bytes(player.timeline.trace)
    player.timeline.advance(at-clock)
    check(player.timeline.waiting_for_media and player.timeline.display_ms==clock,"Exact environment first-use boundary holds the display clock")
    check(var_to_bytes(player.timeline.state)==state and var_to_bytes(player.timeline.trace)==trace,"Missing source publishes no world/event/log changes")
    check(player.media_warmup.wanted==wanted,"Time-specific readiness never drops full received source demand")
    var boundary={"source_group_id":groups[0].id,"source_local_ms":at}
    check(not player._prepared_world_sources_ready(boundary),"World binding checks the candidate boundary's time")
    player.media_warmup.ready_paths[missing]=true
    for turn in 4:player.timeline.advance(at-player.timeline.display_ms)
    check(not player.timeline.waiting_for_media and player.timeline.display_ms>=at,"Original boundary resumes after actual source readiness")
    check(player._prepared_world_sources_ready(boundary),"Ready source satisfies the same candidate boundary")
    player.media_warmup.ready_paths.erase(missing)
    player.external_playback=true
    check(not player._environment_sources_ready(groups[0],0),"Replay retains full received environment readiness")
    Media.close(player.media_warmup)
    player.component_renderer.audio.close()
    player.context_menu.free();player.free()
func run()->void:
    for case_id in ["gallery","fireball"]:
        var directory:String=Fixtures.journal(case_id)
        var journal=Journal.new()
        check(journal.open(directory,true,false).ok,"Actual live journal opens without network")
        var casts:Array=Fixtures.fact_rows(case_id,"spell").filter(func(row):return row.fact.get("behavior_id")=="spell.fireball")
        check(not casts.is_empty(),"Original recording contains its actual Fireball")
        if casts.is_empty():continue
        var sequence:int=int(casts[0].sequence)
        check(journal.replay(sequence-1).ok,"Actual operation-before state reduces")
        var before:Dictionary=journal.state
        var decoded=journal.protocol.decode("PlayerOperation",FileAccess.get_file_as_bytes(directory.path_join("%016d.json"%sequence)))
        check(decoded.ok,"Actual Fireball passes strict packet admission")
        var compiled=Compiler.compile(before,journal.protocol.normalize("PlayerOperation",decoded.value),{})
        check(compiled.ok and compiled.value.groups.size()==1,"Actual Fireball compiles to its original group")
        if not compiled.ok:continue
        for world_path in [false,true]:qualify(before,compiled.value.groups,world_path,sequence)
    var report={"checks":checks,"failures":failures,"scope":"Actual two Fireballs, full demanded source closure, scheduled Play/Timeline readiness, exact first-use world/event fence and replay fallback. No GPU or live latency claim."}
    FileAccess.open("res://.runtime/scheduled-environment-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("SCHEDULED_ENVIRONMENT_CHECKS ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
