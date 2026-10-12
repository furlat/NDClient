extends "res://tests/world_incremental_checks.gd"
# Native atomic camera publication against a real admitted Crypt. The final
# visibility/elevation edits below are explicitly named renderer fixtures.
var timings: Array = []
func drain_view(scene: Node,target: int) -> void:
    var original: int = scene.quarter
    var original_basis: Basis = scene.camera.basis
    var original_root: Node3D = scene.sprite_parent
    var start = Time.get_ticks_usec()
    var frames = 0; var maximum = 0.0; var phases = {}; var poses = {}
    var deadline = Time.get_ticks_msec()+60000
    while scene.rotation_pending() and Time.get_ticks_msec()<deadline:
        var begun = Time.get_ticks_usec()
        scene.timeline.display_ms += 16
        scene._sample_actors(); scene._sample_fixtures()
        if scene.pending_view != null: phases[scene.pending_view.phase] = true
        scene._prepare_rotation()
        scene._sort_draws()
        maximum = maxf(maximum,(Time.get_ticks_usec()-begun)/1000.0)
        if scene.rotation_pending():
            check(scene.quarter==original and scene.camera.basis==original_basis and original_root.is_visible_in_tree(),"Preparation preserves the current camera, view ownership and visible sprites")
            for playback in scene.playbacks.values(): poses[str(playback.sample_seconds)] = true
        await process_frame
        frames += 1
    check(not scene.rotation_pending() and scene.quarter==target and scene.world_quarter==target,"Only the completely prepared target quarter publishes")
    timings.append({"target":target,"frames":frames,"elapsed_ms":(Time.get_ticks_usec()-start)/1000.0,"max_prepare_and_publish_cpu_ms":maximum,"phases":phases.keys(),"old_view_pose_samples":poses.size()})

func run() -> void:
    if DisplayServer.get_name()=="headless":quit(2);return
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(960,640)
    var scene=Player.instantiate();scene.timeline.paused=true;root.add_child(scene)
    var deadline=Time.get_ticks_msec()+120000
    while (not scene.session.recording_ready or not scene._media_ready({})) and scene.session.issue.is_empty() and Time.get_ticks_msec()<deadline: await process_frame
    await scene.presentation_updated
    scene.session.close();scene.set_process(false);scene.hud.hide()
    scene.timeline.current={};scene.timeline.queue=[]
    check(scene.session.issue.is_empty() and scene.media_issue.is_empty(),"Actual recorded Crypt and exact source preparation are ready")
    if not failures.is_empty():scene.queue_free();quit(1);return
    var canonical:Dictionary=scene.timeline.state.duplicate(true)
    scene.request_view(1)
    check(scene.quarter==0 and scene.camera.current,"Requesting a cold quarter does not move the current camera")
    await drain_view(scene,1)
    check(timings.back().old_view_pose_samples>1,"Current native character clocks keep advancing during preparation")
    var source=weakref(scene.static_views[0].root)
    var mask=weakref(scene.static_views[0].mask_viewport)
    scene.request_view(0)
    scene.request_view(2)
    check(not source.get_ref().visible and mask.get_ref().render_target_update_mode==SubViewport.UPDATE_DISABLED,"Canceled view and its coverage stop rendering before disposal")
    await drain_retired(scene)
    check(source.get_ref()==null and mask.get_ref()==null,"Canceled cached target releases its root and separately parented original mask")
    check(scene.quarter==1,"Rapid replacement leaves the current quarter published")
    # Change only target selection/projection while its sources are being built.
    scene.wall_mode="hidden"
    var senses:Dictionary=scene.timeline.state.senses.duplicate(true)
    senses.visible=senses.visible.slice(0,maxi(1,senses.visible.size()-2))
    scene.timeline.state.senses=senses;scene.timeline.revision+=1;scene.timeline.world_revision+=1
    scene._sync_scenery();scene.update_wall_visibility()
    root.size=Vector2i(1000,680)
    scene.camera.size=8.75;scene.camera_focus+=Vector3(.2,0,.1);scene.position_camera()
    await drain_view(scene,2)
    check(scene.wall_mode=="hidden" and scene.wall_mask_view==[scene.camera.global_transform,scene.camera.size,root.get_visible_rect().size],"Changed visibility/mode/zoom publish with the matching prepared mask projection")
    var native=await capture()
    native.save_png("res://.captures/rotation-prepared.png")
    reference_rebuild(scene)
    var independent=await capture()
    independent.save_png("res://.captures/rotation-independent.png")
    var errors=0
    for y in range(native.get_height()):
        for x in range(native.get_width()):
            var a=native.get_pixel(x,y);var b=independent.get_pixel(x,y)
            if maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))>1.0/255+.00001:errors+=1
    check(errors==0,"Changed pending visibility and projection exactly match independent fresh original-source rendering: %d pixels"%errors)
    # An admitted source-generation change must retire incomplete prior rows.
    scene.request_view(3)
    var stale=weakref(scene.pending_view)
    var tile_key:String=scene.timeline.state.tiles.keys()[0]
    var tile:Dictionary=scene.timeline.state.tiles[tile_key].duplicate(true)
    tile.elevation_steps+=1;scene.timeline.state.tiles[tile_key]=tile
    scene.timeline.revision+=1;scene.timeline.world_revision+=1
    scene._sync_world();scene._sync_scenery();scene.update_wall_visibility()
    await drain_retired(scene)
    check(stale.get_ref()==null,"Changed source geometry releases the incomplete prior generation")
    await drain_view(scene,3)
    check(scene.sprite_parent.generation==scene.world_generation,"Publication uses only the current source generation")
    # Retire all three inactive native views after an actual changed source row.
    for q in [0,1,2]:
        scene.request_view(q); await drain_view(scene,q)
    check(scene.static_views.size()==3,"Three source-generation views exist before invalidation")
    var retired=[];var retired_nodes=0
    for view in scene.static_views.values():
        retired.append(weakref(view.root));retired_nodes+=view.entries.size()+view.mask_nodes.size()
    tile=scene.timeline.state.tiles[tile_key].duplicate(true)
    tile.elevation_steps+=1;scene.timeline.state.tiles[tile_key]=tile
    scene.timeline.revision+=1;scene.timeline.world_revision+=1
    var release_start=Time.get_ticks_usec()
    scene._sync_world();scene._sync_scenery();scene.update_wall_visibility()
    var release_cpu=(Time.get_ticks_usec()-release_start)/1000.0
    var request_started=Time.get_ticks_usec()
    scene.request_view(3)
    await drain_view(scene,3)
    var disposal = timings.back().duplicate(true)
    disposal.request_to_publication_ms=(Time.get_ticks_usec()-request_started)/1000.0
    check(scene.presentation_diagnostics().retiring_nodes==0,"A new camera request drains invalidated views and still publishes")
    var release_wall=(Time.get_ticks_usec()-release_start)/1000.0
    check(retired.all(func(ref):return ref.get_ref()==null),"All three inactive source-generation roots retire after publication invalidation")
    timings.append({"case":"three_cached_view_invalidation","retired_native_nodes":retired_nodes,"sync_cpu_ms":release_cpu,"disposal_elapsed_ms":release_wall,"disposal":disposal})
    scene.timeline.state=canonical
    check(scene.presentation_errors.is_empty(),"Prepared rotation has no missing source or rendering errors")
    var report={"checks":checks,"failures":failures,"timings":timings,"scope":"Actual Crypt sources with atomic cold publication, advancing native poses, rapid cached cancellation, and named visibility/projection/elevation renderer fixtures. Pixel comparison retains original tolerance."}
    var file=FileAccess.open("res://generated/rotation_preparation_checks.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
    print("ROTATION_PREPARATION_CHECKS ",JSON.stringify(report))
    scene.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)

func drain_retired(scene: Node) -> Dictionary:
    var deadline = Time.get_ticks_msec()+60000
    var frames = 0
    var maximum = 0.0
    while scene.presentation_diagnostics().retiring_nodes>0 and Time.get_ticks_msec()<deadline:
        var started = Time.get_ticks_usec()
        scene._dispose_views()
        await process_frame; await RenderingServer.frame_post_draw
        maximum = maxf(maximum,(Time.get_ticks_usec()-started)/1000.0)
        frames += 1
    check(scene.presentation_diagnostics().retiring_nodes==0,"Canceled native views completely drain within the wait boundary")
    return {"frames":frames,"max_native_interval_ms":maximum}
