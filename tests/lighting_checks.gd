extends SceneTree
# Synthetic player-state boundary values exercise disclosure/units without
# asserting private implementation details or claiming native gameplay coverage.
const Lighting = preload("res://presentation/lighting.gd")
const Placement = preload("res://placement.gd")
var checks := 0
var failures: Array = []

func check(condition: bool, message: String) -> void:
    checks += 1
    if not condition: failures.append(message)

func item(id: String, lit: bool = true) -> Dictionary:
    return {"item_uuid":id,"is_lit":lit,"very_bright_radius_feet":7,"bright_radius_feet":17,"dim_radius_feet":23}

func state() -> Dictionary:
    return {"audience":{"controlled":["owner"]},"tiles":{"2,3":{"elevation_steps":2}},
        "senses":{"objects":{"fixed":{"visual":true}},"entities":{"witness":{"visual":true}}},
        "objects":{"fixed":{"item":item("fixed"),"placement":{"position":[4,5],"base_height_steps":3}}},
        "actors":{"owner":{"uuid":"owner","last_visual_position":[2,3],"present":true,
            "controlled_items":[item("carried")],"visual_loadout":{"layers":[item("carried")]}},
        "witness":{"uuid":"witness","last_visual_position":[2,3],"present":true,
            "controlled_items":null,"visual_loadout":{"layers":[item("equipped")]}}}}

func _initialize() -> void:
    run.call_deferred()

func run() -> void:
    var started := Time.get_ticks_msec()
    var value := state()
    var original := value.duplicate(true)
    var result := Lighting.resolve(value)
    check(result.sources.size() == 3 and result.issues.is_empty(), "Fixed, controlled-carried and disclosed equipped sources resolve")
    check(value == original, "Resolution does not mutate canonical displayed state")
    var by_id := {}
    for source in result.sources: by_id[source.item_uuid] = source
    check(by_id.fixed.position == Vector3(4,4*Placement.HEIGHT_UNIT,5), "Placement elevation plus documented optical lift")
    check(by_id.carried.position == Vector3(2,4.5*Placement.HEIGHT_UNIT,3), "Actor uses disclosed support plus above-avatar carried optical elevation")
    check(by_id.fixed.very == 1.4 and by_id.fixed.bright == 3.0 and by_id.fixed.outer == 8.0, "Backend fractional very and floored bright-plus-dim units")
    check(by_id.fixed.bright_radius_feet == 17 and by_id.fixed.dim_radius_feet == 23, "Exact native feet retained")
    value.objects.fixed.item.is_lit = false
    check(Lighting.resolve(value).sources.size() == 2, "Extinguished fixed source stops illuminating")
    value.actors.witness.visual_loadout.layers[0].is_lit = false
    check(Lighting.resolve(value).sources.size() == 1, "Disclosed equipment activation is observed")
    value.actors.owner.controlled_items[0].is_lit = false
    check(Lighting.resolve(value).sources.is_empty(), "Controlled after-value wins over stale duplicate loadout")
    value = state(); value.senses.objects.erase("fixed")
    check(Lighting.resolve(value).sources.size() == 2, "Remembered object without current visual contact is not a light")
    value = state(); value.senses.objects.fixed.visual = false
    check(Lighting.resolve(value).sources.size() == 2, "Nonvisual object contact does not invent an optical source")
    value = state(); value.senses.entities.witness.visual = false
    check(Lighting.resolve(value).sources.size() == 2, "Hidden carrier does not illuminate from remembered position")
    value = state(); value.actors.owner.present = false
    check(Lighting.resolve(value).sources.size() == 2, "Departed carrier has no emitter")
    value = state(); value.actors.owner.last_visual_position = null
    check(Lighting.resolve(value).sources.size() == 2, "Unknown carrier position has no emitter")
    value = state(); value.objects.fixed.item.erase("bright_radius_feet")
    result = Lighting.resolve(value)
    check(result.sources.size() == 2 and result.issues.size() == 1, "Historical source without radius is reported, never inferred")
    value = state(); value.actors.witness.controlled_items = [item("private")]
    result = Lighting.resolve(value)
    check(result.sources.all(func(source):return source.item_uuid != "private"), "Noncontrolled inventory is ignored even if supplied")
    value = state(); value.objects.fixed.item.very_bright_radius_feet = 0
    value.objects.fixed.item.bright_radius_feet = 0; value.objects.fixed.item.dim_radius_feet = 0
    result = Lighting.resolve(value)
    var fixed: Dictionary = result.sources.filter(func(source):return source.item_uuid == "fixed")[0]
    check(fixed.very == 0 and fixed.bright == 1 and fixed.outer == 1, "Backend minimum one-cell bright/outer honored")
    var lighting := Lighting.new()
    var stage := Node3D.new(); root.add_child(stage); lighting.attach(stage)
    var material := ShaderMaterial.new(); material.shader = load("res://modular.gdshader")
    lighting.apply(material); lighting.sync(state())
    check(material.get_shader_parameter("authored_base_light") == 0.0, "Live material has no constant self-illumination")
    check(lighting.nodes.size()==3,"Exactly one native point light per disclosed emitter")
    var held: OmniLight3D = lighting.nodes.carried
    lighting.sample({"owner":{"position":[2.25,3.5],"base_height_steps":2.5,"visual_height":0.25}})
    check(held.position.is_equal_approx(Vector3(2.25,5.25*Placement.HEIGHT_UNIT,3.5)),"Native carried point follows displayed interpolation/support/jump")
    check(is_equal_approx(held.omni_range,8.0) and not held.shadow_enabled,"Canonical outer range feeds native optical sphere without invented shadows")
    lighting.sync(state())
    check(held==lighting.nodes.carried,"State revisions retain native light identity")
    lighting.sample({}, {"carried":0.5})
    check(is_equal_approx(held.light_energy,Lighting.OPTICAL_ENERGY*0.5),"Authored flame sample feeds native energy once")
    lighting.sync({})
    check(lighting.nodes.is_empty(),"Zero disclosed sources retires every native emitter")
    stage.queue_free()
    var lamps := Lighting.directionals({})
    check(lamps.nodes.is_empty(), "Missing directional authoring adds no general illumination")
    lamps = Lighting.directionals({"directionalSources":[{"id":"key","directionToSource":[2,3,-4],"colorLinear":[0.25,0.5,0.75],"intensity":1.7}]})
    check(lamps.nodes.size() == 1 and lamps.issues.is_empty(), "Authored directional source creates native light")
    var lamp: DirectionalLight3D = lamps.nodes[0]
    check(lamp.basis.z.is_equal_approx(Vector3(2,3,-4).normalized()), "Native emission direction preserves fixed world-space authoring")
    check(lamp.light_color.srgb_to_linear().is_equal_approx(Color(0.25,0.5,0.75)), "Authored linear colour converted to native sRGB property")
    check(is_equal_approx(lamp.light_energy,1.7) and not lamp.shadow_enabled, "Authored directional energy, no invented sprite wall shadows")
    lamp.free()
    lamps = Lighting.directionals({"directionalSources":[{"id":"invalid","directionToSource":[0,0,0],"colorLinear":[1,1,1],"intensity":1}]})
    check(lamps.nodes.is_empty() and lamps.issues.size() == 1, "Invalid zero direction reports an authoring issue")
    var summary := {"checks":checks,"failures":failures,"elapsed_ms":Time.get_ticks_msec()-started}
    print("LIGHTING_CHECKS ",JSON.stringify(summary))
    quit(0 if failures.is_empty() else 1)
