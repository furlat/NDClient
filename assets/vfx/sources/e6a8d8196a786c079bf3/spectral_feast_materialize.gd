extends "res://assets/vfx/sources/cb6c8719a6b42c394aba/spectral_feast.gd"
## Same authored one-cell Feast geometry, ghost/flow material and source motion.
## Per-role spectral value separates tableware/food; a shared local birth front
## gathers actual surfaces instead of revealing the whole footprint at once.
const Values = preload("res://assets/vfx/sources/601eb8db9c55b6ad084e/shader_material.gd")
var role_parameters: Dictionary = {}
var cached_materials: Dictionary = {}
var source_parameters: Dictionary = {}


static func make_component(input: Dictionary) -> Node3D:
	var component: Node3D = VfxPackageIO_e6a8d8196a.resource("res://assets/vfx/sources/e6a8d8196a786c079bf3/spectral_feast_materialize.gd").new()
	component.material_shader = input.material_shader
	component.role_parameters = input.role_parameters.duplicate(true)
	component.source_parameters = input.duplicate(true)
	var document := VfxPackageDocument_e6a8d8196a.new()
	var state := GLTFState.new()
	if document.append_from_file(input.geometry,state) != OK:
		component.free()
		return null
	component.subject = document.generate_scene(state)
	component.add_child(component.subject)
	component.subject.scale = Vector3(.28,.81649658*.9,.50)
	component.apply_materials(component.subject)
	for index in 18:
		var shape := SphereMesh.new()
		shape.radius = .009 if index%3 else .014
		shape.height = shape.radius*2.0
		shape.radial_segments = 6
		shape.rings = 3
		var mote := MeshInstance3D.new()
		mote.mesh = shape
		mote.material_override = component.make_material("Flame")
		component.subject.add_child(mote)
		component.motes.append(mote)
	return component


func make_material(kind: String) -> ShaderMaterial:
	if cached_materials.has(kind):
		return cached_materials[kind]
	var material: ShaderMaterial = super.make_material(kind)
	for uniform in role_parameters.get(kind,{}):
		material.set_shader_parameter(uniform,Values.uniform_value(role_parameters[kind][uniform]))
	cached_materials[kind] = material
	return material


func sample(seconds: float) -> void:
	super.sample(seconds*float(source_parameters.motion_rate)+float(source_parameters.motion_offset_seconds))
	var inverse := Projection(global_transform.affine_inverse())
	for material in cached_materials.values():
		# Own this material's source clock alongside its birth/transform state.
		# An external shader_uniform binding would clone displayed materials
		# after construction and leave this per-role state pointing at old copies.
		material.set_shader_parameter("clock",seconds*float(source_parameters.motion_rate)+float(source_parameters.motion_offset_seconds))
		material.set_shader_parameter("feast_world_to_source",inverse)
		material.set_shader_parameter("feast_birth_seconds",seconds)


func capture_observation() -> Dictionary:
	return {"feast": {"source_geometry": source_parameters.geometry,
		"shared_per_role_materials": cached_materials.keys(), "original_motes":motes.size(),
		"original_motion_rate":source_parameters.motion_rate, "original_motion_offset_seconds":source_parameters.motion_offset_seconds,
		"birth": "one shared local radial gather on real surfaces; .02–.60seconds",
		"new_light_or_body_animation":false, "consumption_changed":false}}

const VfxPackageIO_e6a8d8196a = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")

const VfxPackageDocument_e6a8d8196a = preload("res://assets/vfx/sources/55f3fdb093ba9d7c2784/scene_document.gd")
