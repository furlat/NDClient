extends "res://assets/vfx/sources/e0294d7ff844457db011/native_ribbon_base.gd"
## Source-fragment GPU ribbon. Keep the old path name and authoring width API.
const SourceMaterials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
var source_material: ShaderMaterial
var source_start := Color.WHITE
var source_end := Color(1, 1, 1, 0)
var source_acceleration := 1.0
@export var fromWidth: float = .5:
	set(value):
		fromWidth = value
		if is_node_ready():
			_update_width_curve()
@export var toWidth: float = 0.0:
	set(value):
		toWidth = value
		if is_node_ready():
			_update_width_curve()


func _get_property_list() -> Array[Dictionary]:
	return [{"name": "_defaults_have_been_set", "type": TYPE_BOOL, "usage": PROPERTY_USAGE_NO_EDITOR}]


func _ready() -> void:
	super._ready()
	var draw_code: String = VfxPackageIO_09a18d9a81.text("res://assets/vfx/sources/d3ab83b12478f43faa1b/trail_draw_pass.gdshader")
	var fragment := draw_code.find("void fragment()")
	assert(fragment > 0)
	# Retain source fragment math and bindings. Only ribbon vertex construction
	# replaces the CPU ImmediateMesh, with the existing native GPU trail vertices.
	var original: String = SourceMaterials.expand_shader(source_material.shader.code, source_material.shader.resource_path.get_base_dir())
	original = _without_function(original, "vertex")
	var headers := RegEx.new()
	headers.compile("(?m)^\\s*(?:shader_type|render_mode)[^;]*;")
	original = headers.sub(original, "", true)
	var vertex_code := draw_code.substr(0, fragment)
	vertex_code = SourceMaterials.finish_function(vertex_code, "vertex", "\nCOLOR=textureLod(color_ramp,vec2(UV.x,0.0),0.0);\n")
	var shader := Shader.new()
	shader.code = vertex_code + "\n" + original
	SourceMaterials.replace_shader(source_material, shader)
	draw_pass_1.material = source_material
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([source_start, source_end])
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	color_ramp = ramp
	_update_width_curve()
	dewiggle = false
	clip_overlaps = false
	billboard = true
	scroll = Vector2.ZERO


func _update_width_curve() -> void:
	var profile := Curve.new()
	profile.max_value = maxf(1.0, maxf(fromWidth, toWidth))
	for step in 33:
		var age := float(step) / 32.0
		profile.add_point(Vector2(age, fromWidth - pow(age, source_acceleration) * (fromWidth - toWidth)))
	var texture := CurveTexture.new()
	texture.curve = profile
	curve = texture


func _without_function(code: String, name: String) -> String:
	var begin := code.find("void " + name + "()")
	if begin < 0:
		return code
	var cursor := code.find("{", begin) + 1
	var depth := 1
	while cursor < code.length() and depth > 0:
		if code[cursor] == "{":
			depth += 1
		elif code[cursor] == "}":
			depth -= 1
		cursor += 1
	assert(depth == 0)
	return code.substr(0, begin) + code.substr(cursor)

const VfxPackageIO_09a18d9a81 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
