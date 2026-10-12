extends SceneTree
# Bounded normalized-nearest vs integer-texel channel alignment regression.
const Geometry = preload("res://presentation/character_geometry.gd")
const Catalog = preload("res://source_catalog.gd")
const Placement = preload("res://placement.gd")
var cache = {}; var textures = {}; var checks = 0; var failures = []
func texture(path: String) -> Texture2D:
    if not textures.has(path): textures[path] = ImageTexture.create_from_image(Image.load_from_file(Catalog.media_path(path)))
    return textures[path]
func capture(viewport: SubViewport) -> Image:
    await process_frame; await process_frame; await RenderingServer.frame_post_draw
    return viewport.get_texture().get_image()
func _initialize() -> void: run.call_deferred()
func run() -> void:
    root.unfocusable = true; root.position = Vector2i(-16000,-16000)
    var viewport = SubViewport.new(); viewport.size = Vector2i(192,192); viewport.own_world_3d = true
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS; root.add_child(viewport)
    var world = WorldEnvironment.new(); world.environment = Environment.new()
    world.environment.background_mode = Environment.BG_COLOR; world.environment.background_color = Color.BLACK
    world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED; viewport.add_child(world)
    var camera = Camera3D.new(); camera.projection = Camera3D.PROJECTION_ORTHOGONAL; camera.position = Vector3(.0037,.0019,10); viewport.add_child(camera)
    var node = MeshInstance3D.new(); node.mesh = QuadMesh.new(); node.mesh.size = Vector2(128,128)/Placement.PIXELS_PER_UNIT; viewport.add_child(node)
    var explicit = Shader.new(); var code = FileAccess.get_file_as_string("res://modular.gdshader")
    for channel in ["sheet","component_depth","component_normal","component_support","component_normal_valid"]:
        code = code.replace("texture("+channel+", source_uv)","texelFetch("+channel+", clamp(ivec2(floor(source_uv*vec2(textureSize("+channel+",0)))),ivec2(0),textureSize("+channel+",0)-ivec2(1)),0)")
    explicit.code = code
    var light = OmniLight3D.new();light.position=Vector3(.25,2.5,.75);light.omni_range=8;light.light_energy=1;viewport.add_child(light)
    var results = []
    for category in ["Chest14","Head15"]:
        var path = "/media/smallscale/modular/"+category+"/Idle.png"
        var source = ShaderMaterial.new(); source.shader = load("res://modular.gdshader")
        source.set_shader_parameter("sheet",texture(path)); source.set_shader_parameter("authored_base_light",0.0)
        var entry = {"node":node,"material":source,"actor_layer":{"slot":"chest" if category=="Chest14" else "helmet"},"placement":{"scale_x":1},"scale":1.0}
        Geometry.bind(entry,path,cache,texture)
        var reference = source.duplicate(); reference.shader = explicit
        for frame in [0,13,14]:
            for row in [0,7]:
                for zoom in [.93,1.0,1.07]:
                    camera.size = 128.0/Placement.PIXELS_PER_UNIT*zoom
                    var uv = Vector4(frame/15.0,row/8.0,1.0/15,1.0/8)
                    source.set_shader_parameter("frame_uv",uv); reference.set_shader_parameter("frame_uv",uv)
                    node.material_override = source; var actual = await capture(viewport)
                    node.material_override = reference; var expected = await capture(viewport)
                    var changes = 0; var maximum = 0.0
                    for y in range(192):
                        for x in range(192):
                            var a = actual.get_pixel(x,y); var b = expected.get_pixel(x,y)
                            var error = maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))
                            maximum = maxf(maximum,error)
                            if error>0: changes += 1
                    checks += 1
                    if changes>0: failures.append([category,frame,row,zoom,changes,maximum])
                    results.append({"category":category,"frame":frame,"row":row,"zoom":zoom,"changed_pixels":changes,"max_error":maximum})
    var report = {"checks":checks,"failures":failures,"cases":results,"scope":"Native non-MSAA original+all companion nearest sampling compared to explicit same integer texel fetch; actual Chest14/Head15 frames0,13,14 and facingrows0,7 at3fractional zooms. No interpolation or artwork modifications."}
    var file = FileAccess.open("res://generated/character_geometry_sampling_checks.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
    print("CHARACTER_GEOMETRY_SAMPLING_CHECKS ",JSON.stringify({"checks":checks,"failures":failures}))
    viewport.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
