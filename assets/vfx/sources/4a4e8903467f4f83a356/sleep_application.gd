extends "res://assets/vfx/sources/048e2881b9068776f055/clocked_source.gd"
## Preserve the selected LeLu smoke masks and their source clock.
## Explicit presentation bounds keep this brief application inside its footprint.

var smoke_material: ShaderMaterial


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/4a4e8903467f4f83a356/sleep_application.gd", input)


func apply_scene_edits(node: Node) -> void:
	var smoke := node as GPUParticles3D
	smoke.local_coords = true
	smoke.amount = int(settings.particle_count)
	smoke.lifetime = float(settings.particle_lifetime_seconds)
	smoke.position.y = float(settings.emitter_height_units)
	var process := smoke.process_material as ParticleProcessMaterial
	process.emission_sphere_radius = float(settings.emission_radius_units)
	process.emission_shape_scale = Vector3(1.0, 0.08, 1.0)
	process.radial_velocity_min = float(settings.radial_velocity_units_per_second)
	process.radial_velocity_max = float(settings.radial_velocity_units_per_second)
	process.gravity = Vector3(0.0, 0.15, 0.0)
	process.scale_min = float(settings.card_scale_min_units)
	process.scale_max = float(settings.card_scale_max_units)
	smoke_material = smoke.material_override as ShaderMaterial
	var colour: Array = settings.colour
	smoke_material.set_shader_parameter("Color", Color(colour[0], colour[1], colour[2], 1.0))
	var shader := Shader.new()
	var code: String = smoke_material.shader.code
	code = code.replace("shader_type spatial;", "shader_type spatial;\nuniform mat4 sleep_world_to_source = mat4(1.0);\nuniform float sleep_opacity = 1.0;\nuniform float sleep_radius_units = 4.0;\n")
	var closing: int = code.rfind("}")
	var bounds := "\nvec3 sleep_local = (sleep_world_to_source * INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;\n"
	bounds += "float sleep_edge = 1.0 - smoothstep(sleep_radius_units * 0.78, sleep_radius_units, length(sleep_local.xz));\n"
	bounds += "float sleep_height = 1.0 - smoothstep(1.35, 1.75, sleep_local.y);\n"
	bounds += "ALPHA *= sleep_opacity * sleep_edge * sleep_height;\n"
	code = code.insert(closing, bounds)
	shader.code = code
	SourceMaterials.replace_shader(smoke_material, shader)
	smoke_material.set_shader_parameter("sleep_radius_units", float(settings.footprint_radius_units))
	smoke_material.set_shader_parameter("sleep_opacity", float(settings.opacity))
	# The selected puff has no native optical light; guard future donor changes.
	for light in node.find_children("*", "Light3D", true, false):
		light.light_energy = 0.0
		light.hide()


func update_geometry() -> void:
	if smoke_material != null:
		smoke_material.set_shader_parameter("sleep_world_to_source", global_transform.affine_inverse())


func capture_observation() -> Dictionary:
	var result: Dictionary = super.capture_observation()
	result.footprint_radius_units = float(settings.footprint_radius_units)
	result.optical_lights = find_children("*", "Light3D", true, false).size()
	result.source_alpha_control = "sleep_opacity"
	return result
