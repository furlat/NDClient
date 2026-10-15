extends SceneTree
## Native AnimationPlayer -> sandbox light bridge -> actual atlas light nodes.
## Headless optical/lifecycle checks; these do not claim rendered pixel parity.
const SourceLights = preload("res://sandbox/source_lights.gd")
const FixedLights = preload("res://presentation/lighting_2d.gd")
const LightUnits = preload("res://sandbox/light_units.gd")
var checks := 0
var failures: Array = []
var evidence: Array = []

func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures.append(label)
        print("SANDBOX_SOURCE_LIGHT_FAIL ", label)

func _initialize() -> void:
    run.call_deferred()

func _track(animation: Animation, path: String, first: Variant, last: Variant, discrete: bool = false) -> void:
    var index := animation.add_track(Animation.TYPE_VALUE)
    animation.track_set_path(index, NodePath(path))
    animation.value_track_set_update_mode(index, Animation.UPDATE_DISCRETE if discrete else Animation.UPDATE_CONTINUOUS)
    animation.track_insert_key(index, 0.0, first)
    animation.track_insert_key(index, 1.0, last)

func _page() -> SubViewport:
    var page := SubViewport.new()
    page.size = Vector2i(800, 600)
    page.disable_3d = true
    root.add_child(page)
    return page

func _effect_nodes(page: SubViewport) -> Array:
    return page.get_children().filter(func(node): return node is PointLight2D and str(node.name).begins_with("EffectLight2D_"))

func run() -> void:
    var view := SubViewport.new()
    view.size = Vector2i(800, 600)
    root.add_child(view)
    var camera := Camera3D.new()
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.size = 10.0
    view.add_child(camera)
    var carrier := Node3D.new()
    view.add_child(carrier)
    var effect := Node3D.new()
    effect.name = "AuthoredEffect"
    effect.position = Vector3(1.0, 1.0, 0.0)
    effect.scale = Vector3.ONE * .18
    carrier.add_child(effect)
    var light := OmniLight3D.new()
    light.name = "Pulse"
    light.light_cull_mask = 0
    effect.add_child(light)
    var player := AnimationPlayer.new()
    player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
    effect.add_child(player)
    var animation := Animation.new()
    animation.length = 1.0
    _track(animation, "Pulse:light_energy", 0.0, 4.0)
    _track(animation, "Pulse:omni_range", 2.0, 6.0)
    _track(animation, "Pulse:position", Vector3(1, 2, 3), Vector3(3, 4, 1))
    _track(animation, "Pulse:light_color", Color(1, .2, .1), Color(.1, .5, 1))
    _track(animation, "Pulse:visible", true, false, true)
    var library := AnimationLibrary.new()
    library.add_animation("pulse", animation)
    player.add_animation_library("", library)
    player.play("pulse")
    player.seek(.5, true)
    var page := _page()
    var second_page := _page()
    var baseline_page := _page()
    var adapter = SourceLights.new()
    var baseline = FixedLights.new()
    adapter.light_strength = .43
    baseline.light_strength = .43
    adapter.attach(page)
    adapter.attach_page(second_page)
    baseline.attach(baseline_page)
    var state := {"senses":{"light_sources":{"fixture-lamp":{
        "anchor_entity_uuid":null, "anchor_item_uuid":null, "actor_anchored":false,
        "appearance":"torch", "position":[0, -1], "base_height_steps":1,
        "very_bright_radius_feet":0, "bright_radius_feet":25, "dim_radius_feet":10}}}}
    var original := state.duplicate(true)
    adapter.sync(state)
    baseline.sync(state)
    var handles := {"pulse":{"root":effect}}
    adapter.sample_handles(handles)
    check(adapter.issues.is_empty(), "Native Omni source resolves without an unsupported-source issue")
    check(adapter.effect_sources.size() == 1, "One authored source has one optical sample")
    var source: Dictionary = adapter.effect_sources[0]
    check(is_equal_approx(source.source_range, 4.0) and is_equal_approx(source.world_range, .72) and is_equal_approx(source.unit_scale, .18), "Root asset-unit conversion is applied once to animated range")
    check(is_equal_approx(light.omni_range, 4.0), "Source Omni property stays in authoring units")
    check(source.world_position.is_equal_approx(light.global_position), "Optical origin is the current transformed native position")
    check(is_equal_approx(source.energy, 2.0) and source.color.is_equal_approx(light.light_color), "Native animation supplies actual energy and color")
    check(adapter.sources.size() == 1 and state == original, "Effect sources neither alter fixed sources nor fabricate SDK light observations")
    var first_node: PointLight2D
    for quarter in 4:
        camera.position = Vector3(8, 8, 8).rotated(Vector3.UP, quarter * PI / 2.0)
        camera.look_at(Vector3.ZERO)
        adapter.project(camera)
        baseline.project(camera)
        var nodes := _effect_nodes(page)
        check(nodes.size() == 1 and _effect_nodes(second_page).size() == 1, "Quarter%d: each receiving page has one native2D source" % quarter)
        if nodes.size() != 1: continue
        var node: PointLight2D = nodes[0]
        if first_node == null: first_node = node
        check(node == first_node, "Quarter%d: camera rotation retains the light node" % quarter)
        var centre := camera.global_position - camera.global_basis.z * 10.0
        var ppu := camera.unproject_position(centre + camera.global_basis.x).distance_to(camera.unproject_position(centre))
        var expected_span := Vector2.ONE * 2.0 * .72 * ppu
        var projected: Dictionary = adapter.canvas_sources().filter(func(row): return row.id == source.id)[0]
        check(node.enabled and node.position.is_equal_approx(camera.unproject_position(light.global_position)), "Quarter%d: native optical source follows actual world position" % quarter)
        check(projected.span.is_equal_approx(expected_span) and projected.cookie_position.is_equal_approx(node.position), "Quarter%d: range and intensity centre follow the projected emitter" % quarter)
        check(node.offset == Vector2.ZERO and node.scale == Vector2.ONE, "Quarter%d: effect light has no displaced floor disc" % quarter)
        check(is_equal_approx(node.height, light.global_position.y * camera.global_basis.z.y * ppu), "Quarter%d: normal-light height derives from world elevation" % quarter)
        check(is_equal_approx(node.energy, .86) and node.color.is_equal_approx(light.light_color), "Quarter%d: global strength is applied exactly once without color changes" % quarter)
        var fixed: PointLight2D = adapter.nodes["fixture-lamp"]
        var expected: PointLight2D = baseline.nodes["fixture-lamp"]
        check(fixed.position == expected.position and fixed.color == expected.color and fixed.energy == expected.energy and fixed.height == expected.height and fixed.texture_scale == expected.texture_scale and fixed.offset == expected.offset and fixed.scale == expected.scale, "Quarter%d: ordinary fixture lighting is unchanged" % quarter)
        evidence.append({"quarter":quarter, "source_range":source.source_range, "unit_scale":source.unit_scale,
            "world_range":source.world_range, "native_energy":light.light_energy, "projected_energy":node.energy,
            "world_position":str(light.global_position), "height_pixels":node.height, "span":str(projected.span)})
    var effect_texture := first_node.texture as GradientTexture2D
    check(effect_texture != null and effect_texture.fill == GradientTexture2D.FILL_RADIAL, "Effect falloff uses Godot's native radial gradient texture")
    check(effect_texture == _effect_nodes(second_page)[0].texture, "Receiving pages share one effect cookie resource")
    var gradient: Gradient = effect_texture.gradient
    var monotone := true
    var previous := 1.0
    for index in 257:
        var colour := gradient.sample(float(index) / 256.0)
        monotone = monotone and colour.r >= 0.0 and colour.r <= previous and colour.r == colour.g and colour.g == colour.b
        previous = colour.r
    check(monotone and gradient.sample(0.0).r == 1.0 and gradient.sample(1.0).r == 0.0, "Neutral optical falloff decreases smoothly from full centre to zero edge")
    check(gradient.sample(.99).r < .001 and gradient.sample(.25).r > gradient.sample(.5).r and gradient.sample(.5).r > gradient.sample(.75).r, "Effect cookie has no bright/dim plateaus or hard outer band")
    var previous_attenuation := light.omni_attenuation
    var midpoint := gradient.sample(.5).r
    light.omni_attenuation = previous_attenuation + 2.0
    adapter.sample_handles(handles); adapter.project(camera)
    check(first_node.texture != effect_texture and first_node.texture.gradient.sample(.5).r < midpoint, "Animated donor attenuation selects the corresponding immutable optical falloff")
    check(gradient.sample(.5).r == midpoint, "An admitted cookie stays unchanged for other sources and shadow registration")
    light.omni_attenuation = previous_attenuation
    adapter.sample_handles(handles); adapter.project(camera)
    check(first_node.texture==effect_texture and is_equal_approx(first_node.texture.gradient.sample(.5).r, midpoint), "Restoring donor attenuation restores the exact prior optical falloff")
    var native_colour := light.light_color
    var authored_colour := Color("365be0")
    adapter.sample_handles(handles, 0.0, {"color":authored_colour})
    adapter.project(camera)
    check(first_node.color.is_equal_approx(authored_colour) and _effect_nodes(second_page)[0].color.is_equal_approx(authored_colour), "Authored spell hue reaches both receiving pages")
    check(light.light_color == native_colour and adapter.effect_sources[0].native_color == native_colour, "Optical hue preserves the native source and its provenance")
    check(is_equal_approx(first_node.energy, .86) and is_equal_approx(light.omni_range, 4.0), "Spell hue does not alter the animated energy or range")
    adapter.sample_handles(handles)
    adapter.project(camera)
    check(first_node.color == native_colour, "Removing the optical override immediately restores donor colour")
    player.seek(0.0, true)
    adapter.sample_handles(handles)
    adapter.project(camera)
    check(not first_node.enabled and is_zero_approx(first_node.energy), "Authored zero energy remains zero; no minimum brightness")
    player.seek(.5, true)
    adapter.sample_handles(handles)
    adapter.project(camera)
    check(first_node.enabled and is_equal_approx(first_node.energy, .86), "Seeking into the source pulse restores its exact animated energy")
    effect.hide()
    adapter.sample_handles(handles)
    adapter.project(camera)
    check(not first_node.enabled, "Hidden cue ancestor disables its light")
    effect.show()
    player.seek(1.0, true)
    adapter.sample_handles(handles)
    adapter.project(camera)
    check(not first_node.enabled and not light.visible, "Authored light visibility is respected at source lifetime end")
    player.seek(.5, true)
    # Discrete native visibility remains owned by the source after its end key;
    # explicitly start the next visible cue before testing page independence.
    light.show()
    carrier.scale = Vector3.ONE * 2.0
    adapter.sample_handles(handles)
    adapter.sample_handles(handles)
    adapter.project(camera)
    source = adapter.effect_sources[0]
    check(is_equal_approx(source.world_range, 1.44) and is_equal_approx(source.unit_scale, .36) and is_equal_approx(light.omni_range, 4.0), "Parent conversion updates once without accumulating across samples")
    adapter.light_strength = 0.0
    adapter.project(camera)
    check(not first_node.enabled and is_zero_approx(first_node.energy), "Existing global strength disables effect receiving lights too")
    adapter.light_strength = .43
    adapter.project(camera)
    adapter.detach_page(page)
    check(not first_node.enabled and first_node.is_queued_for_deletion(), "Detaching a page immediately disables and releases its effect source")
    check(_effect_nodes(second_page)[0].enabled, "Detaching one page leaves the other page's source active")
    adapter.sample_handles({})
    adapter.project(camera)
    check(adapter.canvas_sources().size() == 1 and not _effect_nodes(second_page)[0].enabled, "Removing the handle removes only its source and preserves the fixed lamp")
    check(adapter._effect_cookies.size()<=adapter.RETAINED_EFFECT_COOKIES, "Removed native handles retain only bounded immutable optical cookies")
    await process_frame
    check(_effect_nodes(second_page).is_empty(), "Removed effect lights do not remain in the atlas")
    var unsupported := Node3D.new()
    view.add_child(unsupported)
    unsupported.add_child(SpotLight3D.new())
    unsupported.add_child(DirectionalLight3D.new())
    adapter.sample_handles({"unsupported":{"root":unsupported}})
    adapter.project(camera)
    check(adapter.effect_sources.is_empty() and adapter.issues.size() == 2, "Unsupported Spot/Directional sources report explicit gaps and emit no invented light")
    adapter.sample_handles(handles)
    adapter.project(camera)
    check(adapter.issues.is_empty() and _effect_nodes(second_page).size() == 1, "Replacing the effect removes prior unsupported-source issues")
    var restored: PointLight2D = _effect_nodes(second_page)[0]
    var units:Dictionary={light.get_instance_id():LightUnits.prepare(light)}
    LightUnits.apply(units,.36)
    handles.pulse.light_units=units
    adapter.sample_handles(handles)
    adapter.project(camera)
    source=adapter.effect_sources[0]
    check(is_equal_approx(light.omni_range,1.44) and is_equal_approx(source.source_range,4.0) and is_equal_approx(source.world_range,1.44), "Converted native range and optical range agree without double scaling")
    adapter.clear_pages()
    check(not restored.enabled and restored.is_queued_for_deletion(), "Final atlas cleanup releases source lights")
    check(adapter._effect_cookies.is_empty(), "Final atlas cleanup releases retained immutable cookies")
    baseline.clear_pages()
    view.queue_free()
    page.queue_free()
    second_page.queue_free()
    baseline_page.queue_free()
    await process_frame
    var report := {"checks":checks, "failures":failures, "projection":evidence,
        "qualification":"Headless native source/atlas parameters and lifetime; not final rendered appearance or native3D attenuation parity"}
    FileAccess.open("res://generated/sandbox_source_light_checks.json", FileAccess.WRITE).store_string(JSON.stringify(report, "  "))
    print("SANDBOX_SOURCE_LIGHT_CHECKS ", checks, " failures=", failures.size())
    quit(0 if failures.is_empty() else 1)
