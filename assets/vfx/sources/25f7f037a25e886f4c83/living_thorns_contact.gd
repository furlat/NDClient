extends Node3D
## The original living wall geometry, with source-space occupancy from real actors.
const Modules = preload("res://assets/vfx/sources/468b795cf354d2e2fba0/thorns_modules.gd")
const DonorScene = preload("res://assets/vfx/sources/7fb2e55699a318c2dafb/donor_scene.gd")
const ResourceGraph = preload("res://assets/vfx/sources/1d02b6d800655ef86df2/resource_graph.gd")

var wall: Node3D
var settings: Dictionary = {}
var contacts: Array = []
var source_transform_known := false
var last_source_transform: Transform3D

static func make_component(input: Dictionary) -> Node3D:
	var component: Node3D = VfxPackageIO_25f7f037a2.resource("res://assets/vfx/sources/25f7f037a25e886f4c83/living_thorns_contact.gd").new()
	component.settings = input.duplicate(true)
	var scene: PackedScene = VfxPackageIO_25f7f037a2.resource(input.scene)
	if scene == null:
		component.free()
		return null
	var source: Node3D = DonorScene.instantiate(scene, [])
	source.name = "Donor"
	ResourceGraph.isolate_node(source, {})
	component.add_child(source)
	component.wall = Modules.new()
	component.add_child(component.wall)
	component.wall.module_count = int(input.get("module_count", 3))
	component.wall.circular = bool(input.get("circular", false))
	component.wall.heading = float(input.get("heading", 0.0))
	return component

func _ready() -> void:
	# Original wall setup reads global transforms. Run it after tree insertion,
	# before the native sampler collects this occurrence's geometry and players.
	wall.build(get_node("Donor"))
	wall.start()
	# The original geometry evaluates deformation in the recorder's world space.
	# Change both directions of that mapping together, so a translated/scaled wall
	# stays stationary and its local actor contacts do not deform the wrong side.
	for material in wall.mats:
		var code: String = material.shader.code
		code = code.replace("shader_type spatial;", "shader_type spatial;\nuniform mat4 thorns_world_to_source=mat4(1.0);\nuniform mat4 thorns_source_to_world=mat4(1.0);")
		code = code.replace("vec3 wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;",
			"vec3 wp=(thorns_world_to_source*MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;")
		code = code.replace("VERTEX=(inverse(MODEL_MATRIX)*vec4(wp,1.0)).xyz;",
			"VERTEX=(inverse(MODEL_MATRIX)*thorns_source_to_world*vec4(wp,1.0)).xyz;")
		var shader := Shader.new()
		shader.code = code
		material.shader = shader

	if settings.has("bark_ambient_fill"):
		for material in wall.mats:
			preload("res://assets/vfx/sources/881d1ab33a1c2b51ff85/thorn_bark_readability.gd").apply(material, float(settings.bark_ambient_fill), bool(settings.get("continuous_withdrawal", false)), float(settings.get("withdrawal_sink_source_units", 0.0)))

func set_review_contacts(values: Array) -> void:
	contacts = values

func sample(seconds: float) -> void:
	var occupants: Array[Vector4] = []
	var pulse: float = exp(-pow((seconds - float(settings.get("damage_seconds", 2.5))) / 0.22, 2.0))
	for contact in contacts:
		var local: Vector3 = global_transform.affine_inverse() * contact.ground
		occupants.append(Vector4(local.x, local.z, 1.0, pulse))
	var seconds_total: float = float(settings.get("seconds", 5.6))
	wall.set_visual_state(seconds, occupants, smoothstep(seconds_total - .6, seconds_total, seconds))
	if not source_transform_known or last_source_transform != global_transform:
		last_source_transform = global_transform
		source_transform_known = true
		var world_to_source := global_transform.affine_inverse()
		for material in wall.mats:
			material.set_shader_parameter("thorns_world_to_source", world_to_source)
			material.set_shader_parameter("thorns_source_to_world", global_transform)

const VfxPackageIO_25f7f037a2 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
