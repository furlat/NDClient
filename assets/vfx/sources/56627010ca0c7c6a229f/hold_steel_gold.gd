extends "res://assets/vfx/sources/628326bc47127477d83b/hold.gd"
## Source Blender link meshes/physics, four anchors and timing remain exact.
## Decode the approved steel/gold colours once at the material boundary.


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/56627010ca0c7c6a229f/hold_steel_gold.gd", input)


func material(gold: bool = false, role: int = 0) -> ShaderMaterial:
	var result: ShaderMaterial = super.material(gold, role)
	var code: String = result.shader.code
	code = code.replace("shader_type spatial;", "shader_type spatial;\nuniform vec4 steel_shadow:source_color;\nuniform vec4 steel_highlight:source_color;\nuniform vec4 gold_shadow:source_color;\nuniform vec4 gold_highlight:source_color;\n")
	code = code.replace("vec3(.06,.075,.09)", "steel_shadow.rgb")
	code = code.replace("vec3(.65,.70,.73)", "steel_highlight.rgb")
	code = code.replace("vec3(1.,.68,.18)", "gold_highlight.rgb")
	code = code.replace("vec3(.55,.28,.06)", "gold_shadow.rgb")
	code = code.replace("vec3(1.,.78,.32)", "gold_highlight.rgb")
	code = code.replace("vec3(1.,.84,.43)", "gold_highlight.rgb")
	code = SourceMaterials.finish_fragment(code, "\nEMISSION = gold ? ALBEDO * 0.25 : vec3(0.0);\n")
	var shader := Shader.new()
	shader.code = code
	SourceMaterials.replace_shader(result, shader)
	for name in ["steel_shadow", "steel_highlight", "gold_shadow", "gold_highlight"]:
		result.set_shader_parameter(name, Color(parameters[name]))
	return result
