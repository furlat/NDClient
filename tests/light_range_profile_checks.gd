extends SceneTree
## Actual admitted light -> native PointLight2D gradient boundary. No pixel claim.
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
    var resolved: Dictionary = Existing.resolve(state)
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
        var item: Dictionary = candidate.actors[source.actor_uuid].controlled_items.filter(func(i): return i.item_uuid == source.item_uuid)[0]
        item.very_bright_radius_feet = item_case.feet[0]
        item.bright_radius_feet = item_case.feet[1]
        item.dim_radius_feet = item_case.feet[2]
        adapter.sync(candidate)
        adapter.project(camera)
        var row: Dictionary = adapter.canvas_sources().filter(func(r): return r.id == source.item_uuid)[0]
        check(adapter.nodes[source.item_uuid] == node, item_case.name + ": retained native emitter")
        check(node.texture is GradientTexture2D and row.texture == node.texture, item_case.name + ": public node/exposure share native gradient")
        var texture: GradientTexture2D = node.texture
        textures[item_case.name] = texture
        var gradient: Gradient = texture.gradient
        # Native Gradient may retain insertion order until its first sample.
        # Compare boundary positions, without mutating its storage or point colors.
        var offsets: PackedFloat32Array = gradient.offsets.duplicate()
        offsets.sort()
        var expected: Array = item_case.knots
        var exact := offsets.size() == expected.size()
        for i in mini(offsets.size(), expected.size()):
            exact = exact and is_equal_approx(offsets[i], expected[i])
        check(exact, item_case.name + ": exact very/bright/outer boundary ratios")
        var edge_values := true
        for i in expected.size():
            edge_values = edge_values and is_equal_approx(gradient.sample(expected[i]).r, item_case.intensities[i])
        check(edge_values, item_case.name + ": actual sampled boundary intensities match the default authored profile")
        check(texture.fill == GradientTexture2D.FILL_RADIAL and texture.fill_from == Vector2(.5,.5) and texture.fill_to == Vector2(1,.5), item_case.name + ": native radial texture spans centre to outer radius")
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
    check(textures.different_inner_same_outer != initial_texture and not is_equal_approx(textures.different_inner_same_outer.gradient.sample(.25).r, initial_texture.gradient.sample(.25).r), "Changed inner radii at same outer change actual native profile")
    var duplicated := state.duplicate(true)
    var items: Array = duplicated.actors[source.actor_uuid].controlled_items
    items.append(items.filter(func(i): return i.item_uuid == source.item_uuid)[0].duplicate(true))
    adapter.sync(duplicated); adapter.project(camera)
    check(adapter.nodes.size() == resolved.sources.size() and adapter.canvas_sources().size() == resolved.sources.size(), "Repeated disclosed item identity creates no duplicate emitter")
    check(node.texture == initial_texture and node.enabled, "Duplicate source retains the actual finite enabled profile")
    check(state == original and journal.snapshot() == original, "All radius perturbations leave admitted replay state untouched")
    adapter.clear_pages()
    view.queue_free(); page.queue_free()
    await process_frame
    var report := {"checks":checks,"failures":failures,"recording":recording,"sequence":sequence,"cases":evidence,
        "scope":"Headless native PointLight2D/GradientTexture2D boundary from actual admitted Hide/light state plus named radius perturbations. Tests source ratios, finite monotonic radial profile, identity reuse and unchanged positioning/color/height. No framebuffer, world-floor radiance or gameplay-light equivalence claim.",
        "invocation":{"script":"res://tests/light_range_profile_checks.gd","arguments":Array(OS.get_cmdline_user_args())}}
    FileAccess.open("res://generated/light_range_profile_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("LIGHT_RANGE_PROFILE ",JSON.stringify({"checks":checks,"failures":failures}))
    quit(0 if failures.is_empty() else 1)
