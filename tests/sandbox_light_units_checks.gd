extends SceneTree
## Native range cutoff on a selected lit donor material, plus source-clock
## replay. The control is an ordinary Omni with explicit world-unit lengths.
const Units = preload("res://sandbox/light_units.gd")
const DONOR = "res://assets/native_effects/sandbox/projectiles/library/lelu/pack_lelu_godot_patreons_community_pack_3_d/VFX/Scenes/VFX_DemonPunch.tscn"
var checks := 0
var failures: Array = []
var samples: Array = []

func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok: failures.append(label); print("LIGHT_UNITS_FAIL ", label)

func _initialize() -> void:
    root.position = Vector2i(-16000, -16000)
    root.unfocusable = true
    run.call_deferred()

func _track(animation: Animation, path: String, first: Variant, last: Variant) -> void:
    var index := animation.add_track(Animation.TYPE_VALUE)
    animation.track_set_path(index, NodePath(path))
    animation.track_insert_key(index, 0.0, first)
    animation.track_insert_key(index, 1.0, last)

func _parameters() -> void:
    var owner := Node3D.new(); root.add_child(owner)
    var light := OmniLight3D.new(); light.name = "Pulse"; owner.add_child(light)
    light.omni_range = 6.0; light.light_size = .2
    var bindings := {light.get_instance_id():Units.prepare(light)}
    var player := AnimationPlayer.new(); owner.add_child(player)
    player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
    var animation := Animation.new(); animation.length = 1.0
    _track(animation, "Pulse:omni_range", 6.0, 10.0)
    _track(animation, "Pulse:light_size", .2, .6)
    _track(animation, "Pulse:light_energy", 4.0, 2.0)
    _track(animation, "Pulse:light_color", Color(.2, .4, 1), Color(1, .3, .1))
    var library := AnimationLibrary.new(); library.add_animation("pulse", animation)
    player.add_animation_library("", library); player.play("pulse")
    for age in [0.0, .25, .7, .3, .7]:
        Units.restore(bindings)
        player.seek(age, true)
        var authored_range := light.omni_range
        var authored_size := light.light_size
        var authored_energy := light.light_energy
        var authored_color := light.light_color
        Units.apply(bindings, .085)
        check(is_equal_approx(light.omni_range, authored_range * .085), "Animated range converts once at %.2fs" % age)
        check(is_equal_approx(light.light_size, authored_size * .085), "Animated emitter size converts once at %.2fs" % age)
        check(light.light_energy == authored_energy and light.light_color == authored_color, "Range conversion preserves native energy and colour at %.2fs" % age)
        check(bindings[light.get_instance_id()].range == authored_range and bindings[light.get_instance_id()].size == authored_size, "Raw lengths remain available to the optical bridge at %.2fs" % age)
        for scale in [.5, .085, .085, 1.0]:
            Units.rescale(bindings, scale)
            check(is_equal_approx(light.omni_range, authored_range * scale) and is_equal_approx(light.light_size, authored_size * scale), "Same-age rescale does not accumulate at %.2fs scale%.3f" % [age, scale])
        Units.restore(bindings)
        check(light.omni_range == authored_range and light.light_size == authored_size, "Next authoring sample starts from raw lengths at %.2fs" % age)
        check(is_equal_approx(player.current_animation_position, age), "Unit conversion never advances the animation clock at %.2fs" % age)
    owner.queue_free()
    await process_frame
    Units.restore(bindings); Units.rescale(bindings, .5)
    check(not is_instance_valid(bindings.values()[0].node), "Retired light bindings do not recreate native nodes")

func _world(material: StandardMaterial3D, raw_range: float, scale: float, mode: String) -> Dictionary:
    var radius := raw_range * scale
    var view := SubViewport.new(); view.size = Vector2i(256, 256)
    view.own_world_3d = true; view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    root.add_child(view)
    var environment := WorldEnvironment.new(); environment.environment = Environment.new()
    environment.environment.background_mode = Environment.BG_COLOR
    environment.environment.background_color = Color.BLACK
    environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
    view.add_child(environment)
    var camera := Camera3D.new(); view.add_child(camera)
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL; camera.size = radius * 2.5
    camera.position = Vector3(0, 0, radius * 4); camera.near = .001; camera.far = 100
    camera.current = true
    var surface := MeshInstance3D.new(); surface.mesh = QuadMesh.new()
    surface.mesh.size = Vector2.ONE * radius * 2.5
    surface.material_override = material; view.add_child(surface)
    var carrier := Node3D.new(); view.add_child(carrier)
    carrier.scale = Vector3.ONE * scale if mode != "control" else Vector3.ONE
    var light := OmniLight3D.new(); carrier.add_child(light)
    light.position.z = raw_range * .25 if mode != "control" else radius * .25
    light.omni_range = raw_range if mode != "control" else radius
    light.omni_attenuation = 0.0
    light.light_energy = 2.0; light.light_color = Color(.31, .4365, 1)
    light.shadow_enabled = false
    if mode == "converted":
        Units.apply({light.get_instance_id():Units.prepare(light)}, scale)
    return {"view":view, "light":light, "camera":camera, "radius":radius, "mode":mode}

func _pixel(image: Image, camera: Camera3D, point: Vector3) -> Color:
    var pixel := Vector2i(camera.unproject_position(point).floor())
    return image.get_pixelv(pixel)

func _rendered(material: StandardMaterial3D, raw_range: float) -> void:
    for scale in [.085, 2.0 / 3.0]:
        var actual := _world(material, raw_range, scale, "converted")
        var control := _world(material, raw_range, scale, "control")
        var old := _world(material, raw_range, scale, "unconverted")
        await process_frame; await RenderingServer.frame_post_draw
        await process_frame; await RenderingServer.frame_post_draw
        var a: Image = actual.view.get_texture().get_image()
        var c: Image = control.view.get_texture().get_image()
        var o: Image = old.view.get_texture().get_image()
        var radius: float = actual.radius
        var inner := _pixel(a, actual.camera, Vector3(radius * .3, 0, 0))
        var outside := _pixel(a, actual.camera, Vector3(radius * 1.1, 0, 0))
        var previous := _pixel(o, old.camera, Vector3(radius * 1.1, 0, 0))
        var max_error := 0; var old_changed := 0
        for y in a.get_height():
            for x in a.get_width():
                var av := a.get_pixel(x, y); var cv := c.get_pixel(x, y)
                max_error = maxi(max_error, maxi(maxi(absi(av.r8-cv.r8), absi(av.g8-cv.g8)), absi(av.b8-cv.b8)))
                if av != o.get_pixel(x, y): old_changed += 1
        check(max_error <= 1, "Scale%.3f: converted native light matches explicit native world-range control within one RGB8 quantization byte" % scale)
        check(inner.b > .05, "Scale%.3f: selected lit donor material is visibly illuminated inside range" % scale)
        check(outside.r8 == 0 and outside.g8 == 0 and outside.b8 == 0, "Scale%.3f: native surface is unlit outside converted radius" % scale)
        check(previous.b > .05 and old_changed > 100, "Scale%.3f: unconverted parent-scaled Omni reproduces overwide native illumination" % scale)
        samples.append({"scale":scale, "raw_range":raw_range, "world_range":radius,
            "max_rgb8_error":max_error, "old_changed_pixels":old_changed,
            "inner":str(inner), "outside":str(outside), "unconverted_outside":str(previous)})
        a.save_png("res://.captures/sandbox-light-units/converted-%.3f.png" % scale)
        c.save_png("res://.captures/sandbox-light-units/control-%.3f.png" % scale)
        o.save_png("res://.captures/sandbox-light-units/unconverted-%.3f.png" % scale)
        for row in [actual, control, old]: row.view.queue_free()
        await process_frame

func run() -> void:
    await _parameters()
    var donor: Node3D = load(DONOR).instantiate()
    var material: StandardMaterial3D = donor.get_node("debirs_mini_FINAL").material_override.duplicate(true)
    var raw_range: float = donor.get_node("OmniLight3D").omni_range
    check(material.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED, "Selected original Chill debris material actually receives native lighting")
    donor.free()
    DirAccess.make_dir_recursive_absolute("res://.captures/sandbox-light-units")
    await _rendered(material, raw_range)
    var report := {"checks":checks, "failures":failures, "samples":samples,
        "renderer":RenderingServer.get_current_rendering_method(), "material_source":DONOR + " :: debirs_mini_FINAL.material_override",
        "scope":"Native range/size unit conversion and replay. Actual lit donor material versus native explicit world-range control; no full-source animation or attenuation parity claim."}
    FileAccess.open("res://generated/sandbox_light_units_checks.json", FileAccess.WRITE).store_string(JSON.stringify(report, "  "))
    print("SANDBOX_LIGHT_UNITS ", JSON.stringify({"checks":checks, "failures":failures}))
    quit(0 if failures.is_empty() else 1)
