extends "res://assets/vfx/sources/109eaa5c7a6e4977719e/chill_hand_contact.gd"
## Third isolated corrective: the native wind fan remains the same moving
## mesh/sheet; only its final optical alpha is bounded independently of frames.
var wind_material: ShaderMaterial
var native_wind_shader: String

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = construct("res://assets/vfx/sources/ff81230ba1bf34b128a8/chill_hand_layers.gd", input)
	var light: OmniLight3D = instance.subject.get_node("OmniLight3D")
	assert(is_zero_approx(light.light_energy), "Initial-zero Chill light contract changed")
	light.free()
	return instance

func apply_scene_edits(node: Node) -> void:
	super.apply_scene_edits(node)
	wind_material = node.get_node("windimpact_A").material_override
	native_wind_shader = NativeSources.expand_shader(wind_material.shader.code, wind_material.shader.resource_path.get_base_dir())
	assert(native_wind_shader.contains("floor(COLOR.a * last_cell)"), "Native wind frame selector changed")
	assert(native_wind_shader.contains("ALPHA = tex.a;"), "Native wind alpha source changed")
	var opacity := float(parameters.wind_opacity)
	assert(opacity > 0.0 and opacity <= .3)
	# COLOR.a is this source's frame index, not a lifetime opacity. Do not alter
	# the emitter alpha/curve, multiply it into ALPHA, or replace the sheet mask.
	var code := native_wind_shader.replace("shader_type spatial;", "shader_type spatial;\nuniform float chill_wind_opacity = 1.0;")
	var shader := Shader.new()
	shader.code = NativeSources.finish_fragment(code, "\nALPHA *= chill_wind_opacity;\n")
	NativeSources.replace_shader(wind_material, shader)
	wind_material.set_shader_parameter("chill_wind_opacity", opacity)

func capture_observation() -> Dictionary:
	var row := super.capture_observation()
	row.chill_wind_support = {"final_alpha_multiplier":wind_material.get_shader_parameter("chill_wind_opacity"),"native_frame_selector":"floor(COLOR.a * last_cell)","native_sheet":wind_material.get_shader_parameter("sprite_sheet").resource_path,"native_mesh":subject.get_node("windimpact_A").draw_pass_1.resource_path,"native_blend_depth_normal_priority_retained":true,"native_process_and_sheet_clock_retained":true,"other_layers_unchanged":true,"optical_lights":0}
	return row
