extends SceneTree
# Slow acceptance lane: use the real player scene, its public action handlers,
# real choices/preview/commands and native animation clocks. No injected state.
const Player = preload("res://play.tscn")
const LoadingPresentation=preload("res://loading.gd")
const Journal = preload("res://sdk/journal.gd")
const JSONCodec = preload("res://sdk/strict_json.gd")
const Placement = preload("res://placement.gd")
const FrameProfile = preload("res://frame_profile.gd")
const Choices = preload("res://sdk/choices.gd")
var scene: Node
var startup_notice:LoadingPresentation
var checks = 0
var failures: Array = []
var evidence: Dictionary = {"actions":[], "jump_offered":false, "reconnect":false}
var started = Time.get_ticks_msec()

func _initialize() -> void: _run.call_deferred()

func show_loading_notice(message:String)->void:
    if startup_notice==null:
        startup_notice=LoadingPresentation.new()
        startup_notice.start_player=false
        root.add_child(startup_notice)
    startup_notice.label.text=message
    startup_notice.move_to_front()

func close_loading_notice()->void:
    if startup_notice==null:return
    startup_notice.queue_free()
    startup_notice=null

func check(value: bool, message: String) -> void:
    checks += 1
    if not value: failures.append(message); print("PLAYER_LIVE_FAIL ",message)

func healthy() -> bool:
    return scene.session.issue.is_empty() and scene.presentation_errors.is_empty() and Time.get_ticks_msec()-started < 180000

func ready() -> bool:
    return scene.command_ready()

func until(predicate: Callable, label: String, timeout: int = 60000) -> bool:
    var deadline = Time.get_ticks_msec()+timeout
    while not predicate.call() and healthy() and Time.get_ticks_msec() < deadline: await process_frame
    var success: bool = predicate.call() and healthy()
    check(success, label + ("; notice="+scene.notice_text+" issue="+str(scene.session.issue)+" presentation="+str(scene.presentation_errors) if not success else ""))
    return success

func request(operation: String, arguments: Dictionary = {}) -> Dictionary:
    var id: int = scene.session.request(operation, arguments)
    if not await until(func():return scene.session.responses.has(id), "Native " + operation + " response"):
        return {"ok":false}
    var result: Dictionary = scene.session.responses[id]
    scene.session.responses.erase(id)
    check(result.ok, "Native " + operation + " succeeds: " + str(result.get("error", "")))
    return result

func select_position(behavior: String) -> Dictionary:
    var current: Array = scene.timeline.state.actors[scene.available_actions.entity_uuid].last_visual_position
    var best: Dictionary = {}
    var distance = INF
    for action in scene.available_actions.position_actions:
        if action.behavior_id != behavior or not action.can_afford: continue
        for target in Choices.action_options(scene.available_actions,action):
            var coordinate: Variant = Choices.binding_position(scene.available_actions,target)
            if coordinate == null: continue
            var p: Array = coordinate
            if behavior == "action.move":
                var screen = grid_screen(p)
                scene.update_wall_visibility()
                if not root.get_visible_rect().has_point(screen) or scene.pick_world(screen).get("kind") != "ground" or not scene.Interaction.same_position(scene.pick_cell(screen).get("position"),p) or scene.hud.pointer_over_controls(screen): continue
            var delta = absf(p[0]-current[0])+absf(p[1]-current[1])
            if delta > 0 and delta < distance:
                best = {"action":action,"target":target}
                distance = delta
    return best

func grid_screen(position: Array) -> Vector2:
    var tile: Dictionary = scene.timeline.state.tiles["%d,%d" % [position[0],position[1]]]
    return scene.camera.unproject_position(Vector3(position[0],tile.elevation_steps*Placement.HEIGHT_UNIT,position[1]))

func click_grid(position: Array) -> void:
    var screen = grid_screen(position)
    check(scene.Interaction.same_position(scene.pick_cell(screen).get("position"),position),"Viewport ray picks the disclosed target cell")
    check(scene.pick_actor(screen).is_empty(),"Target click does not overlap an actor pixel")
    var motion = InputEventMouseMotion.new()
    motion.position = screen; motion.global_position = screen
    scene.get_viewport().push_input(motion,true)
    var click = InputEventMouseButton.new()
    click.position = screen; click.global_position = screen
    click.button_index = MOUSE_BUTTON_LEFT; click.pressed = true
    scene.get_viewport().push_input(click,true)
    var release: InputEventMouseButton = click.duplicate()
    release.pressed = false
    scene.get_viewport().push_input(release,true)
    evidence.viewport_click = {"target":position,"screen":[screen.x,screen.y]}

func observe_actor(id: String, samples: Array) -> void:
    if not scene.visual_actors.has(id): return
    var visual: Dictionary = scene.visual_actors[id]
    var sample: Dictionary = scene.displayed_samples.get(id,{})
    if sample.is_empty(): return
    var body: Node3D
    var shadow: Node3D
    for entry in visual.entries:
        if entry.node.visible and entry.role == "body" and body == null: body = entry.node
        if entry.node.visible and entry.role == "shadow": shadow = entry.node
    if body == null: return
    var source: Node = scene.playbacks[id]
    var value = {"position":visual.row.position.duplicate(), "height":visual.row.base_height_steps,
        "clip":source.clip, "source_seconds":source.sample_seconds, "body_position":[body.position.x,body.position.y,body.position.z],
        "lift_pixels":sample.get("lift_pixels",0.0), "ground_y":Placement.contact(visual.row).y,
        "shadow_y":shadow.position.y if shadow != null else null}
    if samples.is_empty() or samples.back() != value: samples.append(value)

func movement(behavior: String, required: bool) -> bool:
    var selected = select_position(behavior)
    if selected.is_empty():
        if required: check(false,"Native encounter offers a legal " + behavior + " target")
        else: evidence.jump_skip = "Native choices offered no affordable jump after walking"
        return not required
    if behavior == "action.jump": evidence.jump_offered = true
    var actor: String = scene.available_actions.entity_uuid
    var initial: Array = scene.timeline.state.actors[actor].last_visual_position.duplicate()
    var target: Array = Choices.binding_position(scene.available_actions,selected.target).duplicate()
    var command: int = scene.session.status.next_command_number
    var prior_sequence: int = scene.timeline.sequence
    scene.selected_mode = behavior
    if behavior == "action.move": click_grid(target)
    else:
        scene.select_behavior(behavior)
        # Region choices already disclose their initial targets. The production
        # handler requests Preview after choosing the target, not on selection.
        if not await until(func():return ready() and not scene.selected_action.is_empty() and (scene.selected_action.get("position_region")!=null or not scene.selection_preview.is_empty()),"Native action selection admits its disclosed targets"): return false
        scene.choose_target(target)
    check(scene.command_busy and scene.pending_request.kind == ("command" if behavior=="action.move" else "preview"), "Scene submits complete movement or previews compound action: " + behavior)
    var samples: Array = []
    var deadline = Time.get_ticks_msec()+60000
    while healthy() and Time.get_ticks_msec() < deadline:
        observe_actor(actor,samples)
        if ready() and scene.timeline.sequence > prior_sequence and scene.session.status.next_command_number > command: break
        await scene.presentation_updated
    check(ready() and scene.timeline.sequence > prior_sequence, "Scene completes native action and presentation: " + behavior)
    if not healthy(): return false
    var receipt = await request("receipt",{"number":command})
    if not receipt.ok: return false
    check(receipt.value.receipt.kind == "committed", "Native action receipt committed: " + behavior)
    check(scene.Interaction.same_position(scene.timeline.state.actors[actor].last_visual_position,target), "Backend position equals selected legal target: " + behavior)
    check(scene.Interaction.same_position(scene.visual_actors[actor].row.position,target), "Rendered actor reaches backend destination: " + behavior)
    check(samples.any(func(value):return not scene.Interaction.same_position(value.position,initial) and not scene.Interaction.same_position(value.position,target)), "Native render interpolation observed: " + behavior)
    var expected: String = "Rolling" if behavior == "action.jump" else "Run"
    check(samples.any(func(value):return value.clip == expected and value.source_seconds > 0), "Authored native animation advances: " + behavior)
    check(samples.all(func(value):return is_equal_approx(value.body_position[0],value.position[0]) and is_equal_approx(value.body_position[2],value.position[1])), "Rendered body follows displayed grid contact: " + behavior)
    if behavior == "action.jump":
        check(samples.any(func(value):return value.lift_pixels > 0 and value.body_position[1] > value.ground_y), "Jump body rises above authoritative support")
        check(samples.all(func(value):return value.shadow_y == null or is_equal_approx(value.shadow_y,value.ground_y)), "Jump shadow remains on support")
    evidence.actions.append({"behavior":behavior,"actor_uuid":actor,"from":initial,"to":target,
        "command_number":command,"receipt":receipt.value.receipt,"samples":samples})
    return failures.is_empty()

func _run() -> void:
    scene = Player.instantiate()
    root.add_child(scene)
    if not await until(ready, "Production scene receives initial native choices"): await finish(); return
    var capture = scene.game_config.test_result.get_base_dir()
    for entry in [{"name":"discovery.json","value":scene.available_actions},{"name":"state.json","value":scene.timeline.state}]:
        var file = FileAccess.open(capture.path_join(entry.name),FileAccess.WRITE)
        file.store_string(JSON.stringify(entry.value)); file.close()
    evidence.ready_frame = Engine.get_process_frames()
    evidence.ready_elapsed_ms = Time.get_ticks_msec()-started
    check(not scene.visual_actors.is_empty(),"Initial actors have render geometry")
    if not await movement("action.move",true): await finish(); return
    if not await movement("action.jump",false): await finish(); return
    var completed: Array = scene.timeline.completed_groups.duplicate(true)
    var prior_sequence: int = scene.timeline.sequence
    var prior_actor: String = scene.session.status.boundary.input_actor_uuid
    var command: int = scene.session.status.next_command_number
    var reconnect = await request("reconnect")
    if not reconnect.ok: await finish(); return
    evidence.reconnect = true
    scene.end_turn()
    check(scene.command_busy, "Production end-turn handler submits a command")
    if not await until(func():return ready() and scene.timeline.sequence > prior_sequence and scene.session.status.next_command_number > command,
        "Reconnected follower receives end-turn operation and scene presents it"): await finish(); return
    var receipt = await request("receipt",{"number":command})
    if receipt.ok: check(receipt.value.receipt.kind == "committed", "End-turn receipt committed")
    check(scene.timeline.completed_groups.slice(0,completed.size()) == completed, "Reconnect preserves completed presentation groups exactly")
    var ids: Dictionary = {}
    for group in scene.timeline.completed_groups: ids[group.id] = true
    check(ids.size() == scene.timeline.completed_groups.size(), "Reconnect does not duplicate presentation occurrences")
    check(scene.session.status.boundary.input_actor_uuid != prior_actor, "Native turn passes to the next actor")
    evidence.end_turn = {"command_number":command,"from_actor":prior_actor,"next_actor":scene.session.status.boundary.input_actor_uuid}
    await finish()

func finish() -> void:
    scene.set_process(false)
    evidence.profile = FrameProfile.save(scene.profile,root,"player-live",false)
    evidence.profile_notes = "History starts after the first process callback and includes subsequent asset loading/admission. Frames after ready_frame cover live interactions after initial readiness. Neither includes engine launch/import cost; profile export and screenshot readback occur after sampling stops."
    if DisplayServer.get_name() != "headless":
        await RenderingServer.frame_post_draw
        var screenshot: String = scene.game_config.test_result.get_base_dir().path_join("player-live.png")
        var code = root.get_texture().get_image().save_png(screenshot)
        check(code == OK,"Native rendered viewport screenshot saved")
        evidence.screenshot = screenshot
    scene.session.close()
    check(scene.session.issue.is_empty(), "SDK reports no live-session failure")
    check(scene.presentation_errors.is_empty(), "Scene reports no authored presentation failure")
    if not scene.timeline.state.is_empty() and not scene.timeline.busy():
        check(scene.timeline.state == scene.session.journal.state, "Displayed state equals canonical SDK state after actions")
    var replay = Journal.new()
    var reopened = replay.open(scene.game_config.journal)
    check(reopened.ok and replay.state == scene.session.journal.state, "Recorded live actions cold-replay exactly")
    var direct_arc = 0
    var steps = 0
    for name in DirAccess.get_files_at(scene.game_config.journal):
        if not name.ends_with(".json"): continue
        var decoded = JSONCodec.new().parse(FileAccess.get_file_as_string(scene.game_config.journal.path_join(name)))
        if not decoded.ok: continue
        for lineage in decoded.value.get("lineages",[]):
            for node in lineage.events:
                if node.get("fact") == null: continue
                if node.fact.kind == "step" and node.fact.committed:
                    steps += 1
                    if node.fact.trajectory == "direct_arc": direct_arc += 1
    check(steps > 0,"Real journal contains committed movement facts")
    if evidence.jump_offered: check(direct_arc > 0,"Real journal contains the committed authored jump")
    evidence.committed_steps = steps
    evidence.direct_arc_steps = direct_arc
    evidence.final = scene.presentation_diagnostics()
    var report = {"checks":checks,"failures":failures,"elapsed_ms":Time.get_ticks_msec()-started,"evidence":evidence,
        "render_mode":DisplayServer.get_name()}
    var file = FileAccess.open(scene.game_config.test_result,FileAccess.WRITE)
    file.store_string(JSON.stringify(report,"  ",true,true)); file.close()
    print(JSON.stringify({"checks":checks,"failures":failures,"elapsed_ms":report.elapsed_ms,"actions":evidence.actions.size(),
        "jump_offered":evidence.jump_offered,"direct_arc_steps":direct_arc,"reconnect":evidence.reconnect}))
    # Populate the existing empty-root teardown draw after saved evidence.
    # No pre-join draw or shorter synchronous retirement is implied.
    show_loading_notice("Closing the encounter…")
    scene.queue_free()
    await process_frame
    quit(0 if failures.is_empty() else 1)
