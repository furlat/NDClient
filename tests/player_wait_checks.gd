extends "res://tests/player_live_checks.gd"
# Real Crypt, real end-turn command, native HTTP/SSE through a test-only delayed
# forwarder. Camera input and original AnimationTree sampling must keep running.
func _run() -> void:
    scene=Player.instantiate(); root.add_child(scene)
    if not await until(ready,"Real Crypt initializes before delayed command"): await finish(); return
    var actor: String=scene.session.status.boundary.input_actor_uuid
    var command: int=scene.session.status.next_command_number
    var before_frame=Engine.get_process_frames()
    var before_camera: Vector3=scene.camera.position
    var before_display: float=scene.timeline.display_ms
    var source_times={}
    var frame_intervals: Array=[]
    var last_tick=Time.get_ticks_usec()
    var started_wait=Time.get_ticks_msec()
    var max_age=0
    scene.end_turn()
    check(scene.command_busy,"Native end-turn command is awaiting a server response")
    # Use actual player camera input; no replacement frame or animation loop.
    var wheel=InputEventMouseButton.new(); wheel.button_index=MOUSE_BUTTON_WHEEL_UP
    wheel.pressed=true; wheel.position=Vector2(640,420)
    var original_size: float=scene.camera.size
    root.push_input(wheel,true)
    while scene.command_busy and healthy() and Time.get_ticks_msec()-started_wait<15000:
        await scene.presentation_updated
        var now=Time.get_ticks_usec(); frame_intervals.append((now-last_tick)/1000.0); last_tick=now
        if scene.playbacks.has(actor): source_times[scene.playbacks[actor].sample_seconds]=true
        max_age=maxi(max_age,int(scene.session.diagnostics().network.get("oldest_request_ms",0)))
    var elapsed=Time.get_ticks_msec()-started_wait
    check(elapsed>=int(scene.game_config.test_command_delay_ms)-100,"Actual command response experiences injected server-side wait")
    check(Engine.get_process_frames()-before_frame>20,"Scene frame callbacks continue while command awaits server")
    check(scene.camera.size<original_size,"Actual viewport wheel input changes camera while command is pending")
    check(source_times.size()>4 and scene.timeline.display_ms>before_display,"Native AnimationTree sampling and presentation clock continue during network wait")
    check(max_age>=int(scene.game_config.test_command_delay_ms)-150,"Client exposes pending HTTP wall-time separately from frame work")
    frame_intervals.sort()
    evidence.delayed_server={"delay_ms":scene.game_config.test_command_delay_ms,"observed_command_ms":elapsed,
        "frames":Engine.get_process_frames()-before_frame,"distinct_animation_samples":source_times.size(),
        "frame_p95_ms":frame_intervals[int((frame_intervals.size()-1)*.95)] if not frame_intervals.is_empty() else 0,
        "frame_max_ms":frame_intervals.back() if not frame_intervals.is_empty() else 0,"network_oldest_ms":max_age,
        "client_execution":scene.session.diagnostics()}
    await until(func():return ready() and scene.session.status.next_command_number>command,"Delayed real end-turn eventually commits and scene catches up")
    var receipt=await request("receipt",{"number":command})
    if receipt.ok: check(receipt.value.receipt.kind=="committed","Delayed command receives its original committed receipt")
    await finish()

func finish() -> void:
    scene.set_process(false)
    evidence.profile=FrameProfile.save(scene.profile,root,"player-wait",false)
    if DisplayServer.get_name()!="headless":
        await RenderingServer.frame_post_draw
        var screenshot: String=scene.game_config.test_result.get_base_dir().path_join("player-wait.png")
        check(root.get_texture().get_image().save_png(screenshot)==OK,"Native wait-test viewport saved")
        evidence.screenshot=screenshot
    var closing = Time.get_ticks_msec()
    scene.session.close()
    evidence.session_close_ms = Time.get_ticks_msec()-closing
    evidence.retirement_after_close = scene.session.diagnostics()
    check(evidence.retirement_after_close.retirement_pending_groups==0 and evidence.retirement_after_close.retired_groups==scene.timeline.completed_group_count,"Native close drains completed presentation data before worker exit")
    check(scene.session.issue.is_empty() and scene.presentation_errors.is_empty(),"No SDK or presentation errors during delayed response")
    var replay=Journal.new()
    var opened=replay.open(scene.game_config.journal)
    check(opened.ok and replay.state==scene.timeline.state and replay.state==scene.session.journal.state,"Delayed command displayed state equals cold-replayed durable state")
    var report={"checks":checks,"failures":failures,"elapsed_ms":Time.get_ticks_msec()-started,"evidence":evidence,"render_mode":DisplayServer.get_name()}
    FileAccess.open(scene.game_config.test_result,FileAccess.WRITE).store_string(JSON.stringify(report,"  ",true,true))
    print("PLAYER_WAIT_CHECKS ",JSON.stringify(report))
    scene.queue_free(); await process_frame
    quit(0 if failures.is_empty() else 1)
