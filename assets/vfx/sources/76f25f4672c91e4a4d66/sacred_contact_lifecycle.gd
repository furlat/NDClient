extends "res://assets/vfx/sources/e35da80babda34e8de49/sacred_beam.gd"
## The selected source flare formerly finished while hidden above the floor.
## Start that original particle at actual ground contact, then retire the shaft.
const ReceivingBindings = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
var column_materials: Array[ShaderMaterial] = []


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/76f25f4672c91e4a4d66/sacred_contact_lifecycle.gd", input)


func apply_scene_edits(node: Node) -> void:
	super.apply_scene_edits(node)
	for child in node.find_children("*", "GeometryInstance3D", true, false):
		if not (String(child.name).begins_with("inner_") or String(child.name).begins_with("outter_")):
			continue
		if not child.material_override is ShaderMaterial:
			continue
		var material: ShaderMaterial = child.material_override
		var shader := Shader.new()
		var code: String = material.shader.code
		code = code.replace("shader_type spatial;", "shader_type spatial; uniform float contact_column_alpha=1.0;")
		var end: int = code.rfind("}")
		assert(end >= 0)
		shader.code = code.insert(end, "\nALPHA *= contact_column_alpha;\n")
		ReceivingBindings.replace_shader(material, shader)
		column_materials.append(material)
	assert(not column_materials.is_empty(), "Sacred source has no column materials")
	var flare: GPUParticles3D = node.get_node("muzzle")
	flare.scale *= float(parameters.contact_flare_scale)


func advance_lifecycle(delta: float) -> void:
	super.advance_lifecycle(delta)
	var flare: GPUParticles3D = source.get_node("muzzle")
	if tick < 52:
		flare.emitting = false
	elif tick == 52:
		flare.restart()
		flare.emitting = true
	var age: float = float(tick) / float(parameters.simulation_hz)
	var opacity: float = 1.0 - smoothstep(float(parameters.column_fade_begin_seconds), float(parameters.column_fade_end_seconds), age)
	for material in column_materials:
		material.set_shader_parameter("contact_column_alpha", opacity)
