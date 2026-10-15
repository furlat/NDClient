extends Node
## Real Produce Flame source at one requested clock and two native draw cadences.
## Framebuffer retirement/paused stability are the oracle, not speed_scale math.
var checks := 0
var failures: Array = []
var observations: Array = []

func check(value: bool, label: String) -> void:
    checks += 1
    if not value: failures.append(label); push_error(label)

func frame() -> void:
    await get_tree().process_frame
    await RenderingServer.frame_post_draw

func pause(world: Node) -> void:
    world.playing = false
    world.loop = false
    world.set_process(false)

func isolate_flight(world: Node, cue: Dictionary) -> void:
    # Inspect this existing source only. Other native impacts/casts must not
    # influence its retirement measurement or its source light contribution.
    for id in world.handles:
        if id != cue.id: world.handles[id].root.hide()

func advance(world: Node, cue: Dictionary, until: float, deltas: Array) -> void:
    while world.elapsed < until:
        await get_tree().process_frame
        world.elapsed = minf(until, world.elapsed + 1.0 / 60.0)
        world._sample_frame(1.0 / 60.0)
        isolate_flight(world, cue)
        deltas.append(world.handles[cue.id].root.get_process_delta_time())
        await RenderingServer.frame_post_draw

func covered(image: Image) -> int:
    var count := 0
    for y in range(0, image.get_height(), 2):
        for x in range(0, image.get_width(), 2):
            if image.get_pixel(x, y).a > 0.12: count += 1
    return count

func removed_pixels(before: Image, after: Image) -> int:
    var count := 0
    for y in range(0, before.get_height(), 2):
        for x in range(0, before.get_width(), 2):
            var a := before.get_pixel(x, y)
            var b := after.get_pixel(x, y)
            var difference := absf(a.a - b.a) + absf(a.r * a.a - b.r * b.a) + absf(a.g * a.a - b.g * b.a) + absf(a.b * a.a - b.b * b.a)
            if difference > 0.12: count += 1
    return count

func retirement(world: Node, cue: Dictionary, label: String) -> Dictionary:
    var handle: Dictionary = world.handles[cue.id]
    check(handle.root.visible, label + ": measure the source before host retirement")
    check(handle.emitters.all(func(node): return not node.emitting), label + ": contact stopped all native emitters")
    var before: Image = world.effect_layer.viewport.get_texture().get_image()
    handle.root.hide()
    await frame()
    var after: Image = world.effect_layer.viewport.get_texture().get_image()
    var removed := removed_pixels(before, after)
    # Same acceptance boundary as the existing complete choreography test.
    check(removed <= 64, label + ": authored native tail is visually spent (%d samples)" % removed)
    before.save_png("res://.captures/particle-clock/" + label + ".png")
    handle.root.show()
    await frame()
    return {"world_seconds":world.elapsed, "source_seconds":handle.age, "removed_pixel_samples":removed}

func cadence(deltas: Array) -> Dictionary:
    var ordered := deltas.duplicate()
    ordered.sort()
    return {"frames":ordered.size(), "min_seconds":ordered.front(),
        "median_seconds":ordered[ordered.size() / 2], "max_seconds":ordered.back()}

func run(world: Node) -> void:
    var previous_vsync := DisplayServer.window_get_vsync_mode()
    var previous_max_fps := Engine.max_fps
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    DirAccess.make_dir_recursive_absolute("res://.captures/particle-clock")
    var selected := -1
    for index in world.spells.size():
        if world.spells[index].spell_id == "produce_flame": selected = index
    check(selected >= 0, "Real Produce Flame library entry exists")
    if selected >= 0:
        for fps in [30, 120]:
            Engine.max_fps = fps
            world.select_spell(selected)
            pause(world)
            for tick in 4: await frame()
            var cue: Dictionary = {}
            for candidate in world.cue_plan.cues:
                if candidate.role == "flight": cue = candidate
            check(not cue.is_empty(), "%dHz: real flight cue exists" % fps)
            if cue.is_empty(): continue
            var deltas: Array = []
            await advance(world, cue, lerpf(cue.launch, cue.contact, 0.5), deltas)
            var image: Image = world.effect_layer.viewport.get_texture().get_image()
            var travel_coverage := covered(image)
            check(travel_coverage > 64, "%dHz: actual native flight has visible coverage" % fps)
            image.save_png("res://.captures/particle-clock/%d-travel.png" % fps)
            var bytes := image.get_data()
            var held_age: float = world.handles[cue.id].age
            for tick in 3:
                await get_tree().process_frame
                world._sample_frame(0.0)
                isolate_flight(world, cue)
                await RenderingServer.frame_post_draw
                check(world.effect_layer.viewport.get_texture().get_image().get_data() == bytes, "%dHz: paused native framebuffer remains identical on draw%d" % [fps, tick])
                check(world.handles[cue.id].age == held_age, "%dHz: pause retains requested source age" % fps)
            # Keep the exact existing pre-retirement sample, then the final
            # open-interval sample. Neither adds an artificial settling tail.
            await advance(world, cue, cue.end - 0.02, deltas)
            var prior := await retirement(world, cue, "%d-before-retire" % fps)
            await advance(world, cue, cue.end - 0.000001, deltas)
            var endpoint := await retirement(world, cue, "%d-retire-boundary" % fps)
            await advance(world, cue, cue.end, deltas)
            check(not world.handles[cue.id].root.visible, "%dHz: host retires exactly at the unchanged cue boundary" % fps)
            observations.append({"render_cap_fps":fps, "requested_step_seconds":1.0 / 60.0,
                "native_delta":cadence(deltas), "travel_pixel_samples":travel_coverage,
                "pre_retirement":prior, "retirement_boundary":endpoint})
        if observations.size() == 2:
            check(observations[0].native_delta.median_seconds > observations[1].native_delta.median_seconds * 1.5,
                "Measured native cadence differs; nominal FPS labels alone do not qualify the clock")
            check(is_equal_approx(observations[0].pre_retirement.source_seconds, observations[1].pre_retirement.source_seconds),
                "Both native cadences qualify the same pre-retirement source age")
            check(is_equal_approx(observations[0].retirement_boundary.source_seconds, observations[1].retirement_boundary.source_seconds),
                "Both native cadences qualify the same final source age")
    Engine.max_fps = previous_max_fps
    DisplayServer.window_set_vsync_mode(previous_vsync)
    var report := {"checks":checks, "failures":failures, "observations":observations,
        "qualification":"Actual Produce Flame flight framebuffer at one 60 Hz requested clock, measured 30/120 FPS render caps, unchanged authored tail and source-emission stop; no extra time padding"}
    FileAccess.open("res://.runtime/sandbox-particle-clock-checks.json", FileAccess.WRITE).store_string(JSON.stringify(report, "  "))
    print("SANDBOX_PARTICLE_CLOCK ", JSON.stringify(report))
    get_tree().quit(0 if failures.is_empty() else 1)
