extends SceneTree
# Actual recorded source art, paused at its initial state. Exercise a cold
# Solid camera roundtrip before the first coverage mask is ever requested.
const Player = preload("res://play.tscn")
var checks = 0
var failures: Array = []
func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok: failures.append(label); print("WALL_MODE_FAIL ",label)
func _initialize() -> void: run.call_deferred()
func view(scene: Node, quarter: int) -> void:
    scene.set_process(true); scene.request_view(quarter)
    var deadline = Time.get_ticks_msec()+60000
    while scene.rotation_pending() and Time.get_ticks_msec()<deadline: await scene.presentation_updated
    check(not scene.rotation_pending() and scene.quarter==quarter,"Camera publishes quarter "+str(quarter))
func first_frame(scene: Node) -> Image:
    scene.set_process(true)
    await scene.presentation_updated
    scene.set_process(false)
    await RenderingServer.frame_post_draw
    return root.get_texture().get_image()
func mode(scene: Node, value: String) -> void:
    scene.wall_mode=value; scene.update_wall_visibility()
func run() -> void:
    root.unfocusable=true; root.position=Vector2i(-16000,-16000); root.size=Vector2i(1280,800)
    var scene=Player.instantiate(); scene.timeline.paused=true; root.add_child(scene)
    scene.wall_mode="solid"; scene.initial_focus=true
    scene.camera_focus=Vector3(4,0,5); scene.camera.size=8.137; scene.position_camera()
    scene.fire_light_flicker=false; scene.source_lighting.fire_light_flicker=false
    scene.grid_visible=false; scene.hud.hide()
    var deadline=Time.get_ticks_msec()+180000
    while (not scene.session.recording_ready or not scene._media_ready({}) or scene.world_revision<0) and scene.session.issue.is_empty() and scene.media_issue.is_empty() and Time.get_ticks_msec()<deadline:
        await process_frame
    check(scene.world_revision>=0 and scene.session.issue.is_empty(),"Actual journal initial world publishes")
    if not failures.is_empty(): scene.queue_free(); await process_frame; finish(); return
    scene.session.close(); await scene.presentation_updated; scene.set_process(false)
    var canonical=scene.timeline.state.duplicate(true)
    var clock: float=scene.timeline.display_ms
    check(scene.wall_mask_viewport==null,"Cold solid view has not allocated unused coverage")
    await view(scene,1); await view(scene,0)
    check(scene.wall_mask_viewport==null,"Solid camera roundtrip remains cold before first translucent request")
    mode(scene,"translucent")
    var first=await first_frame(scene)
    check(scene.wall_mask_viewport!=null,"First translucent frame supplies native coverage")
    if scene.wall_mask_viewport!=null:
        var coverage=scene.wall_mask_viewport.get_texture().get_image()
        var painted=0
        for y in range(0,coverage.get_height(),4):
            for x in range(0,coverage.get_width(),4):
                if coverage.get_pixel(x,y).a8>0: painted+=1
        check(painted>100,"First translucent frame contains actual painted wall coverage")
    await process_frame; await RenderingServer.frame_post_draw
    var settled=root.get_texture().get_image()
    check(first.get_data()==settled.get_data(),"First translucent draw has no stale coverage versus settled draw")
    # Resize/pan while coverage is disabled, then consume the deferred work on
    # the very first translucent frame; repeated native draws must be stable.
    mode(scene,"hidden"); await first_frame(scene)
    root.size=Vector2i(1373,817); scene.camera.size=9.1
    scene.camera_focus=Vector3(4.13,0,5.27); scene.position_camera()
    mode(scene,"solid"); await first_frame(scene)
    mode(scene,"translucent"); first=await first_frame(scene)
    await process_frame; await RenderingServer.frame_post_draw
    settled=root.get_texture().get_image()
    check(first.get_data()==settled.get_data(),"Deferred viewport/camera and wall selection publish together")
    check(scene.timeline.state==canonical and scene.timeline.display_ms==clock,"Camera/modes preserve canonical state and event clock")
    check(scene.presentation_errors.is_empty(),"No source or renderer errors")
    scene.queue_free(); await process_frame; await process_frame; finish()
func finish() -> void:
    var report={"checks":checks,"failures":failures,"scope":"Actual journal initial state; cold Solid q0-q1-q0 camera cycle, first translucent coverage pixels, deferred Hidden/Solid camera and viewport changes, first-versus-settled native framebuffer, unchanged canonical state/clock. No timing claim."}
    FileAccess.open("res://generated/wall_mode_lifecycle_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("WALL_MODE_LIFECYCLE ",JSON.stringify(report)); quit(0 if failures.is_empty() else 1)
