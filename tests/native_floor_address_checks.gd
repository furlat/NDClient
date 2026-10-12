extends "res://tests/native_2d_integration_checks.gd"
# Actual recorded world, unchanged native lighting. Each displayed floor batch
# is compared with independent full-precision single-draw atlas addresses.
func snapshot()->Image:
    await process_frame;await RenderingServer.frame_post_draw
    await process_frame;await RenderingServer.frame_post_draw
    return root.get_texture().get_image()
func difference(a:Image,b:Image)->Dictionary:
    var changed:=0;var alpha:=0;var maximum:=0
    for y in a.get_height():
        for x in a.get_width():
            var av=a.get_pixel(x,y);var bv=b.get_pixel(x,y)
            var delta=maxi(absi(av.r8-bv.r8),maxi(absi(av.g8-bv.g8),absi(av.b8-bv.b8)))
            maximum=maxi(maximum,delta)
            if delta>0:changed+=1
            if av.a8!=bv.a8:alpha+=1
    return {"changed":changed,"alpha":alpha,"maximum":maximum}
func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(1280,800)
    var scene=Player.instantiate();scene.timeline.paused=true;root.add_child(scene)
    var deadline=Time.get_ticks_msec()+240000
    while (not scene.session.recording_ready or not scene._media_ready({}) or scene.visual_actors.is_empty()) and scene.session.issue.is_empty() and scene.media_issue.is_empty() and Time.get_ticks_msec()<deadline:await process_frame
    check(scene.session.recording_ready and scene.media_initial_ready,"Actual user journal initial media and scene publish")
    while (scene.timeline.busy() or scene.timeline.sequence<scene.session.latest_sequence) and Time.get_ticks_msec()<deadline:
        scene.timeline.paused=false;scene.timeline.advance(1000);scene.timeline.paused=true;await scene.presentation_updated
    check(not scene.timeline.busy() and scene.timeline.sequence==scene.session.latest_sequence,"Finite actual user journal completely displays")
    check(scene.timeline.state==scene.session.journal.state,"Actual journal state matches canonical reduction")
    scene.session.close();scene.hud.hide();scene.grid_visible=false
    var canonical=scene.timeline.state.duplicate(true)
    DirAccess.make_dir_recursive_absolute("res://.captures/floor-address")
    for quarter in 4:
        scene.set_process(true);scene.request_view(quarter)
        while scene.rotation_pending() and Time.get_ticks_msec()<deadline:await scene.presentation_updated
        for zoom in [4.73,8.137,12.0]:
            scene.set_process(true);scene.camera.size=zoom
            await scene.presentation_updated;await scene.presentation_updated
            scene.set_process(false)
            var actual=await snapshot();var entries={};var nodes=[]
            for receiver in scene.native_light_atlas.receivers:
                if receiver.index<0:continue
                var entry:Dictionary=receiver.entry
                if not entry.node.visible:continue
                entries[entry.node.get_instance_id()]=entry
                var material:ShaderMaterial=entry.received_material.duplicate();material.set_shader_parameter("use_instance_atlas",false)
                var extent:Vector2=scene.native_light_atlas.viewport.size
                var origin=Vector2(receiver.position)/extent;var size=Vector2(receiver.crop.pixels.size)/extent
                material.set_shader_parameter("atlas_region",Vector4(origin.x,origin.y,size.x,size.y))
                var node=MeshInstance3D.new();node.mesh=entry.node.multimesh.mesh;node.material_override=material
                scene.add_child(node);node.global_transform=entry.node.global_transform*entry.node.multimesh.get_instance_transform(receiver.index)
                node.sorting_use_aabb_center=false
                # Split one native batch into the same contiguous painter slot.
                # Offsets include each single node's physical depth, as in the
                # production rank mapping; otherwise tiles sort above walls.
                node.sorting_offset=float(entry.draw_rank)*8.0+float(receiver.index)/maxi(1,entry.batch_rows.size())*4.0-scene.camera.global_basis.z.dot(node.global_position)
                nodes.append(node)
            for entry in entries.values():entry.node.hide()
            var expected=await snapshot();var delta=difference(actual,expected)
            check(delta.alpha==0 and delta.maximum<=1,"Actual q%d zoom%s MultiMesh matches independent source-address singles: %s"%[quarter,zoom,delta])
            receipts.append({"quarter":quarter,"zoom":zoom,"sequence":scene.timeline.sequence,"floors":nodes.size(),"difference":delta})
            actual.save_png("res://.captures/floor-address/q%d-zoom%s-actual.png"%[quarter,zoom]);expected.save_png("res://.captures/floor-address/q%d-zoom%s-reference.png"%[quarter,zoom])
            for node in nodes:node.queue_free()
            for entry in entries.values():entry.node.show()
            await process_frame
    check(scene.timeline.state==canonical,"Pixel oracle never mutates actual player state")
    check(scene.presentation_errors.is_empty(),"Actual scene source and native receiving remain error-free")
    scene.queue_free();await process_frame;await process_frame
    var report={"checks":checks,"failures":failures,"cases":receipts,"scope":"Actual finite user journal complete canonical display; all four quarters and three fractional/wide zooms. Independent full-precision per-floor atlas addresses versus production MultiMesh integer transport."}
    FileAccess.open("res://generated/native_floor_address_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print("FLOOR_ADDRESS_CHECKS ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
