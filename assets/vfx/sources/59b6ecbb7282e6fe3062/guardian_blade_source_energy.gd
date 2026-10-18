extends "res://assets/vfx/sources/ebda7395dfd1e0dab4eb/guardian_blade_response.gd"
## Controlled response-only derivative. Frozen V191 geometry stays inherited.
const OccurrenceOpacity = preload("res://assets/vfx/sources/39f30ee3f172ac269cd6/native_opacity.gd")
var source_energy_profile: Dictionary
var source_energy_material: ShaderMaterial


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = construct("res://assets/vfx/sources/59b6ecbb7282e6fe3062/guardian_blade_source_energy.gd", input)
	instance.name = "effect"
	return instance


func build() -> void:
	super.build()
	assert(response_data.has("source_energy") and response_data.source_energy is Dictionary)
	source_energy_profile = response_data.source_energy.duplicate(true)
	assert(source_energy_profile.encoding == "encoded_source_alpha_energy")
	assert(source_energy_profile.stroke_profile == "accepted_review_js_0p16")
	assert(float(source_energy_profile.inherited_stroke_multiplier) == 0.6)
	assert(float(source_energy_profile.stroke_multiplier) == 0.16)
	var shader: Shader = VfxPackageIO_59b6ecbb72.resource(str(source_energy_profile.shader)) as Shader
	assert(shader != null)
	source_energy_material = ShaderMaterial.new()
	source_energy_material.shader = shader
	source_energy_material.render_priority = response_material.render_priority
	# NativeOpacity's explicit already-adapted contract: this response owns its
	# occurrence alpha through source_colour/visor_opacity, before transfer math.
	# A second generic ALPHA multiplication would corrupt that energy and fade.
	source_energy_material.set_meta(OccurrenceOpacity.UNIFORM, true)
	response_mesh.material_override = source_energy_material


func source_colour(index: int, alpha: float) -> Color:
	if index == 1:
		alpha *= float(source_energy_profile.stroke_multiplier) / float(source_energy_profile.inherited_stroke_multiplier)
	return super.source_colour(index, alpha)


func capture_observation() -> Dictionary:
	var observation: Dictionary = super.capture_observation()
	observation["blade_source_energy"] = {
		"encoding": source_energy_profile.encoding,
		"stroke_profile": source_energy_profile.stroke_profile,
		"stroke_multiplier": source_energy_profile.stroke_multiplier,
		"shader": source_energy_profile.shader,
		"shader_sha256": source_energy_material.shader.code.sha256_text(),
		"occurrence_alpha_in_vertex_once": true,
		"edge_feather_added": false,
		"native_ADD_is_not_encoded_SCREEN_parity": true}
	return observation

const VfxPackageIO_59b6ecbb72 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
