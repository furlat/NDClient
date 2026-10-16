extends "res://tests/native_2d_integration_checks.gd"
# Same recorded scene and camera, three source-preserving illumination captures.
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
    for group in scene.native_light_atlas.groups.values():group.material.set_shader_parameter("use_source_normals",false)
    await snap(scene,"lit-flat")
    for group in scene.native_light_atlas.groups.values():group.material.set_shader_parameter("use_source_normals",true)
    for child in scene.native_light_atlas.viewport.get_children():
        if child is CanvasModulate:child.color=Color.WHITE
        if child is Light2D:child.enabled=false
    await snap(scene,"unlit-original")
    var rows=[]
    var props=[]
    for receiver in scene.native_light_atlas.receivers:
        if not receiver.entry.node.visible:continue
        if receiver.index<0:
            if receiver.entry.has("record"):
                var p:Transform2D=scene.native_light_atlas.receiver_global_transform(receiver)
                props.append({"id":receiver.id,"record":receiver.entry.record,"placement":receiver.entry.get("placement",{}),"role":receiver.entry.get("source_role",-1),"rank":receiver.entry.get("draw_rank",0),"crop":[receiver.crop.pixels.position.x,receiver.crop.pixels.position.y,receiver.crop.pixels.size.x,receiver.crop.pixels.size.y],"screen_transform":[p.x.x,p.x.y,p.y.x,p.y.y,p.origin.x,p.origin.y],"atlas":[receiver.position.x,receiver.position.y]})
            continue
        var t:Transform2D=scene.native_light_atlas.receiver_global_transform(receiver)
        rows.append({"id":receiver.id,"source":receiver.entry.record.path,"crop":[receiver.crop.pixels.position.x,receiver.crop.pixels.position.y,receiver.crop.pixels.size.x,receiver.crop.pixels.size.y],"screen_transform":[t.x.x,t.x.y,t.y.x,t.y.y,t.origin.x,t.origin.y],"index":receiver.index,"rank":receiver.entry.draw_rank,"atlas":[receiver.position.x,receiver.position.y]})
    var report={"checks":checks,"failures":failures,"sequence":scene.timeline.sequence,"renderer":RenderingServer.get_current_rendering_method(),"driver":RenderingServer.get_current_rendering_driver_name(),"floor_sources":rows,"prop_sources":props}
    DirAccess.make_dir_recursive_absolute("res://.runtime/graphics-quality")
    var diagnostic=".runtime/graphics-quality/native_floor_lighting_checks.json"
    FileAccess.open("res://"+diagnostic,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    var summary=report.duplicate()
    summary.erase("floor_sources");summary.erase("prop_sources")
    summary.floor_source_count=rows.size();summary.prop_source_count=props.size();summary.full_diagnostic=diagnostic
    FileAccess.open("res://generated/native_floor_lighting_checks.json",FileAccess.WRITE).store_string(JSON.stringify(summary,"  "))
    print("FLOOR_LIGHTING_CAPTURE ",JSON.stringify({"checks":checks,"failures":failures,"floors":rows.size()}));scene.queue_free();await process_frame;await process_frame;quit(0 if failures.is_empty() else 1)
