extends "res://assets/vfx/sources/51beb78aeb4520031c07/ice_wall_assembly_breakup.gd"
## The persistent breach uses the actual section's native breakup, rarefied
## source-noise mist and slow falling frost. No new grid debris or flash.
const Bindings = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")


static func make_component(input: Dictionary) -> Node3D:
	assert(input.settings.kind == "ice" and input.side == "full")
	assert(input.has("source_breakup") and input.has("fog_noise_resource"))
	return construct("res://assets/vfx/sources/2a0fda0e7f174924eafc/ice_wall_frost_air.gd", input)


func create_air() -> void:
	super.create_air()
	var material: ShaderMaterial = air_mats.back()
	var code: String = material.shader.code
	code = code.replace("smoothstep(0.0,.22,edge.x)*smoothstep(0.0,.20,edge.y)*smoothstep(0.0,.32,edge.z)",
		"smoothstep(0.0,.42,edge.x)*smoothstep(0.0,.35,edge.y)*smoothstep(0.0,.55,edge.z)")
	code = code.replace("float cloud=.62+.10*cos(sample_point.x*.85+sample_point.y*.40)+.08*cos(sample_point.z*.72-sample_point.y*.55);", """
		float horizontal=texture(cold_noise,sample_point.xz*.19+vec2(wall_clock*.018,0.0)).r;
		float vertical=texture(cold_noise,sample_point.xy*.23+vec2(.31,-wall_clock*.025)).r;
		float cloud=smoothstep(.12,.80,horizontal*.55+vertical*.45);
		cloud *= .55+.45*(1.0-smoothstep(.1,.95,(sample_point.y+half_extent.y)/(2.0*half_extent.y)));
	""")
	code = code.replace("ALBEDO=vec3(.49,.76,.87);", "ALBEDO=vec3(.20,.40,.56);")
	code = code.replace("exp(-density*.70)", "exp(-density*.45)")
	var shader := Shader.new()
	shader.code = code
	Bindings.replace_shader(material, shader)
	material.set_shader_parameter("cold_noise", VfxPackageIO_2a0fda0e7f.resource(parameters.fog_noise_resource))
	for flake_material in flake_mats:
		var flake_shader := Shader.new()
		flake_shader.code = flake_material.shader.code.replace(
			"ALPHA=opacity*soft;", "float spoke=exp(-pow(sin(atan(q.y,q.x)*3.0)*length(q)*5.0,2.0)); ALPHA=opacity*soft*(.3+.7*spoke);")
		Bindings.replace_shader(flake_material, flake_shader)


func capture_observation() -> Dictionary:
	var result: Dictionary = super.capture_observation()
	result.cold_air = {"source_noise": parameters.fog_noise_resource,
		"slow_advected_mist": true, "snow_cycle_seconds": 4.0, "flakes": frost_flakes.size(),
		"new_light_or_flash": false, "duration": "remaining parent concentration; finite recording is illustrative"}
	return result

const VfxPackageIO_2a0fda0e7f = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
