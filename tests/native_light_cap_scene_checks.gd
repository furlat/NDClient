extends "res://tests/native_surface_receiving_checks.gd"
# Cap on/off through the real disclosed room, four fixed camera views, and
# final 3D composition. Isolated source/illumination oracles run separately.
# The cap is play.gd's in-memory light_cap_enabled published as the light_cap
# global; the user's saved setting is never written.
func set_cap(scene:Node,enabled:bool)->void:
    scene.light_cap_enabled=enabled;publish_receiving(scene)

func run()->void:
    var expect_off="--expect-carried-off" in OS.get_cmdline_user_args()
    var label="carried-off" if expect_off else "all-lit"
    var capture_dir="res://.captures/light-cap/"+label
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(1280,800)
    ProjectSettings.set_setting("source_data/encounter_cache_mib",0)
    var scene=Player.instantiate();scene.timeline.paused=true;root.add_child(scene)
    var deadline=Time.get_ticks_msec()+240000
    while (not scene.session.recording_ready or not scene._media_ready({}) or scene.visual_actors.is_empty()) and scene.session.issue.is_empty() and scene.media_issue.is_empty() and Time.get_ticks_msec()<deadline:await process_frame
    check(scene.session.recording_ready and scene.media_initial_ready,"Recorded room mandatory sources publish")
    while (scene.timeline.busy() or scene.timeline.sequence<scene.session.latest_sequence) and Time.get_ticks_msec()<deadline:
        scene.timeline.paused=false;scene.timeline.advance(1000);scene.timeline.paused=true;await scene.presentation_updated
    check(not scene.timeline.busy() and scene.timeline.state==scene.session.journal.state,"Room replay finishes canonically")
    scene.session.close();scene.hud.hide();scene.grid_visible=false;scene.camera.size=8.137
    scene.wall_mode="hidden";scene.update_wall_visibility()
    var canonical=scene.timeline.state.duplicate(true)
    var receipt=lighting_receipt(scene)
    check(receipt.actors.size()==2 and receipt.actors.all(func(actor):return actor.torches.size()==1 and bool(actor.torches[0].is_lit)!=expect_off),"Recorded carried torch state matches case "+label)
    DirAccess.make_dir_recursive_absolute(capture_dir)
    for quarter in 4:
        scene.set_process(true);scene.request_view(quarter)
        while scene.rotation_pending() and Time.get_ticks_msec()<deadline:await scene.presentation_updated
        check(not scene.rotation_pending() and scene.quarter==quarter,"Requested camera quarter publishes "+str(quarter))
        await scene.presentation_updated;await scene.presentation_updated;scene.set_process(false)
        var display_clock=scene.timeline.display_ms
        var samples=scene.displayed_samples.duplicate(true)
        var original_cap:bool=scene.light_cap_enabled
        set_cap(scene,false)
        var uncapped=await snapshot()
        set_cap(scene,true)
        var capped=await snapshot()
        var delta=difference(uncapped,capped)
        check(delta.changed>0,"Native accumulated light ceiling affects overlapping room lights q"+str(quarter))
        check(delta.alpha==0,"Light cap preserves final composition alpha q"+str(quarter))
        uncapped.save_png(capture_dir+"/q%d-off.png"%quarter);capped.save_png(capture_dir+"/q%d-on.png"%quarter)
        set_cap(scene,false)
        var restored=await snapshot()
        check(difference(uncapped,restored).maximum==0,"Cap off restores the original room framebuffer exactly q"+str(quarter))
        scene.set_normals_visible(true);publish_receiving(scene)
        var normal_off=await snapshot()
        set_cap(scene,true)
        var normal_on=await snapshot()
        check(difference(normal_off,normal_on).maximum==0,"Normals diagnostic is unaffected by illumination cap q"+str(quarter))
        scene.set_normals_visible(false);set_cap(scene,original_cap)
        check(scene.timeline.display_ms==display_clock and scene.displayed_samples==samples,"Lighting toggles preserve displayed animation clocks and source samples q"+str(quarter))
        receipts.append({"quarter":quarter,"delta":delta,"lights":scene.light_table.count})
    check(scene.timeline.state==canonical,"Cap never changes authoritative gameplay state")
    check(scene.presentation_errors.is_empty() and scene.light_table.issues.is_empty(),"Native scene reports no source or lighting errors")
    var report={"lighting":receipt,"checks":checks,"failures":failures,"cases":receipts,"renderer":RenderingServer.get_current_rendering_method(),"driver":RenderingServer.get_current_rendering_driver_name(),"scope":"Actual recorded room, four camera quarters, final3D pixels. Off restores baseline, alpha and canonical state stay unchanged, and unlit Normals is invariant. Pixel differences/captures support visual inspection; independent isolated cap oracles are separate."}
    FileAccess.open("res://generated/native_light_cap_scene_"+label+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("NATIVE_LIGHT_CAP_SCENE ",JSON.stringify({"checks":checks,"failures":failures,"label":label}))
    scene.queue_free();await process_frame;await process_frame;quit(0 if failures.is_empty() else 1)
