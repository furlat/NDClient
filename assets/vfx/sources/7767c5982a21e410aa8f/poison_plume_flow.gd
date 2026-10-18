extends "res://assets/vfx/sources/048e2881b9068776f055/clocked_source.gd"
## Original liquid-cone geometry, normal/albedo maps and smoke flipbook.
## Smooth coverage replaces opaque scissored sheets; source trajectories stay.


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/7767c5982a21e410aa8f/poison_plume_flow.gd", input)


func apply_scene_edits(node: Node) -> void:
	var liquid: GPUParticles3D = node.get_node("acidcone")
	var material: StandardMaterial3D = liquid.material_override
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.alpha_scissor_threshold = 0.0
	material.emission *= float(parameters.liquid_emission_gain)
	var color: Color = liquid.process_material.color
	var gain: float = float(parameters.liquid_color_gain)
	liquid.process_material.color = Color(color.r * gain, color.g * gain, color.b * gain,
		color.a * float(parameters.liquid_alpha_gain))
	liquid.process_material.scale_min *= float(parameters.liquid_scale_min_gain)
	liquid.process_material.scale_max *= float(parameters.liquid_scale_max_gain)
	var smoke: GPUParticles3D = node.get_node("VFX_Smoke_A15")
	var smoke_color: Color = smoke.process_material.color
	var smoke_gain: float = float(parameters.smoke_color_gain)
	smoke.process_material.color = Color(smoke_color.r * smoke_gain, smoke_color.g * smoke_gain,
		smoke_color.b * smoke_gain, smoke_color.a * float(parameters.smoke_alpha_gain))


func capture_observation() -> Dictionary:
	var result: Dictionary = super.capture_observation()
	result.native_liquid_count = 40
	result.native_smoke_count = 5
	result.native_normal_map_retained = true
	result.coverage = "smooth source alpha instead of opaque alpha scissor"
	return result
