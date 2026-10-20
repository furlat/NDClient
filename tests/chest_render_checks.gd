extends SceneTree
# Original vendor pixels versus the production 3D material, with the authored
# colour rectangle/pivot at one screen pixel per source pixel. No artwork edits.
const Catalog = preload("res://source_catalog.gd")
const Placement = preload("res://placement.gd")
const WorldRows = preload("res://presentation/world.gd")
const ORIGINALS = "C:/Users/tommaso/Documents/UnityProjects/SmallscaleExplore/Assets/SmallScaleInt/Fantasy kingdom Tileset/Environment/Sprites"
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

func check(condition: bool, message: String) -> void:
    checks += 1
    if not condition: failures.append(message); print("CHEST_RENDER_FAIL ",message)

func source_row(asset: String, opened: bool) -> Dictionary:
    var state = {"tiles":{},"objects":{"chest":{"item":{"item_id":asset,"is_open":opened},
        "placement":{"position":[0,0],"base_height_steps":0,"kind":"cell","orientation":"east"}}}}
    var result = WorldRows.rows(state,cache)
    check(result.unresolved.is_empty() and result.rows.size()==1,"Disclosed chest has an authored owner")
    return result.rows[0]

func capture() -> Image:
    for i in range(3): await process_frame
    await RenderingServer.frame_post_draw
    return root.get_texture().get_image()

func native_srgb(value: float, alpha: float) -> float:
    # Independent vendor-byte oracle for Forward+'s linear 3D blending on
    # black followed by standard sRGB output, with unchanged source alpha.
    # https://docs.godotengine.org/en/stable/engine_details/architecture/internal_rendering_architecture.html
    var linear:float=value/12.92 if value<=0.04045 else pow((value+0.055)/1.055,2.4)
    linear*=alpha
    return linear*12.92 if linear<=0.0031308 else 1.055*pow(linear,1.0/2.4)-0.055

func _initialize() -> void: run.call_deferred()

func run() -> void:
    if DisplayServer.get_name()=="headless": print("CHEST_RENDER_CHECKS requires native graphics"); quit(2); return
    root.size = Vector2i(1280,800)
    root.msaa_3d = Viewport.MSAA_DISABLED
    # source_unlit names the source-shadow pass in the production shader.
    # Identity receiving keeps the actual colour pass, with no scene lights.
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
    var reference := Sprite2D.new(); reference.centered = false
    reference.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    root.add_child(reference)
    var caption := Label.new(); caption.position = Vector2(220,120)
    caption.text = "Original Unity sprite (2D)                         Production chest (3D, unlit, 1:1)"
    root.add_child(caption)
    var output := "res://.runtime/presentation-checks"
    DirAccess.make_dir_recursive_absolute(output)
    # All existing chest owner pairs use their exact source JSON keys, and only
    # intact display is overridden. Destruction remains on the original bank.
    for asset in ["environment.storage_chest","environment.chest.fantasy_a1","environment.chest.fantasy_a3","environment.chest.fantasy_b1"]:
        var owner = Catalog.owner_for({"kind":"prop","asset":asset},cache)
        for opened in [false,true]:
            var row = source_row(asset,opened)
            var key := "true" if opened else "false"
            check(row.state==key,"Boolean prop state retains authored key")
            check(Catalog.bank_for(row,false,cache)==owner.intact[key],"Intact bank is owned by disclosed state")
            check(Catalog.bank_for(row,true,cache)==owner.destructions[key],"Destruction bank remains authored")
            for quarter in range(4):
                var record = Catalog.environment(row,quarter,cache)
                check(record.get("original_library")==Catalog.environment_index(cache).rests[owner.intact[key]],"All chest families select existing original rest")
                check(Catalog.environment(row,quarter,cache,1,0).bank==owner.destructions[key],"Destruction frame still uses original authored bank")
    for opened in [false,true]:
        var row = source_row("environment.storage_chest",opened)
        world.add_environment_entries(row)
        var seen_views := {}
        for quarter in range(4):
            world.quarter = quarter; world.position_camera()
            var record = Catalog.environment(row,quarter,cache)
            var original := Image.load_from_file(ORIGINALS.path_join(record.path.get_file()))
            var selected := Image.load_from_file(Catalog.media_path(record.path))
            check(original != null and selected != null and original.get_data()==selected.get_data(),"Selected colour is byte-exact Unity original")
            seen_views[record.path] = true
            check(Vector2(record.native_size[0],record.native_size[1])==Vector2(256,256) and Vector2(record.pivot[0],record.pivot[1])==Vector2(128,208) and record.scale==1,"Original registered canvas/pivot/scale are preserved")
            var library = Catalog.environment_file(Catalog.environment_index(cache).library[record.original_library],cache)
            var matching = library.samples.filter(func(sample):return sample.colour.path==record.path)[0]
            check(record.geometry==matching.surface.geometry and record.normal==matching.surface.normal,"Original colour uses its matching registered depth and normal")
            check(matching.source_view==Placement.pose(row.orientation,quarter),"Open and closed states retain the same original camera facing")
            check(world.prepare_sources().is_empty(),"All original colour/depth/normal source operands are physically prepared")
            for entry in world.entries:
                world.initialize_entry(entry)
                entry.node.position += world.camera.basis.x * (200.0/Placement.PIXELS_PER_UNIT)
                entry.material.render_priority = -1 if entry.source_role==0 else 0
            reference.texture = ImageTexture.create_from_image(original)
            var center := Vector2(root.size)*.5
            reference.position = center-Vector2(200,0)-Vector2(record.pivot[0],record.pivot[1])
            var frame := await capture()
            var right := center+Vector2(200,0)-Vector2(record.pivot[0],record.pivot[1])
            var max_delta := 0.0; var sum_delta := 0.0; var count := 0; var changed := 0
            var max_native_delta := 0.0
            var outside_alpha := 0
            for y in range(256):
                for x in range(256):
                    var source_pixel := original.get_pixel(x,y)
                    var right_pixel := frame.get_pixel(int(right.x)+x,int(right.y)+y)
                    if source_pixel.a==0:
                        if maxf(right_pixel.r,maxf(right_pixel.g,right_pixel.b))>2.0/255: outside_alpha += 1
                        continue
                    var left_pixel := frame.get_pixel(int(reference.position.x)+x,int(reference.position.y)+y)
                    var delta := maxf(absf(left_pixel.r-right_pixel.r),maxf(absf(left_pixel.g-right_pixel.g),absf(left_pixel.b-right_pixel.b)))
                    max_delta = maxf(max_delta,delta); sum_delta += delta; count += 1
                    var expected := Vector3(native_srgb(source_pixel.r,source_pixel.a),native_srgb(source_pixel.g,source_pixel.a),native_srgb(source_pixel.b,source_pixel.a))
                    var native_delta := maxf(absf(expected.x-right_pixel.r),maxf(absf(expected.y-right_pixel.g),absf(expected.z-right_pixel.b)))
                    max_native_delta = maxf(max_native_delta,native_delta)
                    if native_delta>2.0/255: changed += 1
            var result := {"opened":opened,"quarter":quarter,"path":record.path,"visible_pixels":count,"canvas_vs_spatial_max_pixel_delta":max_delta,"canvas_vs_spatial_mean_pixel_delta":sum_delta/maxi(count,1),"native_transfer_max_pixel_delta":max_native_delta,"changed_over_two_bytes_after_native_transfer":changed,"unexpected_opaque_pixels":outside_alpha}
            evidence.append(result)
            check(count>1000 and changed==0,"Native identity-lit pixels match original bytes through Forward+ linear-alpha/sRGB transfer")
            check(outside_alpha==0,"Transparent source pixels remain empty in the production render")
            frame.save_png(output.path_join("chest-original-%s-q%d.png" % ["open" if opened else "closed",quarter]))
        check(seen_views.size()==4,"Camera quarters use all four original authored views")
        for entry in world.entries: entry.node.queue_free()
        world.entries.clear(); await process_frame
    var summary := {"checks":checks,"failures":failures,"comparisons":evidence,"renderer":RenderingServer.get_video_adapter_name()}
    var file := FileAccess.open(output.path_join("chest_render_checks.json"),FileAccess.WRITE)
    file.store_string(JSON.stringify(summary,"  "))
    print("CHEST_RENDER_CHECKS ",JSON.stringify(summary)); quit(0 if failures.is_empty() else 1)
