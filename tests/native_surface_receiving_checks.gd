extends "res://tests/native_floor_address_checks.gd"
# Same actual disclosed scene: receiving-normal and connected-floor correction
# versus the prior single-ray/exposed-skirt baseline, through final3D output.
func original_receiving(scene:Node,enabled:bool)->void:
    for group in scene.native_light_atlas.groups.values():
        group.material.set_shader_parameter("ground_join_mask",0 if enabled else group.get("join_mask",0))
        var record:Dictionary=group.entry.get("record",{})
        if record.get("normal",{}).has("original_path"):
            group.material.set_shader_parameter("normal_texture",group.entry.material.get_shader_parameter("geometry_texture") if enabled else group.entry.material.get_shader_parameter("normal_texture"))
func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(1280,800)
    ProjectSettings.set_setting("source_data/encounter_cache_mib",0)
    var scene=Player.instantiate();scene.timeline.paused=true;root.add_child(scene)
    var deadline=Time.get_ticks_msec()+240000
    while (not scene.session.recording_ready or not scene._media_ready({}) or scene.visual_actors.is_empty()) and scene.session.issue.is_empty() and scene.media_issue.is_empty() and Time.get_ticks_msec()<deadline:await process_frame
    check(scene.session.recording_ready and scene.media_initial_ready,"Actual user scene mandatory media publishes")
    while (scene.timeline.busy() or scene.timeline.sequence<scene.session.latest_sequence) and Time.get_ticks_msec()<deadline:
        scene.timeline.paused=false;scene.timeline.advance(1000);scene.timeline.paused=true;await scene.presentation_updated
    check(not scene.timeline.busy() and scene.timeline.state==scene.session.journal.state,"Actual71-record canonical replay completes")
    scene.session.close();scene.hud.hide();scene.grid_visible=false;scene.camera.size=8.137
    var canonical=scene.timeline.state.duplicate(true)
    DirAccess.make_dir_recursive_absolute("res://.captures/surface-receiving")
    for quarter in 4:
        scene.set_process(true);scene.request_view(quarter)
        while scene.rotation_pending() and Time.get_ticks_msec()<deadline:await scene.presentation_updated
        await scene.presentation_updated;await scene.presentation_updated;scene.set_process(false)
        original_receiving(scene,true)
        var before=await snapshot()
        original_receiving(scene,false)
        var after=await snapshot()
        var joins=0;var exposed=0;var props=0
        for receiver in scene.native_light_atlas.receivers:
            if receiver.get("join_mask",0)>0:joins+=1
            elif receiver.index>=0:exposed+=1
            if receiver.entry.get("record",{}).get("normal",{}).has("original_path"):props+=1
        var delta=difference(before,after)
        check(joins>0 and props>0,"Actual published terrain/prop receivers use both corrected inputs q"+str(quarter))
        check(delta.changed>0,"Actual final framebuffer responds to corrected receiving q"+str(quarter))
        check(delta.alpha==0,"Actual final framebuffer keeps alpha q"+str(quarter))
        before.save_png("res://.captures/surface-receiving/q%d-before.png"%quarter);after.save_png("res://.captures/surface-receiving/q%d-after.png"%quarter)
        scene.set_normals_visible(true);scene.native_light_atlas.sync(scene);scene.native_light_atlas.sync_output(scene)
        var normals=await snapshot()
        check(difference(after,normals).changed>0,"Normals view shows receiving vectors without native illumination q"+str(quarter))
        var lights=[]
        for light in scene.source_lighting.nodes.values():
            lights.append({"node":light,"energy":light.energy,"position":light.position})
            light.energy=8.0;light.position+=Vector2(331,173)
        var moved_lights=await snapshot()
        check(difference(normals,moved_lights).maximum==0,"Normals view is exactly invariant to light energy and position q"+str(quarter))
        for light in lights:light.node.energy=light.energy;light.node.position=light.position
        var shadow_visible=false
        for entry in scene.actor_entries:
            if entry.get("generated_shadow",false) and entry.node.visible:shadow_visible=true
        check(not shadow_visible,"Normals omits generated shadow overlays q"+str(quarter))
        normals.save_png("res://.captures/surface-receiving/q%d-normals.png"%quarter)
        scene.set_normals_visible(false);scene.native_light_atlas.sync(scene);scene.native_light_atlas.sync_output(scene)
        var restored=await snapshot()
        check(difference(after,restored).maximum<=1,"Disabling Normals restores original receiving frame q"+str(quarter))
        receipts.append({"quarter":quarter,"joined":joins,"unjoined":exposed,"props":props,"difference":delta})
    check(scene.timeline.state==canonical,"Receiving corrections never alter canonical gameplay")
    check(scene.presentation_errors.is_empty(),"Actual scene has no missing source or receiving errors")
    var report={"checks":checks,"failures":failures,"cases":receipts,"renderer":RenderingServer.get_current_rendering_method(),"driver":RenderingServer.get_current_rendering_driver_name(),"scope":"Final3D actual71-packet scene in four quarters. Before uses original single-ray prop normals and independently exposed floor skirts; after uses source pixel-integrated Cycles normals and published-topology interior joins. Alpha/state unchanged. Pixel differences are recorded, not a subjective-quality assertion."}
    FileAccess.open("res://generated/native_surface_receiving_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print("NATIVE_SURFACE_RECEIVING ",JSON.stringify(report));scene.queue_free();await process_frame;await process_frame;quit(0 if failures.is_empty() else 1)
