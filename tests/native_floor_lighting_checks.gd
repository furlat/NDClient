extends "res://tests/native_2d_integration_checks.gd"
# Same recorded scene and camera, three source-preserving illumination captures
# through the lit sprite shaders: received normals, flat normals, and unlit.
func snap(scene:Node,label:String)->void:
    await process_frame;await RenderingServer.frame_post_draw
    await process_frame;await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://.captures/floor-lighting/"+label+".png")
func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(1280,800)
    ProjectSettings.set_setting("source_data/encounter_cache_mib",0)
    var scene=Player.instantiate();scene.timeline.paused=true;root.add_child(scene)
    var deadline=Time.get_ticks_msec()+240000
    while (not scene.session.recording_ready or not scene._media_ready({}) or scene.visual_actors.is_empty()) and scene.session.issue.is_empty() and scene.media_issue.is_empty() and Time.get_ticks_msec()<deadline:await process_frame
    check(scene.session.recording_ready and scene.media_initial_ready,"Original room media initialized")
    while (scene.timeline.busy() or scene.timeline.sequence<scene.session.latest_sequence) and Time.get_ticks_msec()<deadline:
        scene.timeline.paused=false;scene.timeline.advance(1000);scene.timeline.paused=true;await scene.presentation_updated
    check(not scene.timeline.busy() and scene.timeline.state==scene.session.journal.state,"Complete actual journal canonical state")
    scene.session.close();scene.hud.hide();scene.grid_visible=false;scene.camera.size=8.137
    scene.request_view(0)
    while scene.rotation_pending() and Time.get_ticks_msec()<deadline:await scene.presentation_updated
    await scene.presentation_updated;await scene.presentation_updated;scene.set_process(false)
    DirAccess.make_dir_recursive_absolute("res://.captures/floor-lighting")
    await snap(scene,"lit-normals")
    # Lit sprites receive in their own environment shader; flat normals and the
    # unlit view are written on the same materials and receiving globals.
    var receivers:Array=scene.entries.filter(func(entry):return entry.material is ShaderMaterial and entry.material.shader==scene.ENVIRONMENT_SHADER)
    for entry in receivers:entry.material.set_shader_parameter("use_source_normals",false)
    await snap(scene,"lit-flat")
    for entry in receivers:entry.material.set_shader_parameter("use_source_normals",true)
    RenderingServer.global_shader_parameter_set(&"light_ambient",1.0)
    RenderingServer.global_shader_parameter_set(&"light_count",0)
    await snap(scene,"unlit-original")
    scene.claim_receiving();scene._publish_receiving()
    var rows=[]
    var props=[]
    for entry in receivers:
        if not entry.node.visible:continue
        if entry.has("batch_rows"):
            for index in entry.batch_rows.size():
                var row:Dictionary=entry.batch_rows[index]
                var at:Vector3=(entry.node.global_transform*entry.node.multimesh.get_instance_transform(index)).origin
                var screen:Vector2=scene.camera.unproject_position(at)
                rows.append({"id":str(row.id),"source":entry.record.path,"index":index,"rank":entry.draw_rank,"screen_origin":[screen.x,screen.y]})
        elif entry.has("record"):
            var screen:Vector2=scene.camera.unproject_position(entry.node.global_position)
            props.append({"id":entry.get("id",""),"record":entry.record,"placement":entry.get("placement",{}),"role":entry.get("source_role",-1),"rank":entry.get("draw_rank",0),"screen_origin":[screen.x,screen.y]})
    var report={"checks":checks,"failures":failures,"sequence":scene.timeline.sequence,"renderer":RenderingServer.get_current_rendering_method(),"driver":RenderingServer.get_current_rendering_driver_name(),"floor_sources":rows,"prop_sources":props}
    DirAccess.make_dir_recursive_absolute("res://.runtime/graphics-quality")
    var diagnostic=".runtime/graphics-quality/native_floor_lighting_checks.json"
    FileAccess.open("res://"+diagnostic,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    var summary=report.duplicate()
    summary.erase("floor_sources");summary.erase("prop_sources")
    summary.floor_source_count=rows.size();summary.prop_source_count=props.size();summary.full_diagnostic=diagnostic
    FileAccess.open("res://generated/native_floor_lighting_checks.json",FileAccess.WRITE).store_string(JSON.stringify(summary,"  "))
    print("FLOOR_LIGHTING_CAPTURE ",JSON.stringify({"checks":checks,"failures":failures,"floors":rows.size()}));scene.queue_free();await process_frame;await process_frame;quit(0 if failures.is_empty() else 1)
