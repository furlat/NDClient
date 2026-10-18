extends Node3D
## Four real item identities at creation; one exact item at consumption. This
## geometry never implements inventory, charges, healing or rest retirement.
const SourceMaterials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")

var specification: Dictionary = {}
var endpoints: Array = []
var berries: Array[Node3D] = []
var petals: Array[MeshInstance3D] = []
var berry_material: ShaderMaterial
var leaf_material: ShaderMaterial
var current_seconds := 0.0

static func make_component(input: Dictionary) -> Node3D:
	assert(input.item_uuids.size() == (4 if input.mode == "creation" else 1))
	var identities := {}
	for identity in input.item_uuids:
		assert(not str(identity).is_empty() and not identities.has(identity), "Goodberry needs distinct real item owners")
		identities[identity] = true
	var effect: Node3D = VfxPackageIO_bf6d447d05.resource("res://assets/vfx/sources/bf6d447d0525f84fb79e/goodberry.gd").new()
	effect.specification = input.duplicate(true)
	effect.prepare()
	return effect

func set_live_endpoints(value: Array) -> void:
	endpoints = value

func prepare() -> void:
	berry_material = ShaderMaterial.new()
	berry_material.shader = VfxPackageIO_bf6d447d05.resource("res://assets/vfx/sources/c711c17fb576188e5b06/goodberry_material.gdshader")
	berry_material.set_shader_parameter("native_noise", VfxPackageIO_bf6d447d05.resource(specification.native_noise))
	berry_material.set_shader_parameter("berry_shadow", Color(specification.berry_colours[0]))
	berry_material.set_shader_parameter("berry_skin", Color(specification.berry_colours[1]))
	berry_material.set_shader_parameter("berry_crest", Color(specification.berry_colours[2]))
	leaf_material = ShaderMaterial.new()
	leaf_material.shader = VfxPackageIO_bf6d447d05.resource("res://assets/vfx/sources/ac1917ecfe3704ca9e13/goodberry_leaf.gdshader")
	leaf_material.set_shader_parameter("native_leaf", VfxPackageIO_bf6d447d05.resource(specification.native_leaf))
	leaf_material.set_shader_parameter("leaf_colour", Color(specification.leaf_colour))
	for identity in specification.item_uuids:
		var berry := Node3D.new()
		berry.name = "ActualItem_" + str(identity).validate_node_name()
		add_child(berry)
		var fruit := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = .036
		mesh.height = .064
		mesh.radial_segments = 12
		mesh.rings = 6
		fruit.mesh = mesh
		fruit.material_override = berry_material
		fruit.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		berry.add_child(fruit)
		for side in [-1.0, 1.0]:
			var leaf := _leaf(.055, .028)
			leaf.position = Vector3(side * .015, .033, 0)
			leaf.rotation = Vector3(-.45, side * .65, side * -.65)
			berry.add_child(leaf)
		berries.append(berry)
	for index in 5:
		var leaf := _leaf(.055, .024)
		add_child(leaf)
		petals.append(leaf)

func _leaf(length_cells: float, width_cells: float) -> MeshInstance3D:
	var leaf := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = Vector2(width_cells, length_cells)
	leaf.mesh = mesh
	leaf.material_override = leaf_material
	leaf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return leaf

func sample(seconds: float) -> void:
	current_seconds = seconds
	if endpoints.size() < 2:
		for berry in berries:
			berry.hide()
		for leaf in petals:
			leaf.hide()
		return
	var inverse := global_transform.affine_inverse()
	var hand: Vector3 = inverse * endpoints[0].point
	var destination: Vector3 = inverse * endpoints[1].point
	var creation: bool = specification.mode == "creation"
	var envelope := smoothstep(0.0, .18, seconds) * (1.0 - smoothstep(.85, 1.15, seconds))
	if not creation:
		envelope = smoothstep(0.0, .10, seconds) * (1.0 - smoothstep(.42, .57, seconds))
	for index in berries.size():
		var offset := Vector3(float(index % 2) - .5, .0, float(index / 2) - .5) * .083 if creation else Vector3.ZERO
		berries[index].position = hand + offset + Vector3.UP * (.045 + .014 * sin(seconds * 4.0 + index))
		if not creation:
			berries[index].position = hand.lerp(destination, smoothstep(.10, .38, seconds))
		berries[index].rotation.y = seconds * .55 + index
		berries[index].visible = envelope > .001
	berry_material.set_shader_parameter("presence", envelope)
	berry_material.set_shader_parameter("local_clock_seconds", seconds)
	var heal_visible: bool = not creation and specification.healing_admitted
	var petal_envelope := envelope if creation else smoothstep(.40, .55, seconds) * (1.0 - smoothstep(.90, 1.20, seconds))
	leaf_material.set_shader_parameter("presence", maxf(envelope, petal_envelope))
	for index in petals.size():
		var angle := float(index) * 2.39996 + seconds * 1.7
		petals[index].visible = petal_envelope > .001 and (creation or heal_visible)
		var centre := hand if creation else destination - Vector3.UP * .12
		var radius := .10 if creation else .15 * petal_envelope
		petals[index].position = centre + Vector3(cos(angle) * radius, sin(angle) * .045 + seconds * .035, sin(angle) * radius)
		petals[index].rotation = Vector3(.25 * sin(angle), angle, .35 * cos(angle))
		petals[index].scale = Vector3.ONE * petal_envelope

func capture_observation() -> Dictionary:
	return {"mode": specification.mode, "exact_item_uuids": specification.item_uuids,
		"healing_admitted": specification.healing_admitted, "seconds": current_seconds,
		"inventory_or_charge_solver": false, "creates_light": false, "temporary_item_duration_solver": false}

const VfxPackageIO_bf6d447d05 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
