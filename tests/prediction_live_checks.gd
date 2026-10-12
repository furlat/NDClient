extends "res://tests/player_live_checks.gd"
# Actual public preview/command, delayed transport, original sources and native
# AnimationTree; speculative presentation must precede server execution only.
func _run() -> void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000)
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    scene=Player.instantiate();root.add_child(scene)
    if not await until(ready,"Real encounter ready for local prediction"):await finish();return
    var chosen=select_position("action.move")
    check(not chosen.is_empty(),"Disclosed walk target exists")
    if chosen.is_empty():await finish();return
    var actor:String=scene.available_actions.entity_uuid
    var origin:Array=scene.timeline.state.actors[actor].last_visual_position.duplicate()
    var sequence:int=scene.timeline.sequence
    var trace_rows:Dictionary=scene.timeline.trace.rows.duplicate(true)
    var trace_logs:Array=scene.timeline.trace.logs.duplicate(true)
    var command:int=scene.session.status.next_command_number
    var started_count:int=scene.prediction.started
    scene._execute_admitted({"action":chosen.action,"selection":scene.Interaction.selection(chosen.action,[chosen.target.index])})
    if not await until(func():return scene.prediction.started>started_count,"Native submission starts an authored predicted prefix"):await finish();return
    var submitted=Time.get_ticks_msec()
    var samples=[]
    var waiting_frames=0
    var rotated=false
    var displacement=false
    var bounded=true
    var neutral=true
    var stable_state=true
    var previous_source=-1.0
    var no_rewind=true
    var max_frame=0.0
    var last=Time.get_ticks_usec()
    while healthy() and Time.get_ticks_msec()-submitted<30000:
        await scene.presentation_updated
        var now=Time.get_ticks_usec();max_frame=maxf(max_frame,(now-last)/1000.0);last=now
        var sample:Dictionary=scene.displayed_samples.get(actor,{})
        if sample.get("predicted",false):
            waiting_frames+=1
            if waiting_frames==30:
                scene.request_view(1);rotated=true
            displacement=displacement or sample.position!=origin
            bounded=bounded and scene.prediction.active.elapsed_ms<=120.0
            neutral=neutral and not sample.has("trace_track_id")
            if scene.timeline.sequence==sequence and scene.timeline.current.is_empty():
                stable_state=stable_state and scene.timeline.state.actors[actor].last_visual_position==origin and scene.timeline.trace.rows==trace_rows and scene.timeline.trace.logs==trace_logs
        if sample.get("clip")=="Run":
            no_rewind=no_rewind and sample.source_seconds+0.000001>=previous_source
            previous_source=sample.source_seconds
        observe_actor(actor,samples)
        if ready() and scene.timeline.sequence>sequence:break
    check(waiting_frames>20 and displacement,"Actor moves visually during actual two-second server delay")
    check(bounded and neutral and stable_state,"Prefix stays bounded without canonical movement or trace evidence")
    check(rotated and scene.quarter==1,"Camera quarter changes while predicted movement awaits server")
    check(no_rewind and scene.prediction.matched==1,"Native Run phase transfers without replaying opening")
    check(scene.timeline.state.actors[actor].last_visual_position==chosen.target.position,"Actual server destination wins")
    check(scene.visual_actors[actor].row.position==chosen.target.position,"Native body finishes at canonical destination")
    var receipt=await request("receipt",{"number":command})
    if receipt.ok:check(receipt.value.receipt.kind=="committed","Original delayed command committed")
    evidence.actions.append({"behavior":"action.move","command":command,"samples":samples})
    evidence.prediction={"waiting_frames":waiting_frames,"native_no_rewind":no_rewind,"max_frame_ms":max_frame,"state":scene.Prediction.diagnostics(scene.prediction),"delay_ms":scene.game_config.test_command_delay_ms}
    await movement("action.jump",true)
    evidence.prediction.after_jump=scene.Prediction.diagnostics(scene.prediction)
    await finish()
