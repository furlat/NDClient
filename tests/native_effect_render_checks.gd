extends SceneTree
const Effects=preload("res://presentation/native_effects.gd")
const Preview=preload("res://presentation/native_effect_preview.gd")
var rows:Array=[]
func _initialize()->void:call_deferred("run")
func run()->void:
    var record=Effects.source_record("class.action_surge")
    var owner=Node3D.new();root.add_child(owner)
    var preview=Preview.new();owner.add_child(preview)
    var error=preview.configure("class.action_surge")
    if not error.is_empty():push_error(error);quit(1);return
    var reference_script:Script=load("res://.runtime/native-effects/reference/ClassComponents.gd")
    var refs:Array=[]
    for half in ["back","front"]:
        var view=SubViewport.new();view.size=Vector2i(384,384);view.own_world_3d=true
        view.transparent_bg=true;view.msaa_3d=Viewport.MSAA_2X;view.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(view)
        var camera=Camera3D.new();view.add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL
        camera.keep_aspect=Camera3D.KEEP_WIDTH;camera.size=384.0/float(record.pixels_per_unit);camera.current=true
        var source:Node3D=reference_script.new();source.kind="burst";source.side_name=half;view.add_child(source)
        refs.append({"view":view,"source":source,"camera":camera,"half":half})
    DirAccess.make_dir_recursive_absolute("res://.captures/native-effects")
    for quarter in 4:
        var rotation=Basis(Vector3.UP,quarter*PI*.5)
        var camera_basis=rotation*Basis.looking_at(Vector3(-6,-sqrt(24.0),-6))
        for age in [.125,.375,.75]:
            preview.sample(age,camera_basis,Vector3.ZERO)
            for ref in refs:
                ref.camera.basis=camera_basis;ref.camera.position=Vector3(0,.9*.816496580927726,0)+camera_basis.z*12.0
                ref.source.quadrant=quarter
                for ribbon in ref.source.ribbons:
                    var a=quarter*PI*.5;ribbon.material_override.set_shader_parameter("camera_ground",Vector2(cos(a)+sin(a),cos(a)-sin(a)))
                ref.source.set_age(age);ref.view.render_target_update_mode=SubViewport.UPDATE_ONCE
            await process_frame;await RenderingServer.frame_post_draw
            for i in 2:
                var name="q%d-t%03d-%s"%[quarter,roundi(age*1000),refs[i].half]
                refs[i].view.get_texture().get_image().save_png("res://.captures/native-effects/"+name+"-original.png")
                preview.views[i].output.get_texture().get_image().save_png("res://.captures/native-effects/"+name+"-palette.png")
                rows.append({"name":name,"quarter":quarter,"seconds":age})
            # The actual source RGBA before the composition palette, independent
            # old source on the left, new one-simulation/half-plane on the right.
            for row in preview.views:
                for child in row.viewport.get_children():
                    if child is CanvasLayer:child.visible=false
                row.viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
            await process_frame;await RenderingServer.frame_post_draw
            for i in 2:
                var name=rows[rows.size()-2+i].name
                preview.views[i].viewport.get_texture().get_image().save_png("res://.captures/native-effects/"+name+"-raw.png")
            for row in preview.views:
                for child in row.viewport.get_children():
                    if child is CanvasLayer:child.visible=true
    var report={"renderer":RenderingServer.get_current_rendering_method(),"driver":RenderingServer.get_current_rendering_driver_name(),"samples":rows}
    var file=FileAccess.open("res://.runtime/native-effects/render.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
    for ref in refs:ref.view.free()
    preview.close();owner.free();quit()
