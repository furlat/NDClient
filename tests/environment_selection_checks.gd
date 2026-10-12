extends SceneTree
# Selection bounds describe original RGBA bytes, independently of lighting.
var checks := 0
var failures: Array = []
func _initialize() -> void: run.call_deferred()
func run() -> void:
    root.unfocusable = true; root.position = Vector2i(-16000,-16000); root.size = Vector2i(256,64)
    root.msaa_3d = Viewport.MSAA_DISABLED
    var camera := Camera3D.new(); camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.size = 1; camera.position.z = 10; root.add_child(camera)
    var node := MeshInstance3D.new(); var quad := QuadMesh.new(); quad.size = Vector2(4,1); node.mesh = quad
    var material := ShaderMaterial.new(); material.shader = load("res://environment.gdshader")
    node.material_override = material; root.add_child(node)
    var source := Image.create(4,1,false,Image.FORMAT_RGBA8)
    var bytes := [0,1,2,20]
    for x in range(4): source.set_pixel(x,0,Color8(bytes[x],bytes[x],bytes[x],128))
    material.set_shader_parameter("colour_texture",ImageTexture.create_from_image(source))
    material.set_shader_parameter("colour_size",Vector2(4,1)); material.set_shader_parameter("colour_rect",Vector4(0,0,4,1))
    material.set_shader_parameter("has_geometry",false); material.set_shader_parameter("highlighted",true)
    material.set_shader_parameter("use_selection",true); material.set_shader_parameter("selection_kind",1)
    material.set_shader_parameter("rgba_min",Vector4(0,0,0,1)); material.set_shader_parameter("rgba_max",Vector4(1,1,1,249))
    await inspect(material,"environment")
    material = ShaderMaterial.new(); material.shader = load("res://grid.gdshader"); node.material_override = material
    camera.size = 1.0/90.5096679919
    var colours := Texture2DArray.new(); colours.create_from_images([source])
    material.set_shader_parameter("colours",colours); material.set_shader_parameter("highlighted",true)
    var fields := Image.create(22,1,false,Image.FORMAT_RGBAF)
    fields.set_pixel(0,0,Color(4,1,2,.5)); fields.set_pixel(1,0,Color(1,0,-1,-1))
    fields.set_pixel(5,0,Color(0,0,0,1)); fields.set_pixel(17,0,Color(0,0,0,1))
    fields.set_pixel(18,0,Color(1,1,1,249)); fields.set_pixel(20,0,Color(1,0,0,1))
    material.set_shader_parameter("metadata",ImageTexture.create_from_image(fields))
    material.set_shader_parameter("placement_state",ImageTexture.create_from_image(Image.create(1,1,false,Image.FORMAT_RGBAF)))
    await inspect(material,"grid")
    var report := {"checks":checks,"failures":failures,"renderer":RenderingServer.get_current_rendering_method()}
    var file := FileAccess.open("res://generated/environment_selection_checks.json",FileAccess.WRITE)
    file.store_string(JSON.stringify(report,"  ")); file.close()
    print("ENVIRONMENT_SELECTION_CHECKS ",JSON.stringify(report)); quit(0 if failures.is_empty() else 1)

func inspect(material: ShaderMaterial, shader_name: String) -> void:
    var bytes := [0,1,2,20]
    for body in [false,true]:
        if shader_name=="environment": material.set_shader_parameter("invert_selection",body)
        else:
            var item := Image.create(1,1,false,Image.FORMAT_RGBAF); item.fill(Color(0,0,1 if body else 0,1))
            material.set_shader_parameter("instances",ImageTexture.create_from_image(item))
        await process_frame; await process_frame; await RenderingServer.frame_post_draw
        var actual := root.get_texture().get_image()
        for x in range(4):
            var visible := actual.get_pixel(x*64+32,32).g > .2
            var selected: bool = bytes[x]<=1
            checks += 1
            if visible != (selected != body): failures.append({"shader":shader_name,"byte":bytes[x],"body":body,"visible":visible})
