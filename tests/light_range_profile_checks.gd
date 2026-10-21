extends SceneTree
## Actual admitted light -> PointLight2D and its generated radial source image.
## No framebuffer/radiance claim; the independent native Gradient oracle is retained.
const Journal = preload("res://sdk/journal.gd")
const Lighting = preload("res://presentation/lighting_2d.gd")
const Existing = preload("res://presentation/lighting.gd")
const Placement = preload("res://placement.gd")
var checks := 0
var failures: Array = []
var evidence: Array = []

func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok: failures.append(label); print("LIGHT_RANGE_FAIL ", label)

func _initialize() -> void:
    run.call_deferred()

func prepare_cookies(adapter:RefCounted,resolved:Dictionary)->void:
    var until:int=Time.get_ticks_msec()+10000
    while resolved.sources.any(func(source):return adapter.prepare_cookie(source)==null) and Time.get_ticks_msec()<until:
        await process_frame
    check(resolved.sources.all(func(source):return not adapter.cookie_pending(source)),"Actual asynchronous radial source images complete before native publication")

func run() -> void:
    var recording := ""
    var sequence := 8
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--recording="): recording = arg.trim_prefix("--recording=")
        if arg.begins_with("--sequence="): sequence = int(arg.trim_prefix("--sequence="))
    if recording.is_empty():
        print("Usage: --recording=<real Hide/light journal> [--sequence=8]")
        quit(2); return
    var journal = Journal.new()
    var opened: Dictionary = journal.open(recording, true, false)
    check(opened.ok, "Actual journal opens")
    if not opened.ok: quit(1); return
    var replayed: Dictionary = journal.replay(sequence)
    check(replayed.ok, "Strict public replay admits requested boundary")
    if not replayed.ok: quit(1); return
    var state: Dictionary = journal.snapshot()
    var original := state.duplicate(true)
    var resolved: Dictionary = Lighting.resolve(state)
    var carried: Array = resolved.sources.filter(func(s): return s.actor_uuid in state.audience.controlled and s.item_id == "equipment.portable_torch")
    check(carried.size() == 1, "Real boundary contains one controlled lit portable torch")
    if carried.size() != 1: quit(1); return
    var source: Dictionary = carried[0]
    var baseline = Existing.new()
    baseline.sources = resolved.sources
    baseline.sample({})
    var view := SubViewport.new()
    view.size = Vector2i(768, 512)
    root.add_child(view)
    var camera := Camera3D.new()
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.size = 12.0
    view.add_child(camera)
    camera.position = Vector3(14, 10, 14)
    camera.look_at(Vector3(4, 0, 6))
    var page := SubViewport.new()
    page.size = Vector2i(1024, 1024)
    page.disable_3d = true
    root.add_child(page)
    var adapter = Lighting.new()
    adapter.attach(page)
    await prepare_cookies(adapter,resolved)
    adapter.sync(state)
    adapter.project(camera)
    check(adapter.range_profile != null and adapter.issues.is_empty(), "Default native range profile resolves without external cookie or source errors")
    var node: PointLight2D = adapter.nodes[source.item_uuid]
    var initial_texture: Texture2D = node.texture
    var centre: Vector3 = camera.position - camera.basis.z * 10.0
    var ppu: float = camera.unproject_position(centre + camera.basis.x).distance_to(camera.unproject_position(centre))
    var expected_height := 56.0 * 2.0 / Placement.PIXELS_PER_UNIT * ppu
    check(adapter.sampled[source.item_uuid].position == baseline.sampled[source.item_uuid].position, "Default profile preserves the existing world emitter anchor")
    check(node.position.is_equal_approx(camera.unproject_position(baseline.sampled[source.item_uuid].position)), "Default source remains at the exact projected anchor")
    check(node.color == Lighting.TORCH_COLOUR and node.energy == baseline.sampled[source.item_uuid].energy, "Default warm color and native energy remain unchanged")
    check(is_equal_approx(node.height, expected_height), "Default native normal height remains56 source pixels")
    check([source.very_bright_radius_feet, source.bright_radius_feet, source.dim_radius_feet] == [10, 20, 20], "Actual server torch supplies10/20/+20feet")

    # Expected knot positions are explicit backend units: fractional very-bright,
    # floored bright/total cells; coincident zone boundaries have one native knot.
    var cases := [
        {"name":"actual_torch", "feet":[10,20,20], "outer":8.0, "knots":[0.0,0.25,0.5,1.0], "intensities":[1.0,.85,.7,0.0]},
        {"name":"different_inner_same_outer", "feet":[5,15,25], "outer":8.0, "knots":[0.0,0.125,0.375,1.0], "intensities":[1.0,.85,.7,0.0]},
        {"name":"same_ratios_double_radius", "feet":[20,40,40], "outer":16.0, "knots":[0.0,0.25,0.5,1.0], "intensities":[1.0,.85,.7,0.0]},
        {"name":"fractional_very_floored_bright", "feet":[7,17,23], "outer":8.0, "knots":[0.0,0.175,0.375,1.0], "intensities":[1.0,.85,.7,0.0]},
        {"name":"coincident_inner_boundaries", "feet":[10,10,30], "outer":8.0, "knots":[0.0,0.25,1.0], "intensities":[1.0,.85,0.0]},
        {"name":"zero_very", "feet":[0,20,20], "outer":8.0, "knots":[0.0,0.5,1.0], "intensities":[.85,.7,0.0]},
        {"name":"no_dim", "feet":[10,20,0], "outer":4.0, "knots":[0.0,0.5,1.0], "intensities":[1.0,.85,0.0]},
        {"name":"all_zero_native_minimum", "feet":[0,0,0], "outer":1.0, "knots":[0.0,1.0], "intensities":[.85,0.0]},
        {"name":"very_at_outer", "feet":[20,20,0], "outer":4.0, "knots":[0.0,1.0], "intensities":[1.0,0.0]}]
    var textures := {}
    for item_case in cases:
        var candidate := state.duplicate(true)
        var item: Dictionary = candidate.light_sources[source.item_uuid]
        item.very_bright_radius_feet = item_case.feet[0]
        item.bright_radius_feet = item_case.feet[1]
        item.dim_radius_feet = item_case.feet[2]
        await prepare_cookies(adapter,Lighting.resolve(candidate))
        adapter.sync(candidate)
        adapter.project(camera)
        var row: Dictionary = adapter.canvas_sources().filter(func(r): return r.id == source.item_uuid)[0]
        check(adapter.nodes[source.item_uuid] == node, item_case.name + ": retained native emitter")
        check(node.texture is ImageTexture and row.texture == node.texture and node.texture.has_meta(&"cookie_image"), item_case.name + ": public node/exposure share the actual completed radial source image")
        var texture:Texture2D=node.texture
        textures[item_case.name]=texture
        var image:Image=texture.get_meta(&"cookie_image")
        # Retain the native Gradient numerical oracle and original explicit
        # boundary values, independently of the production cookie generator.
        var gradient=Gradient.new();gradient.interpolation_mode=Gradient.GRADIENT_INTERPOLATE_CUBIC
        gradient.offsets=PackedFloat32Array(item_case.knots)
        var colours=PackedColorArray()
        for value in item_case.intensities:colours.append(Color(value,value,value))
        gradient.colors=colours
        var offsets:PackedFloat32Array=gradient.offsets.duplicate();offsets.sort()
        var exact:bool=image.get_size()==Vector2i(256,256) and image.get_format()==Image.FORMAT_RGBA8
        var error:float=0.0
        for y in image.get_height():
            for x in image.get_width():
                var radius:float=clampf((Vector2(x,y)/float(image.get_width()-1)-Vector2(.5,.5)).length()*2.0,0.0,1.0)
                var expected:Color=gradient.sample(radius)
                var actual:Color=image.get_pixel(x,y)
                error=maxf(error,absf(actual.r-expected.r))
                exact=exact and actual.r==actual.g and actual.g==actual.b and actual.a==1.0
        check(exact and error<=1.0/255.0, item_case.name + ": every generated radial pixel matches the independent native Gradient within one RGBA8 quantum, including exact supplied zone ratios")
        check(is_equal_approx(row.outer, item_case.outer) and is_equal_approx(row.span.x, 2.0 * item_case.outer * ppu) and is_equal_approx(row.span.y, row.span.x * absf(camera.basis.z.y)), item_case.name + ": exact backend total radius drives projected support ellipse")
        check(node.position.is_equal_approx(camera.unproject_position(baseline.sampled[source.item_uuid].position)) and node.color == Lighting.TORCH_COLOUR and is_equal_approx(node.height, expected_height), item_case.name + ": radius changes preserve position/color/height")
        var finite := true
        var monotonic := true
        var previous := INF
        var low := INF
        var high := -INF
        for i in 1025:
            var c: Color = gradient.sample(float(i) / 1024.0)
            finite = finite and is_finite(c.r) and is_finite(c.g) and is_finite(c.b) and c.r >= 0.0 and c.r <= 1.0 and c.r == c.g and c.r == c.b
            monotonic = monotonic and c.r <= previous + 0.000001
            previous = c.r
            low = minf(low,c.r); high = maxf(high,c.r)
        check(finite, item_case.name + ": radial samples finite/grayscale/in0..1")
        check(monotonic, item_case.name + ": radial intensity never increases away from source")
        check(gradient.sample(1.0).r == 0.0, item_case.name + ": outer edge is zero")
        evidence.append({"case":item_case.name,"feet":item_case.feet,"outer_cells":row.outer,"offsets":Array(offsets),"minimum":low,"maximum":high,"monotonic":monotonic,"finite":finite})
    check(textures.actual_torch == initial_texture, "Equal source/profile reuses original native texture")
    check(textures.same_ratios_double_radius == initial_texture, "Common boundary ratios reuse one native texture across absolute ranges")
    check(textures.different_inner_same_outer != initial_texture and textures.different_inner_same_outer.get_meta(&"cookie_image").get_data()!=initial_texture.get_meta(&"cookie_image").get_data(), "Changed inner radii at same outer change actual native profile")
    var duplicated := state.duplicate(true)
    duplicated.light_sources[source.item_uuid]=duplicated.light_sources[source.item_uuid].duplicate(true)
    adapter.sync(duplicated); adapter.project(camera)
    check(adapter.nodes.size() == resolved.sources.size() and adapter.canvas_sources().size() == resolved.sources.size(), "Repeated canonical light-source identity creates no duplicate emitter")
    check(node.texture == initial_texture and node.enabled, "Repeated source publication retains the actual finite enabled profile")
    check(state == original and journal.snapshot() == original, "All radius perturbations leave admitted replay state untouched")
    adapter.clear_pages()
    view.queue_free(); page.queue_free()
    await process_frame
    var report := {"checks":checks,"failures":failures,"recording":recording,"sequence":sequence,"cases":evidence,
        "scope":"Headless PointLight2D and actual completed radial ImageTexture source from original admitted Hide/light optical descriptors plus named radius perturbations. Independent native Gradient oracle checks every RGBA8 source pixel and exact expected boundary profile; finite monotone radial samples, canonical identity reuse and unchanged positioning/color/height remain. No framebuffer, world-floor radiance or gameplay-light equivalence claim.",
        "invocation":{"script":"res://tests/light_range_profile_checks.gd","arguments":Array(OS.get_cmdline_user_args())}}
    FileAccess.open("res://generated/light_range_profile_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("LIGHT_RANGE_PROFILE ",JSON.stringify({"checks":checks,"failures":failures}))
    quit(0 if failures.is_empty() else 1)
