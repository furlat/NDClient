extends SceneTree
# Native GPU checks. The radius plane is synthetic; the wall is the original
# authoring owner with its original packed depth/oct-normal companions.
const Lighting = preload("res://presentation/lighting.gd")
const Placement = preload("res://placement.gd")
class Probe extends "res://main.gd":
    func _ready() -> void:
        set_process(false); set_process_unhandled_input(false)
        camera = Camera3D.new(); camera.projection = Camera3D.PROJECTION_ORTHOGONAL
        camera.size = 5; add_child(camera); camera.current = true; position_camera()
    func _process(_delta: float) -> void: pass

var checks := 0
var failures: Array = []
var evidence: Dictionary = {}
var lighting := Lighting.new()
var camera: Camera3D
var plane: MeshInstance3D

func check(condition: bool, message: String) -> void:
    checks += 1
    if not condition: failures.append(message); print("LIGHTING_RENDER_FAIL ",message)

func capture() -> Image:
    for i in range(3): await process_frame
    await RenderingServer.frame_post_draw
    return root.get_texture().get_image()

func pixel(image: Image, position: Vector3) -> float:
    var point := camera.unproject_position(position)
    var colour := image.get_pixel(int(point.x),int(point.y))
    return (colour.r+colour.g+colour.b)/3.0

func mean(image: Image) -> float:
    var value := 0.0
    var count := 0
    for y in range(0,image.get_height(),3):
        for x in range(0,image.get_width(),3):
            var colour := image.get_pixel(x,y)
            value += (colour.r+colour.g+colour.b)/3.0; count += 1
    return value/count

func difference(first: Image, second: Image) -> float:
    var value := 0.0
    var count := 0
    for y in range(0,first.get_height(),3):
        for x in range(0,first.get_width(),3):
            var a := first.get_pixel(x,y); var b := second.get_pixel(x,y)
            value += absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b); count += 3
    return value/count

func sources(position: Array = [0,0]) -> Dictionary:
    return {"objects":{"torch":{"item":{"item_uuid":"torch","is_lit":true,
        "very_bright_radius_feet":5,"bright_radius_feet":10,"dim_radius_feet":10},
        "placement":{"position":position,"base_height_steps":0}}},"senses":{"objects":{"torch":{"visual":true}}}}

func _initialize() -> void: run.call_deferred()

func run() -> void:
    var start := Time.get_ticks_msec()
    if "--background-check" in OS.get_cmdline_user_args():
        root.unfocusable = true; root.position = Vector2i(-16000,-16000)
    if DisplayServer.get_name() == "headless":
        print("LIGHTING_RENDER_CHECKS requires native graphics"); quit(2); return
    var environment := WorldEnvironment.new()
    environment.environment = Environment.new()
    environment.environment.background_mode = Environment.BG_COLOR
    environment.environment.background_color = Color.BLACK
    environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
    root.add_child(environment)
    var stage := Node3D.new(); root.add_child(stage); lighting.attach(stage)
    camera = Camera3D.new(); camera.projection = Camera3D.PROJECTION_ORTHOGONAL; camera.size = 12
    stage.add_child(camera); camera.position = Vector3(0,20,0); camera.look_at(Vector3.ZERO,Vector3.FORWARD); camera.current = true
    plane = MeshInstance3D.new(); var mesh := PlaneMesh.new(); mesh.size = Vector2(14,14); plane.mesh = mesh
    var material := ShaderMaterial.new(); material.shader = load("res://modular.gdshader")
    var white := Image.create(1,1,false,Image.FORMAT_RGBA8); white.fill(Color.WHITE)
    material.set_shader_parameter("sheet",ImageTexture.create_from_image(white))
    material.set_shader_parameter("frame_uv",Vector4(0,0,1,1))
    plane.material_override = material; stage.add_child(plane); lighting.apply(material)
    var dark := await capture()
    check(mean(dark) < 0.001,"No sources and no directional light produce black, without ambient wash")
    # Nonwhite source and tint catch double colour conversion/multiplication.
    material.set_shader_parameter("authored_base_light",1.0)
    for tint in [Color.WHITE,Color8(88,148,196)]:
        var sample_colour = Color8(160,112,72)
        white.fill(sample_colour)
        material.set_shader_parameter("sheet",ImageTexture.create_from_image(white))
        material.set_shader_parameter("tint",Vector3(tint.r,tint.g,tint.b))
        var expected = sample_colour*tint
        var coloured = await capture()
        var point = camera.unproject_position(Vector3.ZERO)
        var actual = coloured.get_pixel(int(point.x),int(point.y))
        check(maxf(absf(actual.r-expected.r),maxf(absf(actual.g-expected.g),absf(actual.b-expected.b)))<.012,
            "Actor source tint is multiplied once at unit illumination: actual %s expected %s" % [actual,expected])
    material.set_shader_parameter("tint",Vector3.ONE)
    material.set_shader_parameter("authored_base_light",0.0)
    white.fill(Color.WHITE); material.set_shader_parameter("sheet",ImageTexture.create_from_image(white))
    lighting.sync(sources())
    var lit := await capture()
    check(pixel(lit,Vector3.ZERO) > 0.1,"Disclosed source illuminates a receiving surface")
    print("RADIUS_PIXELS ",pixel(lit,Vector3(3.5,0,0))," ",pixel(lit,Vector3(4.1,0,0))," ",pixel(lit,Vector3(2.5,0,2.5))," ",pixel(lit,Vector3(3,0,3)))
    check(pixel(lit,Vector3(3.5,0,0)) > 0.001 and pixel(lit,Vector3(4.1,0,0)) < 0.001,"Outer radius is bright plus dim, with no light beyond it")
    check(pixel(lit,Vector3(2.5,0,2.5)) > 0.001 and pixel(lit,Vector3(3,0,3)) < 0.001,"Source footprint is circular, not a square")
    check(absf(pixel(lit,Vector3(1.99,0,0))-pixel(lit,Vector3(2.01,0,0))) < .02,"Native attenuation remains continuous at the former custom bright-band threshold")
    check(absf(pixel(lit,Vector3(.99,0,0))-pixel(lit,Vector3(1.01,0,0))) < .02,"Native attenuation remains continuous at the former custom very-bright threshold")
    var previous = pixel(lit,Vector3.ZERO)
    for i in range(1,41):
        var value = pixel(lit,Vector3(float(i)/10.0,0,0))
        check(value<=previous+.004,"Radial brightness falls smoothly toward outer range")
        previous = value
    lighting.sample({}, {"torch":.85})
    var flicker_low = await capture()
    lighting.sample({}, {"torch":1.15})
    var flicker_high = await capture()
    check(pixel(flicker_high,Vector3(1.5,0,0))>pixel(flicker_low,Vector3(1.5,0,0))+.02,"Animated source energy changes unsaturated actual receiver pixels")
    check(pixel(flicker_high,Vector3(4.1,0,0))<.001,"Flicker cannot enlarge disclosed light range")
    lighting.sample({})
    var collapsed = sources()
    collapsed.objects.torch.item.dim_radius_feet = 0
    collapsed.objects.torch.item.very_bright_radius_feet = 10
    lighting.sync(collapsed)
    var collapsed_image = await capture()
    check(pixel(collapsed_image,Vector3(1.99,0,0))<.01 and pixel(collapsed_image,Vector3(2.1,0,0))<.001,
        "The reduced native optical range tapers to zero independently of coincident backend bands")
    lighting.sync(sources())
    plane.position.y = -6
    var lowered := await capture()
    check(pixel(lowered,Vector3(0,-6,0)) < 0.001,"Native spherical optical range excludes a surface farther away vertically; backend horizontal visibility is unchanged")
    plane.position.y = 0
    var below := sources(); below.objects.torch.placement.base_height_steps = -2
    lighting.sync(below)
    var reversed := await capture()
    check(mean(reversed) < 0.001,"Upward receiver normals reject a source below the surface")
    # All 24 sources overlap the central receiver; unrelated distant sources
    # cannot prove the configured per-object native light cap.
    plane.visible=false
    var multi=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D;multi.mesh=mesh;multi.instance_count=3
    for i in range(3):multi.set_instance_transform(i,Transform3D(Basis.IDENTITY,Vector3((i-1)*18,0,0)))
    var batch=MultiMeshInstance3D.new();batch.multimesh=multi;batch.material_override=material;stage.add_child(batch)
    var many={"objects":{},"senses":{"objects":{}}}
    for i in range(24):
        var id="relevant%02d"%i
        many.objects[id]={"item":{"item_uuid":id,"is_lit":true,"very_bright_radius_feet":5,"bright_radius_feet":10,"dim_radius_feet":10},"placement":{"position":[0,0],"base_height_steps":0}}
        many.senses.objects[id]={"visual":true}
    lighting.sync(many)
    for node in lighting.nodes.values():node.light_energy=.01
    var all_relevant=await capture()
    var ids=lighting.nodes.keys()
    for i in range(8,ids.size()):lighting.nodes[ids[i]].visible=false
    var eight_relevant=await capture()
    var all_value=pixel(all_relevant,Vector3.ZERO);var eight_value=pixel(eight_relevant,Vector3.ZERO)
    check(lighting.nodes.size()==24 and all_value>eight_value*1.3,"Twenty-four actually relevant native lights contribute beyond eight on one large MultiMesh:24=%f 8=%f"%[all_value,eight_value])
    evidence.relevant_24=all_value;evidence.relevant_8=eight_value
    batch.queue_free();plane.visible=true
    lighting.sync({})
    var directions := Lighting.directionals({"directionalSources":[{"id":"test","directionToSource":[0,1,0],"colorLinear":[1,1,1],"intensity":0.5}]})
    stage.add_child(directions.nodes[0])
    var directional := await capture()
    check(pixel(directional,Vector3.ZERO) > 0.1,"Native directional illumination remains supported")
    lighting.sync({});stage.queue_free(); await process_frame

    var world := Probe.new(); root.add_child(world);lighting.attach(world)
    var row := {"id":"wall","kind":"wall","material":"stone","position":[0,0],"base_height_steps":0,"orientation":"east","boundaries":["east"],"layer":1}
    world.add_environment_entries(row)
    for entry in world.entries:
        world.initialize_entry(entry); entry.node.visible = entry.source_role == 1
        lighting.apply(entry.material)
    var source := sources([1,1]); source.objects.torch.item.bright_radius_feet = 20
    lighting.sync(source)
    var authored := await capture()
    check(mean(authored) > 0.002,"Original stone wall receives source illumination")
    for entry in world.entries: entry.material.set_shader_parameter("use_source_normals",false)
    var flat_normal := await capture()
    var normal_delta := difference(authored,flat_normal)
    check(normal_delta > 0.0001,"Original packed normals materially change the actual wall pixels")
    for entry in world.entries:
        entry.material.set_shader_parameter("use_source_normals",true)
        entry.material.set_shader_parameter("use_source_depth",false)
    var flat_depth := await capture()
    var depth_delta := difference(authored,flat_depth)
    check(depth_delta > 0.0001,"Original packed depth materially changes the receiver lighting")
    lighting.sync({})
    var wall_dark := await capture()
    check(mean(wall_dark) < 0.001,"Original wall is dark without constant emission or sources")
    var output := "res://.runtime/presentation-checks"
    DirAccess.make_dir_recursive_absolute(output)
    authored.save_png(output.path_join("lighting-authored-wall.png"))
    lit.save_png(output.path_join("lighting-circular-radius.png"))
    evidence.merge({"wall_normal_mean_pixel_delta":normal_delta,"wall_depth_mean_pixel_delta":depth_delta,
        "wall_lit_mean":mean(authored),"source_count_stress":24,"renderer":RenderingServer.get_video_adapter_name()})
    var summary := {"checks":checks,"failures":failures,"elapsed_ms":Time.get_ticks_msec()-start,"evidence":evidence}
    var file := FileAccess.open(output.path_join("lighting_render_checks.json"),FileAccess.WRITE)
    file.store_string(JSON.stringify(summary,"  "))
    print("LIGHTING_RENDER_CHECKS ",JSON.stringify(summary)); quit(0 if failures.is_empty() else 1)
