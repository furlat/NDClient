extends Node3D
## Complete native visible wall; exact source Animation interpolants replace
## repeated hidden donor scenes. Living/contact/withdrawal deformation stays GPU.
const CELL := 2.121320344
var bank: Resource
var settings: Dictionary = {}
var material: ShaderMaterial
var draws: Array[MeshInstance3D] = []
var decals: Array[Decal] = []
var module_transforms: Array[Transform3D] = []
var contacts: Array = []
var last_age := NAN
var last_contacts: Array = []
var last_transform := Transform3D.IDENTITY
var transform_known := false
var retirement := 0.0

static func preparation_resources(input: Dictionary) -> Array:
	return [str(input.thorns_bank)]

static func make_component(input: Dictionary) -> Node3D:
	var value: Resource = VfxPackageIO_33bb4a6842.resource(str(input.thorns_bank))
	assert(value != null and value.meshes.size() == 16, "Prepare actual native thorns bank offline")
	var actual := input.duplicate(true)
	actual.erase("thorns_bank")
	var expected: Dictionary = value.source_settings.duplicate(true)
	for key in ["module_count", "circular", "heading", "seconds", "damage_seconds"]:
		actual.erase(key); expected.erase(key)
	assert(actual == expected, "Native bark/source variant requires explicit offline preparation")
	var node: Node3D = VfxPackageIO_33bb4a6842.resource("res://assets/vfx/sources/33bb4a6842b90d94f371/wall.gd").new()
	node.bank = value
	node.settings = input.duplicate(true)
	node._build()
	return node

func _build() -> void:
	material = bank.material.duplicate(false)
	var count := int(settings.get("module_count", 3))
	assert(count > 0 and count <= bank.meshes.size(), "Prepared native source variants support1–16 modules")
	var circular := bool(settings.get("circular", false))
	material.set_shader_parameter("circular", circular)
	material.set_shader_parameter("wall_heading", float(settings.get("heading", 0.0)))
	material.set_shader_parameter("split_layers", false)
	material.set_shader_parameter("foreground", false)
	material.set_shader_parameter("camera_ground", Vector2(1, 1).normalized())
	material.set_shader_parameter("actor_ground", Vector2.ZERO)
	for index in count:
		var origin := Vector3((float(index) + .5 - (0.0 if circular else float(count)*.5))*CELL, .7538, 0.)
		var transform := Transform3D(Basis.from_scale(Vector3(.3539, .4362, 1.004)), origin)
		module_transforms.append(transform)
		var draw := MeshInstance3D.new()
		draw.name = "NativeThornModule%02d" % index
		draw.mesh = bank.meshes[index]
		draw.material_override = material
		draw.transform = transform * bank.mesh_transform
		add_child(draw)
		draw.custom_aabb = draw.transform.affine_inverse() * AABB(Vector3(-40, -.5, -40), Vector3(80, 6, 80))
		draws.append(draw)
		var decal := Decal.new()
		decal.name = "NativeThornGround%02d" % index
		for property in bank.decal_properties:
			decal.set(property, bank.decal_properties[property])
		decal.transform = transform * bank.decal_properties.transform
		# Exact original sampler's painted-scene receiver selection.
		decal.cull_mask = 1
		add_child(decal)
		decals.append(decal)

func set_review_contacts(value: Array) -> void:
	contacts = value

func _animation_value(name: String, seconds: float) -> Variant:
	return bank.animation.value_track_interpolate(bank.tracks[name], minf(maxf(seconds, 0.), bank.animation.length))

func sample(seconds: float) -> void:
	if not is_finite(seconds):
		return
	var moved := not transform_known or global_transform != last_transform
	if moved:
		transform_known = true
		last_transform = global_transform
		material.set_shader_parameter("thorns_world_to_source", global_transform.affine_inverse())
		material.set_shader_parameter("thorns_source_to_world", global_transform)
	if not moved and seconds == last_age and contacts == last_contacts:
		return
	var occupants := PackedVector4Array()
	var pulse := exp(-pow((seconds-float(settings.get("damage_seconds", 2.5)))/.22, 2.))
	for contact in contacts:
		var point: Vector3 = global_transform.affine_inverse()*contact.ground
		if occupants.size() < 16:
			occupants.append(Vector4(point.x, point.z, 1., pulse))
	material.set_shader_parameter("occupant_count", mini(contacts.size(), 16))
	if not occupants.is_empty():
		material.set_shader_parameter("occupants", occupants)
	var total := float(settings.get("seconds", 5.6))
	retirement = clampf(smoothstep(total-.6, total, seconds), 0., 1.)
	material.set_shader_parameter("wall_clock", fmod(seconds, 2.0))
	material.set_shader_parameter("wall_fade", 1.-smoothstep(.65, 1., retirement))
	material.set_shader_parameter("retirement", retirement)
	var scale_value: Vector3 = _animation_value("scale", seconds)
	var dissolve: float = _animation_value("dissolve", seconds)
	var modulate_value: Color = _animation_value("modulate", seconds)
	var mix_value: float = _animation_value("albedo_mix", seconds)
	var decal_visible: bool = _animation_value("visible", seconds)
	var mesh_transform: Transform3D = bank.mesh_transform
	mesh_transform.basis = Basis.from_scale(scale_value)
	for index in draws.size():
		draws[index].transform = module_transforms[index]*mesh_transform
		draws[index].set_instance_shader_parameter("DisolverSTEP", dissolve)
		decals[index].modulate = modulate_value
		decals[index].albedo_mix = mix_value
		decals[index].visible = decal_visible
	last_age = seconds
	last_contacts = contacts.duplicate(true)

func source_bindings() -> Dictionary:
	return {"geometry": draws, "materials": [material], "lights": [], "static_material_topology": true}

func capture_observation() -> Dictionary:
	return {"native_modules": draws.size(), "native_ground_decals": decals.size(), "private_materials": 1,
		"native_source_animation": bank.animation.resource_name, "source_age": last_age, "occupants": contacts.size(),
		"dormant_source_particles_not_constructed": draws.size()*3, "visible_source_layers_removed": false,
		"per_frame_mesh_generation": false, "runtime_shader_generation": false, "retirement": retirement}

const VfxPackageIO_33bb4a6842 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
