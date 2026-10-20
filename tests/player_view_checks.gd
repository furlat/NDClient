extends SceneTree
# Real recorded packets enter the production session/compiler and native scene.
const Player = preload("res://play.tscn")
var checks = 0
var failures: Array = []
func check(value: bool,message: String) -> void:
    checks += 1
    if not value: failures.append(message); print("PLAYER_VIEW_FAIL ",message)

func check_painted_order(scene: Node) -> void:
    # The optimization must retain the established painter order at actual
    # movement, visibility and quarter-view boundaries.
    var expected: Array = (scene.static_entries+scene.actor_entries+scene.ground_overlay.ordered).filter(func(entry):return entry.node.visible)
    expected.sort_custom(func(a,b):
        var ak = scene.Order.key(a.placement,a.role,a.layer,scene.quarter,scene.ground_is_background)
        var bk = scene.Order.key(b.placement,b.role,b.layer,scene.quarter,scene.ground_is_background)
        return scene.Order.less(ak,bk) if ak != bk else a.id < b.id)
    check(scene.draw_order.map(func(entry):return entry.id) == expected.map(func(entry):return entry.id),
        "Displayed painter order matches uncached source ordering")

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
    var scene = Player.instantiate()
    scene.timeline.paused = true
    root.add_child(scene)
    var deadline = Time.get_ticks_msec()+120000
    while not scene.session.recording_ready and scene.session.issue.is_empty() and Time.get_ticks_msec()<deadline:
        await process_frame
    check(scene.session.issue.is_empty(),"Recording compiles: "+str(scene.session.issue))
    check(scene.session.recording_ready,"Recording initialization prepares while presentation is paused")
    # Initialization admission is independent of asynchronous source preparation.
    # Keep the actual scene running until its media gate accepts the snapshot,
    # then wait for the renderer to consume that readiness on the scene thread.
    while scene.session.recording_ready and not scene._media_ready({}) and scene.session.issue.is_empty() and scene.media_issue.is_empty() and Time.get_ticks_msec()<deadline:
        await process_frame
    check(scene.media_initial_ready,"Initialization media finishes before native visual assertions: "+str(scene.media_issue))
    if not failures.is_empty():
        await finish(scene,{"checks":checks,"failures":failures})
        return
    await scene.presentation_updated
    check(scene.timeline.sequence==0,"Paused scene retains initialization instead of latest state")
    check_painted_order(scene)
    var initial = scene.presentation_diagnostics()
    check(not initial.actors.is_empty(),"Disclosed actors have native render layers")
    for id in scene.timeline.state.audience.controlled:
        if scene.timeline.state.actors[id].present:
            check(initial.actors.has(id),"Controlled actor renders without needing a self contact: "+id)
    check(initial.errors.is_empty(),"Authored actor identities and equipment resolve: "+str(initial.errors))
    check(initial.unresolved.is_empty(),"Disclosed environment resolves: "+str(initial.unresolved))
    scene.timeline.paused = false
    scene.timeline.advance(300)
    scene.timeline.paused = true
    await scene.presentation_updated
    var sampled = scene.presentation_diagnostics()
    for q in range(4):
        scene.request_view(q)
        while scene.rotation_pending() and Time.get_ticks_msec()<deadline:
            await scene.presentation_updated
        check(not scene.rotation_pending() and scene.quarter==q,"Requested native quarter publishes before visual assertions")
        await scene.presentation_updated
        check_painted_order(scene)
        var rotated = scene.presentation_diagnostics()
        for id in sampled.actors:
            check(rotated.actors[id].position==sampled.actors[id].position,"Camera preserves actor contact "+id)
            check(is_equal_approx(rotated.actors[id].source_seconds,sampled.actors[id].source_seconds),"Camera preserves animation clock "+id)
        if DisplayServer.get_name() != "headless":
            await RenderingServer.frame_post_draw
            DirAccess.make_dir_recursive_absolute("res://.captures/player")
            root.get_texture().get_image().save_png("res://.captures/player/view-%d.png" % q)
    var rendered_motion: Array = []
    while (scene.timeline.busy() or scene.timeline.sequence<scene.session.latest_sequence) and scene.session.issue.is_empty() and Time.get_ticks_msec()<deadline:
        # Discover probes in each newly admitted bounded window, not only the
        # initial queue. Preparation may yield more groups after this frame.
        var probe = {}
        var groups: Array = scene.timeline.queue.duplicate()
        var offset: float = scene.timeline.display_ms
        if not scene.timeline.current.is_empty():
            groups.push_front(scene.timeline.current)
            offset = scene.timeline.group_start_ms
        for group in groups:
            for track in group.actor_tracks:
                var midpoint: float = offset+track.start_ms+track.duration_ms*.5
                if track.get("motion",false) and midpoint>scene.timeline.display_ms+.0001 and (probe.is_empty() or midpoint<probe.at_ms):
                    probe={"at_ms":midpoint,"track":track}
            offset += group.duration_ms
        var target: float = probe.at_ms if not probe.is_empty() else offset+.001
        scene.timeline.paused = false
        scene.timeline.advance(maxf(0,target-scene.timeline.display_ms))
        scene.timeline.paused = true
        await scene.presentation_updated
        if probe.is_empty() or absf(scene.timeline.display_ms-probe.at_ms)>.0001: continue
        check_painted_order(scene)
        var track: Dictionary = probe.track
        var actor: Dictionary = scene.presentation_diagnostics().actors.get(track.actor_uuid,{})
        check(not actor.is_empty(),"Moving actor remains rendered")
        if actor.is_empty(): continue
        var expected = Vector2(track.from_position[0]+track.to_position[0],track.from_position[1]+track.to_position[1])*0.5
        check(actor.rendered_position != null and Vector2(actor.rendered_position[0],actor.rendered_position[1]).distance_to(expected)<0.0001,"Native sprite reaches committed edge midpoint")
        if track.trajectory == "direct_arc":
            check(actor.rendered_height > actor.height,"Authored jump lifts body above its support")
            var fraction = (track.motion_fraction_from+track.motion_fraction_to)*0.5
            var expected_lift = sin(PI*fraction)*track.arc_height_px*(128.0/scene.rig_config.TILE_W)/64.0
            check(is_equal_approx(actor.rendered_height-actor.height,expected_lift),"Native jump uses authored pixel scale")
        if DisplayServer.get_name() != "headless" and rendered_motion.is_empty():
            await RenderingServer.frame_post_draw
            root.get_texture().get_image().save_png("res://.captures/player/motion.png")
        rendered_motion.append({"at_ms":probe.at_ms,"actor":actor})
    check(not rendered_motion.is_empty(),"Real recording supplies and renders at least one motion midpoint")
    check(not scene.timeline.busy() and scene.timeline.sequence==scene.session.latest_sequence,"Every recording operation drains completely")
    check(scene.timeline.state==scene.session.journal.state,"Displayed terminal state equals canonical SDK journal")
    check(scene.presentation_errors.is_empty(),"Playback has no unresolved actor presentation")
    check_painted_order(scene)
    var final = scene.presentation_diagnostics()
    for id in final.actors:
        var actor: Dictionary = final.actors[id]
        if actor.rendered_position == null: continue
        var expected: Array = scene.timeline.state.actors[id].last_visual_position
        check(actor.position==expected,"Final displayed actor contact equals disclosed state")
        check(Vector2(actor.rendered_position[0],actor.rendered_position[1]).distance_to(Vector2(expected[0],expected[1]))<0.0001,"Final native sprite settles at disclosed contact")
        check(is_equal_approx(actor.rendered_height,actor.height),"Final body settles on support")
    var report = {"checks":checks,"failures":failures,"initial":initial,"sampled":sampled,"rendered_motion":rendered_motion,"final":final}
    await finish(scene,report)

func finish(scene: Node, report: Dictionary) -> void:
    DirAccess.make_dir_recursive_absolute("res://generated")
    var file = FileAccess.open("res://generated/player_view_checks.json",FileAccess.WRITE)
    file.store_string(JSON.stringify(report,"  ",true,true));file.close()
    print(JSON.stringify({"checks":checks,"failures":failures}))
    scene.queue_free()
    await process_frame
    quit(0 if failures.is_empty() else 1)
