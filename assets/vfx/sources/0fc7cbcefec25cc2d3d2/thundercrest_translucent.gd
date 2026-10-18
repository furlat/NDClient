extends "res://assets/vfx/sources/c2a0955ce2641438f0d0/approved_aoe_whole.gd"
## Same ThunderCrest GLB, echo, UV/noise/mask, palette and blend-shape clock.
## The original .64/.30 opacity floors made the moving crest a solid barrier.
const PressureBindings = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/0fc7cbcefec25cc2d3d2/thundercrest_translucent.gd", input)


func clipped_material(old: Material, cell: Vector2, facing: String) -> ShaderMaterial:
	var material: ShaderMaterial = super.clipped_material(old, cell, facing)
	var code: String = material.shader.code
	if not code.contains("uniform bool echo_layer=false;"):
		return material
	var original_alpha := "ALPHA=(echo_layer?0.30+0.35*pulse:0.64+hot*0.34)*mix(0.7,1.0,smoothstep(0.04,0.28,mask))*breakup*rise*fade;"
	assert(code.count(original_alpha) == 1, "ThunderCrest pressure source changed")
	code = code.replace("shader_type spatial;", """shader_type spatial;
uniform float pressure_crest_gain=0.52;
uniform float pressure_echo_gain=0.12;
uniform float pressure_mask_floor=0.04;
uniform float pressure_mask_full=0.28;
""")
	code = code.replace(original_alpha, """
 float pressure_coverage=clamp(pow(rim,1.8)*0.70+pow(clamp(hot,0.0,1.0),2.5)*0.20+pulse*0.65,0.0,1.0);
 ALPHA=(echo_layer?pressure_echo_gain:pressure_crest_gain)*pressure_coverage*smoothstep(pressure_mask_floor,pressure_mask_full,mask)*breakup*rise*fade;
""")
	var derivative := Shader.new()
	derivative.code = code
	PressureBindings.replace_shader(material, derivative)
	var finish: Dictionary = parameters.pressure_finish
	for key: String in ["crest_gain", "echo_gain", "mask_floor", "mask_full"]:
		material.set_shader_parameter("pressure_" + key, float(finish[key]))
	return material
