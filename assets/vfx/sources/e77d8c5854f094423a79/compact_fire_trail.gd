extends "res://assets/vfx/sources/048e2881b9068776f055/clocked_source.gd"
## The original live head/sparks/trail, with a short cantrip history and a
## finite trail fade after its authored source contact.
const TrailBindings = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
var trail_material: ShaderMaterial


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/e77d8c5854f094423a79/compact_fire_trail.gd", input)


func apply_scene_edits(node: Node) -> void:
	var trail: GPUParticles3D = node.get_node("GPUTrail3D")
	trail.set("length_seconds", float(parameters.trail_seconds))
	trail_material = trail.draw_pass_1.surface_get_material(0).duplicate(true)
	assert(trail.draw_pass_1 is PrimitiveMesh, "Compact trail expects its original particle quad")
	trail.draw_pass_1.material = trail_material
	var code: String = trail_material.shader.code
	code = code.replace("shader_type spatial;", "shader_type spatial; uniform float compact_trail_age=0.0;\n")
	var tail := "\nALPHA *= 0.65 * (1.0-smoothstep(%s,%s,compact_trail_age));\n" % [float(parameters.contact_source_seconds), float(parameters.contact_source_seconds) + float(parameters.trail_seconds)]
	var shader := Shader.new()
	shader.code = TrailBindings.finish_fragment(code, tail)
	TrailBindings.replace_shader(trail_material, shader)
	var ramp: GradientTexture1D = trail.get("color_ramp").duplicate(true)
	ramp.gradient = ramp.gradient.duplicate(true)
	var colors: PackedColorArray = ramp.gradient.colors
	for index in colors.size():
		colors[index] = Color(colors[index].r * 0.35, colors[index].g * 0.35, colors[index].b * 0.35, colors[index].a)
	ramp.gradient.colors = colors
	trail.set("color_ramp", ramp)


func advance_lifecycle(delta: float) -> void:
	super.advance_lifecycle(delta)
	trail_material.set_shader_parameter("compact_trail_age", float(tick) / float(parameters.simulation_hz))
