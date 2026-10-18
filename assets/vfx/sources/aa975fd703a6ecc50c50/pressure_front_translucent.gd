extends "res://assets/vfx/sources/f1203319eed2018b617b/pressure_front.gd"
## Keep the authored caps, compression layer, palette and .48s source decay.
## Remove broad interior fill that exposes polygon faces as opaque ribbons.
const PressureBindings = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/aa975fd703a6ecc50c50/pressure_front_translucent.gd", input)


func apply_scene_edits(node: Node) -> void:
	super.apply_scene_edits(node)
	var finish: Dictionary = parameters.pressure_finish
	var code: String = mat.shader.code
	var original_band := "smoothstep(0.035,0.48,edge)*(0.35+0.65*arcs)"
	var original_alpha := "ALPHA=min(0.85,band*0.82+streak*irregular*0.08+veil)*opacity*tear;"
	assert(code.count(original_band) == 1 and code.count(original_alpha) == 1, "Shatter pressure source changed")
	code = code.replace("shader_type spatial;", """shader_type spatial;
uniform float pressure_edge_start=0.28;
uniform float pressure_edge_end=0.92;
uniform float pressure_alpha_cap=0.32;
uniform float pressure_band_gain=0.28;
uniform float pressure_streak_gain=0.055;
""")
	code = code.replace(original_band, "smoothstep(pressure_edge_start,pressure_edge_end,edge)*(0.15+0.85*arcs)")
	code = code.replace(original_alpha, "ALPHA=min(pressure_alpha_cap,band*pressure_band_gain+streak*irregular*pressure_streak_gain)*opacity*tear;")
	var derivative := Shader.new()
	derivative.code = code
	PressureBindings.replace_shader(mat, derivative)
	for key: String in ["edge_start", "edge_end", "alpha_cap", "band_gain", "streak_gain"]:
		mat.set_shader_parameter("pressure_" + key, float(finish[key]))
	var accent_code: String = accent_mat.shader.code
	var original_accent := "ALPHA=soft*smoothstep(-0.3,0.65,irregular)*opacity;"
	assert(accent_code.count(original_accent) == 1, "Shatter compression source changed")
	accent_code = accent_code.replace("shader_type spatial;", "shader_type spatial;\nuniform float pressure_compression_gain=0.22;")
	accent_code = accent_code.replace(original_accent, "ALPHA=soft*smoothstep(-0.3,0.65,irregular)*opacity*pressure_compression_gain;")
	var compression := Shader.new()
	compression.code = accent_code
	PressureBindings.replace_shader(accent_mat, compression)
	accent_mat.set_shader_parameter("pressure_compression_gain", float(finish.compression_gain))
