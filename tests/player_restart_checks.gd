extends "res://tests/player_live_checks.gd"
# The real menu resets a changed backend encounter while this scene and its
# rendering resources stay alive. Exercise the replacement session twice.

func _run() -> void:
    root.unfocusable = true
    root.position = Vector2i(-16000,-16000)
    scene = Player.instantiate()
    root.add_child(scene)
    if not await until(ready,"Initial encounter becomes playable"):
        await _finish_restart();return
    var process_id = OS.get_process_id()
    var scene_id = scene.get_instance_id()
    var camera_id = scene.camera.get_instance_id()
    var hud_id = scene.hud.get_instance_id()
    var viewport = scene.get_viewport().get_viewport_rid()
    var media = scene.MediaWarmup.physical(scene.media_warmup)
    var origin: Array = scene.timeline.state.actors[scene.available_actions.entity_uuid].last_visual_position.duplicate()
    var first_command = scene.session.status.next_command_number
    var initial_textures: Dictionary = {}
    for path in scene.media_plan.required:
        if scene.textures.get(path) != null:
            initial_textures[path] = scene.textures[path].get_rid()
    check(not initial_textures.is_empty(),"Initial displayed media has resident native textures")
    evidence.restarts = []
    for iteration in range(2):
        if not await movement("action.move",true):
            await _finish_restart();return
        var prior_session = scene.session
        var prior_epoch: String = scene.session.status.game_epoch
        var prior_journal: String = scene.game_config.journal
        var prior_cursor: Dictionary = scene.session.journal.cursor.duplicate()
        var prior_state: Dictionary = scene.session.journal.state
        check(not scene.Interaction.same_position(scene.timeline.state.actors[scene.available_actions.entity_uuid].last_visual_position,origin),"Move changed the encounter before restart")
        scene.hud.open_settings()
        var button: Button = scene.hud.settings_panel.restart_button
        check(button.visible and not button.disabled,"Menu offers Restart game for the owned encounter")
        button.pressed.emit()
        check(not ready(),"Restart immediately blocks commands from the old encounter")
        if not await until(func():return ready() and scene.session.status.game_epoch != prior_epoch,"Restart returns to a fresh playable encounter"):
            await _finish_restart();return
        check(not button.disabled,"Open menu enables Restart game again after completion")
        scene.hud.close_settings()
        check(OS.get_process_id()==process_id and scene.get_instance_id()==scene_id,"Restart keeps the same process and Play node")
        check(scene.camera.get_instance_id()==camera_id and scene.hud.get_instance_id()==hud_id and scene.get_viewport().get_viewport_rid()==viewport,"Restart keeps the camera, HUD and native viewport")
        check(is_same(media,scene.MediaWarmup.physical(scene.media_warmup)),"Restart retains the loaded media owner")
        var retained = 0
        for path in initial_textures:
            if scene.textures.get(path)!=null and scene.textures[path].get_rid()==initial_textures[path]:retained+=1
        check(retained==initial_textures.size(),"Initial displayed textures keep their native allocations across restart")
        check(not is_same(prior_session,scene.session) and prior_session.cancelled,"Old session retires before the fresh encounter attaches")
        check(scene.session.status.next_command_number==first_command,"Backend command counter returns to its initial value")
        check(scene.Interaction.same_position(scene.timeline.state.actors[scene.available_actions.entity_uuid].last_visual_position,origin),"Restart restores the backend actor's starting position")
        check(scene.game_config.journal!=prior_journal,"Fresh encounter has its own journal")
        var old_recording = Journal.new()
        var replayed = old_recording.open(prior_journal)
        check(replayed.ok and old_recording.cursor==prior_cursor and old_recording.state==prior_state,"Previous encounter recording remains complete and replayable")
        check(scene.timeline.state==scene.session.journal.state,"Fresh rendered encounter matches canonical backend state")
        evidence.restarts.append({"iteration":iteration+1,"old_epoch":prior_epoch,"new_epoch":scene.session.status.game_epoch,
            "old_journal":prior_journal,"new_journal":scene.game_config.journal,"retained_textures":retained,"process_id":process_id})
    # New choices, command IDs, follower, playback and callbacks must still work.
    if not await movement("action.move",true):
        await _finish_restart();return
    # A real failed bootstrap after an accepted reset must leave this window
    # alive and allow attachment to that same fresh encounter on retry.
    var live_url: String = scene.game_config.url
    scene.game_config.url=live_url+"/unavailable"
    scene.hud.open_settings()
    scene.hud.settings_panel.restart_button.pressed.emit()
    var deadline=Time.get_ticks_msec()+30000
    while scene.restart_error.is_empty() and Time.get_ticks_msec()<deadline:await process_frame
    check(not scene.restart_error.is_empty(),"Failed bootstrap reports a restart error in the retained client")
    check(OS.get_process_id()==process_id and not scene.hud.settings_panel.restart_button.disabled,"Failed attachment retains the process and enables retry")
    var accepted_epoch: String = scene.restart_expected_epoch
    check(not accepted_epoch.is_empty(),"Accepted replacement epoch is retained for attachment retry")
    scene.game_config.url=live_url
    scene.hud.settings_panel.restart_button.pressed.emit()
    if not await until(ready,"Retry attaches after the bootstrap endpoint is restored"):
        await _finish_restart();return
    check(scene.session.status.game_epoch==accepted_epoch,"Retry attaches to the accepted encounter without resetting it again")
    check(scene.restart_error.is_empty() and OS.get_process_id()==process_id,"Successful retry clears the error and preserves the client")
    scene.hud.close_settings()
    await movement("action.move",true)
    await _finish_restart()

func _finish_restart() -> void:
    scene.set_process(false)
    check(scene.session.issue.is_empty(),"No session failure after encounter replacement")
    check(scene.presentation_errors.is_empty(),"No presentation failure after encounter replacement")
    var report = {"checks":checks,"failures":failures,"elapsed_ms":Time.get_ticks_msec()-started,"evidence":evidence}
    FileAccess.open(scene.game_config.test_result,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("PLAYER_RESTART_CHECKS ",JSON.stringify(report))
    scene.queue_free()
    await process_frame
    quit(0 if failures.is_empty() else 1)
