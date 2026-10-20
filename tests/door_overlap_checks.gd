extends SceneTree
# Original registered leaf/frame pixels through production materials. The CPU
# masks below are a test oracle only, independently decoded from source JSON;
# production partitions the unchanged source texture on the GPU.
const Catalog = preload("res://source_catalog.gd")
const Placement = preload("res://placement.gd")
const SourceMaterial=preload("res://presentation/source_material.gd")
const Graphs = preload("res://animation/graphs.gd")
class Probe extends "res://presentation/sprite_sources.gd":
    func _ready() -> void:
        set_process(false); set_process_unhandled_input(false)
        camera = Camera3D.new(); camera.projection = Camera3D.PROJECTION_ORTHOGONAL
        camera.size = get_viewport().get_visible_rect().size.y / Placement.PIXELS_PER_UNIT
        add_child(camera); camera.current = true; position_camera()
    func _process(_delta: float) -> void: pass
    func prepare_sources() -> Array:
        # Preparation owns original physical pixels; texture() only borrows
        # these admitted handles while the production material is sampled.
        var missing:Array=[]
        for entry in entries:
            var row:Dictionary=entry.placement
            var record:Dictionary=Catalog.door_frame(row,quarter,catalog_cache) if entry.source_role==2 else record_for(row)
            if record.is_empty():continue
            var description:Dictionary=EnvironmentSource.describe(row,record,entry.source_role,quarter,camera.basis,source_depth,source_normals)
            for path in description.texture_parameters.values():
                if textures.has(path):continue
                var image:Image=Image.load_from_file(Catalog.media_path(path))
                if image==null or image.is_empty():missing.append(path);continue
                source_images[path]=image;textures[path]=ImageTexture.create_from_image(image)
        return missing
    func texture(path:String) -> Texture2D:
        assert(textures.has(path),"Native source probe requires its exact prepared physical texture: "+path)
        return textures.get(path)

var checks := 0
var failures: Array = []
var evidence: Array = []
var cache := {}

func check(condition: bool, label: String) -> void:
    checks += 1
    if not condition: failures.append(label); print("DOOR_OVERLAP_FAIL ",label)

func _initialize() -> void: run.call_deferred()

func capture() -> Image:
    for i in range(3): await process_frame
    await RenderingServer.frame_post_draw
    return root.get_texture().get_image()

func delta(a: Image, b: Image) -> Dictionary:
    var different := 0; var maximum := 0.0
    for y in range(a.get_height()):
        for x in range(a.get_width()):
            var p := a.get_pixel(x,y); var q := b.get_pixel(x,y)
            var distance := maxf(absf(p.r-q.r),maxf(absf(p.g-q.g),absf(p.b-q.b)))
            maximum = maxf(maximum,distance)
            if distance > 1.0/255.0 + 0.00001: different += 1
    return {"different_pixels":different,"maximum":maximum}

func oracle(row: Dictionary, quarter: int) -> Dictionary:
    var owner := Catalog.owner_for(row,cache)
    var bank := Catalog.bank_data(owner.openings["inward" if row.state=="open.inward" else "outward"],cache)
    # The retired runtime owner no longer carries source measurement prose.
    # Read the exact delivered registration independently of Catalog.pose_for.
    var source:Resource=load("res://authoring/environment/objects/environment.directional_door.tres")
    var registration:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/"+source.measurements))
    var pose: String = Placement.POSES[posmod(Placement.POSES.find(Placement.pose(row.orientation,quarter))-int(registration.pose_offset),4)]
    var frame: int = 0 if row.state=="closed" else int(bank.frame_count)-1
    var region: Dictionary = bank.frames_by_pose[pose][frame]
    var depth_region: Dictionary = bank.depth_frames_by_pose[pose][frame]
    var colour := Image.load_from_file(Catalog.media_path(region.path)).get_region(Rect2i(region.rect[0],region.rect[1],region.rect[2],region.rect[3]))
    var depth := Image.load_from_file(Catalog.media_path(depth_region.path))
    var behind := colour.duplicate() as Image; var front := colour.duplicate() as Image
    var low: float = bank.actor_depth.depth_range[0]; var high: float = bank.actor_depth.depth_range[1]
    var multiplier: float = bank.actor_depth.pixels_per_unit_by_pose[pose]*bank.scale
    var origin: float = (bank.ground_origins_by_pose[pose][1]-bank.pivots_by_pose[pose][1])*bank.scale
    var cutoff: float = 16 if pose in ["e","s"] else -16
    var back_pixels := 0; var front_pixels := 0; var semitransparent := 0
    for y in range(colour.get_height()):
        for x in range(colour.get_width()):
            var rgba := colour.get_pixel(x,y)
            var d := depth.get_pixel(int(depth_region.rect[0])+x,int(depth_region.rect[1])+y)
            var encoded := roundi(d.r*255.0)+256*roundi(d.g*255.0)
            var painter: float = cutoff if encoded==0 else ((encoded-1)/65534.0*(high-low)+low)*multiplier+origin
            if painter <= cutoff:
                front.set_pixel(x,y,Color.TRANSPARENT)
                if rgba.a > 0: back_pixels += 1
            else:
                behind.set_pixel(x,y,Color.TRANSPARENT)
                if rgba.a > 0: front_pixels += 1
            if rgba.a > 0 and rgba.a < 1: semitransparent += 1
    return {"back":ImageTexture.create_from_image(behind),"front":ImageTexture.create_from_image(front),
        "back_pixels":back_pixels,"front_pixels":front_pixels,"semitransparent":semitransparent,
        "pivot":bank.pivots_by_pose[pose],"scale":bank.scale,"colour":region,"frame":frame}

func prepare(world: Node, quarter: int) -> void:
    world.quarter = quarter; world.position_camera()
    check(world.prepare_sources().is_empty(),"Exact original leaf/frame/partition/depth/normal source operands are physically prepared")
    for entry in world.entries:
        # CPU oracle replaced texture uniforms directly; discard that fixture
        # ledger before rebuilding the unchanged production descriptor.
        SourceMaterial.initialize(entry)
        world.initialize_entry(entry)
        entry.material.render_priority = entry.layer

func run() -> void:
    if DisplayServer.get_name()=="headless": print("DOOR_OVERLAP_CHECKS requires native graphics"); quit(2); return
    root.unfocusable = true; root.position = Vector2i(-16000,-16000); root.size = Vector2i(512,512)
    root.msaa_3d = Viewport.MSAA_DISABLED
    RenderingServer.global_shader_parameter_set(&"light_count",0)
    RenderingServer.global_shader_parameter_set(&"light_ambient",1.0)
    RenderingServer.global_shader_parameter_set(&"light_cap",0.0)
    RenderingServer.global_shader_parameter_set(&"light_normals",false)
    var environment := WorldEnvironment.new(); environment.environment = Environment.new()
    environment.environment.background_mode = Environment.BG_COLOR
    environment.environment.background_color = Color.BLACK
    environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
    root.add_child(environment)
    var world := Probe.new(); root.add_child(world)
    var row := {"id":"original-door","kind":"door","asset":"environment.directional_door","position":[0,0],
        "base_height_steps":0,"orientation":"east","boundaries":["east"],"layer":0,"state":"closed"}
    world.add_environment_entries(row)
    var output := "res://.runtime/presentation-checks/doors"
    DirAccess.make_dir_recursive_absolute(output)
    for state in ["closed","open.inward","open.outward"]:
        row.state = state
        for quarter in range(4):
            prepare(world,quarter)
            var record := Catalog.environment(row,quarter,cache)
            var expected := oracle(row,quarter)
            check(record.path==expected.colour.path and record.rect==expected.colour.rect and record.frame==expected.frame,"Original source frame: %s q%d" % [state,quarter])
            check(record.pivot==expected.pivot and record.scale==expected.scale,"Original hinge registration: %s q%d" % [state,quarter])
            var leaf: Dictionary; var back: Dictionary; var frame: Dictionary
            for entry in world.entries:
                if entry.source_role==1: leaf = entry
                if entry.source_role==3: back = entry
                if entry.source_role==2: frame = entry
            check(back.node.visible and back.node.position==leaf.node.position and back.pivot==leaf.pivot,"Leaf partitions share identical contact and original pivot")
            check(expected.back_pixels>0 and expected.front_pixels>0,"Real source exercises pixels on both sides of the frame")
            var actual := await capture()
            # Independent original-pixel oracle: same materials, but original
            # leaf alpha split on CPU instead of production numeric GPU texture.
            for pair in [[back,expected.back],[leaf,expected.front]]:
                pair[0].material.set_shader_parameter("door_leaf_partition",0)
                pair[0].material.set_shader_parameter("colour_texture",pair[1])
                pair[0].material.set_shader_parameter("colour_rect",Vector4(0,0,256,256))
                pair[0].material.set_shader_parameter("colour_size",Vector2(256,256))
            var reference := await capture()
            var comparison := delta(actual,reference)
            check(comparison.different_pixels==0,"GPU assembly equals independently decoded original pixels: %s q%d" % [state,quarter])
            prepare(world,quarter)
            back.node.visible = false; leaf.material.set_shader_parameter("door_leaf_partition",0)
            var previous := await capture()
            var prior := delta(actual,previous)
            check(prior.different_pixels>0,"Regression reproduces old leaf-over-frame error: %s q%d" % [state,quarter])
            leaf.material.render_priority = -1
            var reversed := await capture()
            var reverse_delta := delta(actual,reversed)
            # Open rear-facing views include a substantial foreground region;
            # a whole-frame reversal must fail those cases too.
            if state=="open.outward" and quarter in [2,3]:
                check(reverse_delta.different_pixels>10,"Whole-frame order reversal is insufficient")
            evidence.append({"state":state,"quarter":quarter,"original_back_pixels":expected.back_pixels,
                "original_front_pixels":expected.front_pixels,"semitransparent":expected.semitransparent,
                "oracle_delta":comparison,"previous_order_delta":prior,"reversed_order_delta":reverse_delta})
            actual.save_png(output.path_join("%s-q%d.png" % [state,quarter]))
            previous.save_png(output.path_join("previous-%s-q%d.png" % [state,quarter]))
    # No duplicate leaf opacity for a bank without legacy registration, or when
    # the intact door switches to its authored destruction sequence.
    row.state = "closed"
    var intact := Catalog.environment(row,0,cache)
    var broken := Catalog.environment(row,0,cache,1,0)
    check(intact.has("door_partition") and not broken.has("door_partition"),"Destruction remains on its original single bank pass")
    var playback := Graphs.destruction(world,Catalog.break_duration(row,cache))
    world.destruction[row.id] = playback
    Graphs.request(playback,"Breaking"); Graphs.advance(playback,0.1)
    prepare(world,0)
    for entry in world.entries:
        if entry.source_role==3: check(not entry.node.visible,"Transition into destruction omits extra leaf pass")
        if entry.source_role==1: check(entry.node.visible and entry.material.get_shader_parameter("door_leaf_partition")==0,"Destruction keeps one complete source leaf pass")
    world.destruction.clear(); playback.queue_free()
    row.asset = "environment.door.indoor_door_elegant"
    prepare(world,0)
    for entry in world.entries:
        if entry.source_role==3: check(not entry.node.visible,"Unregistered bank omits extra leaf pass")
        if entry.source_role==1: check(entry.node.visible and entry.material.get_shader_parameter("door_leaf_partition")==0,"Unregistered bank keeps original leaf")
    var report := {"checks":checks,"failures":failures,"cases":evidence,"renderer":RenderingServer.get_video_adapter_name(),
        "scope":"Local intact legacy-registered door leaf/frame overlap only; unchanged original art, alpha, pivot and light packets."}
    var file := FileAccess.open("res://generated/door_overlap_checks.json",FileAccess.WRITE)
    file.store_string(JSON.stringify(report,"  ")); file.close()
    print("DOOR_OVERLAP_CHECKS ",JSON.stringify({"checks":checks,"failures":failures,"cases":evidence}))
    quit(0 if failures.is_empty() else 1)
