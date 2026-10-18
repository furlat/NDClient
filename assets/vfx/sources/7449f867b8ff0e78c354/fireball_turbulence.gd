extends "res://assets/vfx/sources/40729bf8dd1a375ca66e/fireball_native_ignition.gd"
## Intentional Fireball material derivative. Source hierarchy and geometry remain.
const DetailMaterials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
const HEADER := """
uniform float fireball_detail_age = 0.0;
uniform float fireball_detail_flow_scale;
uniform float fireball_detail_fine_scale;
uniform float fireball_detail_flow_motion;
uniform float fireball_detail_fine_motion;
uniform float fireball_detail_fine_weight;
uniform float fireball_detail_noise_low;
uniform float fireball_detail_noise_high;
uniform float fireball_detail_albedo_low;
uniform float fireball_detail_albedo_high;
uniform float fireball_detail_emission_low;
uniform float fireball_detail_emission_high;
uniform float fireball_detail_porosity_floor;
uniform float fireball_detail_peak_opacity;
uniform float fireball_detail_tail_opacity;
uniform float fireball_detail_thin_start_seconds;
uniform float fireball_detail_thin_end_seconds;
uniform float fireball_detail_clear_start_seconds;
uniform float fireball_detail_clear_end_seconds;
"""
const OPACITY := """
float fireball_detail_thin = smoothstep(fireball_detail_thin_start_seconds, fireball_detail_thin_end_seconds, fireball_detail_age);
float fireball_detail_clear = 1.0 - smoothstep(fireball_detail_clear_start_seconds, fireball_detail_clear_end_seconds, fireball_detail_age);
ALPHA *= mix(fireball_detail_peak_opacity, fireball_detail_tail_opacity, fireball_detail_thin) * fireball_detail_clear;
"""
const DETAIL := """
// Same source texture, on the source surface: no screen-space wash or new mesh.
vec2 fireball_detail_drift = fireball_detail_age * Displacement_Speed;
float fireball_detail_coarse = texture(Dissplacement_texture, UV * fireball_detail_flow_scale + fireball_detail_drift * fireball_detail_flow_motion).r;
float fireball_detail_fine = texture(Dissplacement_texture, UV * fireball_detail_fine_scale - fireball_detail_drift.yx * fireball_detail_fine_motion).r;
float fireball_detail_heat = smoothstep(fireball_detail_noise_low, fireball_detail_noise_high, mix(fireball_detail_coarse, fireball_detail_fine, fireball_detail_fine_weight));
ALBEDO *= mix(fireball_detail_albedo_low, fireball_detail_albedo_high, fireball_detail_heat);
EMISSION *= mix(fireball_detail_emission_low, fireball_detail_emission_high, smoothstep(0.20, 0.85, fireball_detail_heat));
ALPHA *= mix(fireball_detail_porosity_floor, 1.0, smoothstep(0.12, 0.75, fireball_detail_heat));
"""
var detail_materials: Array[ShaderMaterial] = []
var detail_layers: Array[String] = []
var material_profile: Dictionary = {}

static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/7449f867b8ff0e78c354/fireball_turbulence.gd", input)

func prepare_materials(node: Node) -> void:
	super.prepare_materials(node)
	var profile_path: String = parameters.get("detail_profile", "")
	assert(not profile_path.is_empty(), "Fireball detail requires explicit material-profile data")
	var decoded: Variant = JSON.parse_string(VfxPackageIO_7449f867b8.text(profile_path))
	assert(decoded is Dictionary, "Fireball detail profile must be a Dictionary")
	material_profile = decoded
	var seen: Dictionary = {}
	for layer_name: String in ["ball", "smoke", "smokeball3", "smokeball4", "smokeball5", "smokeball6"]:
		var draw: GeometryInstance3D = node.get_node(layer_name)
		if draw.layers == 0:
			continue
		assert(draw.material_override is ShaderMaterial, "Fireball detail requires original shader layer: " + layer_name)
		var material: ShaderMaterial = draw.material_override
		assert(not seen.has(material), "Each active Fireball detail layer requires isolated material state")
		seen[material] = true
		var role := "smoke" if layer_name == "smoke" else ("ignition" if layer_name == "ball" else "lobe")
		var values: Dictionary = material_profile[role]
		validate_values(values, role)
		var code: String = material.shader.code
		assert(not code.contains("fireball_detail_age"), "Fireball detail must be applied once")
		code = code.replace("shader_type spatial;", "shader_type spatial;\n" + HEADER)
		if role != "smoke":
			assert(code.contains("uniform sampler2D Dissplacement_texture") and code.contains("uniform vec2 Displacement_Speed"), "Fireball detail requires its actual source-noise bindings")
			code = DetailMaterials.finish_fragment(code, DETAIL + OPACITY)
		else:
			code = DetailMaterials.finish_fragment(code, OPACITY)
		var shader := Shader.new()
		shader.code = code
		DetailMaterials.replace_shader(material, shader)
		for field: String in values:
			if not field.begins_with("lighting_"):
				material.set_shader_parameter("fireball_detail_" + field, float(values[field]))
		if role != "smoke":
			# The original light equation and source normals stay; widen its authored transition.
			material.set_shader_parameter("Hard_Shadow_min", float(values.lighting_low))
			material.set_shader_parameter("Hard_Shadow_max", float(values.lighting_high))
			material.set_shader_parameter("Shadow_Min", float(values.lighting_floor))
		material.set_shader_parameter("fireball_detail_age", float(tick) / float(parameters.simulation_hz))
		detail_materials.append(material)
		detail_layers.append(layer_name)

func validate_values(values: Dictionary, role: String) -> void:
	for field: String in values:
		assert(typeof(values[field]) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(values[field])), "Finite Fireball material value required: " + field)
	for field: String in ["peak_opacity", "tail_opacity"]:
		assert(float(values[field]) >= 0.0 and float(values[field]) <= 1.0)
	assert(values.thin_start_seconds < values.thin_end_seconds)
	assert(values.clear_start_seconds < values.clear_end_seconds)
	if role != "smoke":
		assert(values.noise_low < values.noise_high)
		assert(values.lighting_low < values.lighting_high)
		assert(values.flow_scale > 0.0 and values.fine_scale > 0.0)
		assert(values.porosity_floor >= 0.0 and values.porosity_floor <= 1.0)

func advance_lifecycle(seconds: float) -> void:
	super.advance_lifecycle(seconds)
	for material: ShaderMaterial in detail_materials:
		material.set_shader_parameter("fireball_detail_age", float(tick) / float(parameters.simulation_hz))

func capture_observation() -> Dictionary:
	var result: Dictionary = super.capture_observation()
	result["intentional_fireball_material_variant"] = {
		"layers": detail_layers,
		"profile": parameters.get("detail_profile", ""),
		"source_age_seconds": float(tick) / float(parameters.simulation_hz),
		"noise": "same original bound Dissplacement_texture, two source-surface scales",
		"material_change": "broader original diffuse response, varied albedo/emission, porous finite alpha",
		"source_meshes_emitters_curves_transforms_retained": true,
		"new_lights": 0,
		"artwork_derivative": true
	}
	return result

const VfxPackageIO_7449f867b8 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
