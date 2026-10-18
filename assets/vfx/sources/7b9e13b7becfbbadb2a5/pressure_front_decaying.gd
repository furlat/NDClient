extends "res://assets/vfx/sources/aa975fd703a6ecc50c50/pressure_front_translucent.gd"
## Same short pressure front; let the textured rim thin instead of tearing
## a narrow travelling hole through nearly the entire shell in one sample.


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/7b9e13b7becfbbadb2a5/pressure_front_decaying.gd", input)


func apply_scene_edits(node: Node) -> void:
	super.apply_scene_edits(node)
	var original := "float tear=1.0-smoothstep(1.8-tear_progress*3.8,2.05-tear_progress*3.8,tear_field);"
	var replacement := "float tear=(1.0-tear_progress)*mix(1.0,0.75+0.25*smoothstep(-1.62,1.62,tear_field),tear_progress);"
	var code: String = mat.shader.code
	assert(code.count(original) == 1, "Pressure retirement source changed")
	var shader := Shader.new()
	shader.code = code.replace(original, replacement)
	PressureBindings.replace_shader(mat, shader)
