extends RefCounted
## Low source-texture fill for the unlit side of the opaque living thorn shell.
## It emits no world light and retains the donor's bark, rim/noise and dissolve.
const Sources = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")


static func apply(material: ShaderMaterial, fill: float, continuous_withdrawal: bool = false, sink_depth: float = 0.0) -> void:
	var code: String = material.shader.code
	if not code.contains("VinesTexture"):
		return
	assert(fill >= 0.0 and fill <= .25)
	assert(code.contains("ALBEDO = final_color;"))
	if continuous_withdrawal:
		# Source alpha scissor would discard the entire shell as soon as its
		# global fade falls below .966. The existing geometric root withdrawal
		# already retires it continuously; keep the original dissolve coverage.
		assert(code.contains("ALPHA*=wall_fade;"))
		code = code.replace("ALPHA*=wall_fade;", "")
	if sink_depth > 0.0:
		assert(sink_depth <= .30 and continuous_withdrawal)
		assert(code.contains("wp.y*=1.0-retirement;"))
		code = code.replace("wp.y*=1.0-retirement;", "wp.y=wp.y*(1.0-retirement)-%s*smoothstep(.50,1.0,retirement);" % sink_depth)
	var shader := Shader.new()
	shader.code = code.replace("shader_type spatial;", "shader_type spatial;\nuniform float thorns_bark_fill=0.0;\n")
	shader.code = Sources.finish_fragment(shader.code, "\nEMISSION += base_color.rgb * thorns_bark_fill;\n")
	Sources.replace_shader(material, shader)
	material.set_shader_parameter("thorns_bark_fill", fill)
