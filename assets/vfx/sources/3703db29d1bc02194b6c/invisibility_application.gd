extends "res://assets/vfx/sources/048e2881b9068776f055/clocked_source.gd"
## Complete native puff, used only for the shared invisibility condition family.
## Its colour and finite envelope frame the renderer-owned opacity transition.
const VeilPalette = preload("res://assets/vfx/sources/386bc581a35eb3b9ee50/spatial_energy_palette.gd")
var smoke_material: StandardMaterial3D
var smoke_color := Color.WHITE


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/3703db29d1bc02194b6c/invisibility_application.gd", input)


func apply_scene_edits(node: Node) -> void:
	node.scale = Vector3(float(parameters.source_scale[0]), float(parameters.source_scale[1]), float(parameters.source_scale[2]))
	node.position.y = float(parameters.height_cells)
	if node is GPUParticles3D:
		# The realistic donor is a complete one-shot root with a sixteen-frame
		# native particle billboard, not the stylized outlined cloud source.
		smoke_material = node.material_override
		smoke_color = smoke_material.albedo_color
		smoke_color.a *= float(parameters.get("source_opacity", 1.0))
		smoke_material.albedo_color = smoke_color
		node.process_material.color = Color(str(parameters.get("smoke_tint", parameters.native_palette[2])))
		node.emitting = true


func prepare_materials(node: Node) -> void:
	super.prepare_materials(node)
	for material in materials:
		VeilPalette.apply(material, parameters.native_palette, {"quantize": false, "emission_gain": 0.04})
		var shader := Shader.new()
		shader.code = NativeShaderBindings.finish_fragment(material.shader.code,
			"\nALPHA *= 0.7 * (1.0-smoothstep(0.55,0.95,source_clock));\n")
		NativeShaderBindings.replace_shader(material, shader)


func advance_lifecycle(delta: float) -> void:
	super.advance_lifecycle(delta)
	if smoke_material != null:
		var age: float = float(tick) / float(parameters.simulation_hz)
		var color: Color = smoke_color
		color.a *= 1.0 - smoothstep(0.55, 0.95, age)
		smoke_material.albedo_color = color


func capture_observation() -> Dictionary:
	var result: Dictionary = super.capture_observation()
	result.original_puff_layers_retained = true
	result.condition_family = "invisibility"
	result.changes_actor_opacity = false
	result.optical_lights_added = 0
	return result
