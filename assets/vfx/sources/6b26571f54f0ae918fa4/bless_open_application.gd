extends Node3D
## Original Bless ground/particles plus measured, open Divine-material leaves.
## The quiet existing sustained body material is a separate unchanged phase.
const Original = preload("res://assets/vfx/sources/2f63b2ef0cb2d87dafc6/blessing.gd")
const ReceivingStrands = preload("res://assets/vfx/sources/4373fef56294eece4e7a/receiving_strands.gd")
const SourceMaterials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
const EnergyPalette = preload("res://assets/vfx/sources/386bc581a35eb3b9ee50/spatial_energy_palette.gd")
const NativeOpacity = preload("res://assets/vfx/sources/39f30ee3f172ac269cd6/native_opacity.gd")
var native_application: Node3D
var leaves: Node3D
var opacity_prepared := false


static func make_component(input: Dictionary) -> Node3D:
	var result: Node3D = VfxPackageIO_6b26571f54.resource("res://assets/vfx/sources/6b26571f54f0ae918fa4/bless_open_application.gd").new()
	result.native_application = Original.make_component(input.source_input)
	result.native_application.get_node("Donor/Mesh").hide()
	result.add_child(result.native_application)
	result.leaves = ReceivingStrands.make_component(input.flow_input)
	var shader := Shader.new()
	shader.code = result.leaves.material.shader.code.replace("blend_add", "blend_mix")
	shader.code = shader.code.replace("pow((1.0 - abs(uv.y * 2.0 - 1.0) - 0.5) / 0.5, 0.2)", "1.0")
	shader.code = shader.code.replace("value = smoothstep(0.5, 0.8, value);", "value = smoothstep(0.18, 0.72, value);")
	SourceMaterials.replace_shader(result.leaves.material, shader)
	EnergyPalette.apply(result.leaves.material, input.palette, {"quantize": false, "energy_exposure": 1.0})
	if input.get("gpu_paths",false):
		result.leaves=preload("res://assets/vfx/sources/b4406eb67f97fda9fcd6/receiving_flow.gd").from_native(result.leaves,input.flow_input)
	result.add_child(result.leaves)
	return result


func set_entity_geometry(value: Dictionary) -> void:
	leaves.set_entity_geometry(value)


func sample(seconds: float) -> void:
	native_application.sample(seconds)
	native_application.get_node("Donor/Mesh").hide()
	leaves.sample(seconds)
	if not opacity_prepared:
		NativeOpacity.apply(self)
		opacity_prepared = true


func capture_observation() -> Dictionary:
	return {"bless_application": {"source_ground_and_particles_retained": true,
		"source_cylinder_visible": native_application.get_node("Donor/Mesh").is_visible_in_tree(),
		"measured_divine_leaves": leaves.capture_observation(), "quiet_sustain_changed": false,
		"new_body_animation_or_light": false}}

const VfxPackageIO_6b26571f54 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
