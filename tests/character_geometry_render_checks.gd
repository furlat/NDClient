extends SceneTree
# Real outfit compositions + independently decoded constant-surface native
# light oracles. Test-only swaps are presentation fixtures, not game commands.
const Geometry = preload("res://presentation/character_geometry.gd")
const Catalog = preload("res://source_catalog.gd")
const Placement = preload("res://placement.gd")
const MODULAR_SHADER = preload("res://modular.gdshader")
const Oracle = preload("res://tests/character_geometry_oracle.gdshader")
var checks = 0
var failures: Array = []
var cache = {}
var textures = {}
var viewport: SubViewport
var camera: Camera3D
var sun: DirectionalLight3D
var omni: OmniLight3D
var comparisons = []
func check(ok: bool,label: String) -> void:
    checks += 1
    if not ok: failures.append(label); print("GEOMETRY_RENDER_FAIL ",label)
func texture(path: String) -> Texture2D:
    if not textures.has(path): textures[path] = ImageTexture.create_from_image(Image.load_from_file(Catalog.media_path(path)))
    return textures[path]
func capture() -> Image:
    await process_frame; await process_frame; await RenderingServer.frame_post_draw
    return viewport.get_texture().get_image()
func entry(layer: Dictionary,path: String,priority: int) -> Dictionary:
    var node = MeshInstance3D.new(); var mesh = QuadMesh.new()
    mesh.size = Vector2(128,128)/Placement.PIXELS_PER_UNIT; node.mesh = mesh
    var material = ShaderMaterial.new(); material.shader = MODULAR_SHADER; material.render_priority = priority
    material.set_shader_parameter("sheet",texture(path))
    material.set_shader_parameter("tint",Vector3((int(layer.tint)>>16)&255,(int(layer.tint)>>8)&255,int(layer.tint)&255)/255.0)
    material.set_shader_parameter("layer_alpha",layer.alpha)
    material.set_shader_parameter("shadow",layer.slot=="shadow")
    node.material_override = material; viewport.add_child(node)
    var result = {"node":node,"material":material,"actor_layer":layer,"placement":{"scale_x":1.0},"scale":1.0}
    Geometry.bind(result,path,cache,texture)
    return result
func image_difference(a: Image,b: Image) -> Dictionary:
    var changes = 0; var maximum = 0.0
    for y in range(a.get_height()):
        for x in range(a.get_width()):
            var av = a.get_pixel(x,y); var bv = b.get_pixel(x,y)
            var difference = maxf(absf(av.r-bv.r),maxf(absf(av.g-bv.g),absf(av.b-bv.b)))
            if difference>1.0/255.0: changes += 1
            maximum = maxf(maximum,difference)
    return {"changed_pixels":changes,"maximum":maximum}
func _initialize() -> void: run.call_deferred()
func run() -> void:
    root.unfocusable = true; root.position = Vector2i(-16000,-16000)
    viewport = SubViewport.new(); viewport.size = Vector2i(128,128); viewport.own_world_3d = true
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS; root.add_child(viewport)
    var environment = WorldEnvironment.new(); environment.environment = Environment.new()
    environment.environment.background_mode = Environment.BG_COLOR; environment.environment.background_color = Color.BLACK
    environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED; viewport.add_child(environment)
    camera = Camera3D.new(); camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.size = 128.0/Placement.PIXELS_PER_UNIT; camera.position = Vector3(0,0,10); camera.current = true; viewport.add_child(camera)
    sun = DirectionalLight3D.new(); sun.light_energy = 0.7; sun.visible = false; viewport.add_child(sun)
    omni = OmniLight3D.new(); omni.omni_range = 10; omni.light_energy = 1.0; omni.position = Vector3(.5,.8,3); omni.visible = false; viewport.add_child(omni)
    var cases: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://generated/character_geometry_cases.json"))
    var rows = cases.outfits.duplicate(true)
    var swaps: Dictionary = cases.outfits[0].duplicate(true); swaps.name = "Independent armor/shield swap"
    for layer in swaps.layers:
        if layer.slot in ["chest","offhand"]:
            layer.category = "Chest3" if layer.slot=="chest" else "Shield5"
            for clip in ["Idle","Run","Attack1"]: layer.paths[clip] = "/media/smallscale/modular/"+layer.category+"/"+clip+".png"
    rows.append(swaps)
    var removed: Dictionary = cases.outfits[0].duplicate(true); removed.name = "Equipment removed"
    removed.layers = removed.layers.filter(func(layer):return not layer.get("equipment",false))
    rows.append(removed)
    DirAccess.make_dir_recursive_absolute("res://.captures/character-geometry")
    for outfit in rows:
        for clip in ["Idle","Run","Attack1"]:
            var layers = []
            for layer in outfit.layers:
                if layer.paths.has(clip): layers.append(entry(layer,layer.paths[clip],layers.size()))
            for facing in range(8):
                var frame = [0,6,10][facing%3]
                var uv = Vector4(frame/15.0,facing/8.0,1.0/15,1.0/8)
                for layer in layers: layer.material.set_shader_parameter("frame_uv",uv)
                sun.visible = false
                var geometry_on = await capture()
                for layer in layers: layer.material.set_shader_parameter("has_component_geometry",false)
                var original = await capture()
                var diff = image_difference(geometry_on,original)
                check(diff.changed_pixels==0,"Original colour/tint/alpha/order retained: "+outfit.name+"/"+clip+"/"+str(facing))
                sun.visible = true; sun.rotation = Vector3(-.35,.65,0)
                var flat = await capture()
                for layer in layers: layer.material.set_shader_parameter("has_component_geometry",not layer.get("geometry_paths",{}).is_empty())
                var lit = await capture()
                var response = image_difference(lit,flat)
                check(response.changed_pixels>0,"Actual equipped surface receives normal lighting: "+outfit.name+"/"+clip+"/"+str(facing))
                comparisons.append({"outfit":outfit.name,"clip":clip,"facing":facing,"source_changes":diff.changed_pixels,"lit_changes":response.changed_pixels})
                if clip=="Idle" and facing==3: lit.save_png("res://.captures/character-geometry/"+outfit.name.validate_filename()+".png")
            for layer in layers: layer.node.queue_free()
            await process_frame; textures.clear()
    sun.visible = false
    var samples: Array = JSON.parse_string(FileAccess.get_file_as_string("res://generated/character_geometry_samples.json"))
    var candidates = samples.filter(func(sample):return sample.path=="/media/smallscale/modular/Chest7/Idle.png" and sample.get("supported",true))
    check(candidates.size()==24,"Float-validated native samples cover eight facings and three frames")
    var source_path = "/media/smallscale/modular/Chest7/Idle.png"
    var layer = {"slot":"chest","category":"Chest7","tint":0xAA88DD,"alpha":1.0}
    var actual = entry(layer,source_path,0)
    var reference = ShaderMaterial.new(); reference.shader = Oracle
    reference.set_shader_parameter("sheet",texture(source_path)); reference.set_shader_parameter("tint",Vector3(170,136,221)/255.0)
    actual.material.set_shader_parameter("authored_base_light",0.0)
    # Independent producer equations: geometry.py render_view uses integer
    # native ray coordinates right=x-64, up=96-y, with elevation45 degrees.
    # Z-up producer coordinates become Y-up Godot coordinates before camera yaw.
    for case_index in range(32):
        var i = case_index%8
        var quarter = case_index/8
        var yaw_basis = Basis(Vector3.UP,quarter*PI*.5)
        camera.basis = yaw_basis; camera.position = yaw_basis*Vector3(0,0,10)
        var sample: Dictionary = candidates[i]
        var uv = Vector4(sample.pixel[0]/1920.0,sample.pixel[1]/1024.0,1.0/1920,1.0/1024)
        actual.material.set_shader_parameter("frame_uv",uv); reference.set_shader_parameter("frame_uv",uv)
        for scale_x in [1.0,1.75,-1.0]:
            actual.placement.scale_x = scale_x
            actual.node.basis = yaw_basis.scaled_local(Vector3(scale_x,1,1))
            Geometry.bind(actual,source_path,cache,texture)
            var n = Vector3(sample.normal[0]/scale_x,sample.normal[1],sample.normal[2]).normalized()
            var c = sqrt(.5)
            reference.set_shader_parameter("expected_normal",yaw_basis*Vector3(n.x,c*(n.y+n.z),c*(n.z-n.y)))
            var right = (int(sample.pixel[0])%128)-64
            var up = 96-(int(sample.pixel[1])%128)
            var producer_point = Vector3(right*scale_x,c*(up+sample.depth),c*(sample.depth-up))/Placement.PIXELS_PER_UNIT
            reference.set_shader_parameter("expected_point",yaw_basis*producer_point)
            for light in [sun,omni]:
                light.visible = true
                actual.node.material_override = actual.material; var measured = await capture()
                actual.node.material_override = reference; var expected = await capture()
                var diff = image_difference(measured,expected)
                check(diff.maximum<=2.0/255.0,"Native "+light.get_class()+" matches decoded receiver / facing "+str(i)+" scale_x "+str(scale_x)+" quarter "+str(quarter)+" error "+str(diff.maximum))
                light.visible = false
    actual.node.queue_free(); await process_frame
    camera.basis = Basis.IDENTITY; camera.position = Vector3(0,0,10)
    var unsupported = samples.filter(func(sample):return not sample.get("supported",true))
    check(not unsupported.is_empty(),"Actual source corpus includes unsupported original colour pixels")
    sun.visible = true
    for sample in unsupported.slice(0,8):
        var fixture = entry({"slot":cases.sources[sample.path],"category":"source-fixture","tint":0xCCAA99,"alpha":1.0},sample.path,0)
        fixture.material.set_shader_parameter("frame_uv",Vector4(sample.pixel[0]/1920.0,sample.pixel[1]/1024.0,1.0/1920,1.0/1024))
        var retained = await capture()
        fixture.material.set_shader_parameter("has_component_geometry",false)
        var original = await capture()
        var diff = image_difference(retained,original)
        check(diff.changed_pixels==0 and retained.get_pixel(64,64).get_luminance()>0,"Unsupported original pixel keeps colour/tint/alpha and flat normal: "+sample.path)
        fixture.node.queue_free(); await process_frame; textures.clear()
    var report = {"checks":checks,"failures":failures,"compositions":comparisons,
        "scope":"Actual captured fighter/sorcerer, original per-component swaps/removal, all facings; numeric normal/depth native directional and omni-light oracle, including mirror and nonuniform scale. Optical units remain provisional."}
    var file = FileAccess.open("res://generated/character_geometry_render_checks.json",FileAccess.WRITE); file.store_string(JSON.stringify(report,"  ")); file.close()
    print("CHARACTER_GEOMETRY_RENDER_CHECKS ",JSON.stringify({"checks":checks,"failures":failures,"compositions":comparisons.size()}))
    viewport.queue_free(); await process_frame; quit(0 if failures.is_empty() else 1)
