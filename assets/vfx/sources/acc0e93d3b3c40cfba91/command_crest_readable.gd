extends "res://assets/vfx/sources/9fdc49fe466f72842b32/command_crest_contact.gd"
## Source COLOR.a scrolls the wave texture out of its own mask. Keep its
## visibly developed native phase through arrival, then use the finite crest
## envelope for retirement; a correct transform cannot restore dissolved UVs.


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/acc0e93d3b3c40cfba91/command_crest_readable.gd", input)


func _update_crest() -> void:
	super._update_crest()
	if crest == null or not transport_ready:
		return
	var process: ParticleProcessMaterial = subject.get_node("Wave33").process_material
	var readable_phase := minf(crest_age/.50, .35)
	crest_material.set_shader_parameter("crest_curve_alpha", process.alpha_curve.curve.sample_baked(readable_phase))
