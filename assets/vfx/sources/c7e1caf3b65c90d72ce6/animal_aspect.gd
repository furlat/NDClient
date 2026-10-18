extends "res://assets/vfx/sources/1f895c9802b6dd19377e/enhancement.gd"
## Animal aspect manifests through its own strokes. No enclosing body geometry.
var application_sparks: Node3D
var application_started: bool = false


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/c7e1caf3b65c90d72ce6/animal_aspect.gd", input)


func apply_scene_edits(node: Node) -> void:
	node.scale *= float(settings.scale)
	build_aspect_glyph(node)
	for line in aspect_glyph.get_children():
		line.material_override.shader = VfxPackageIO_c7e1caf3b6.resource("res://assets/vfx/sources/aff43d905d87c775b3ae/animal_aspect_glyph.gdshader")
		line.material_override.set_shader_parameter("aspect_tint", Color(str(settings.palette[3])))
	application_sparks = VfxPackageIO_c7e1caf3b6.resource(parameters.application_scene).instantiate()
	ResourceGraph.isolate_node(application_sparks, {})
	application_sparks.name = "EmblemBirth"
	application_sparks.scale = Vector3.ONE * float(settings.application.scale)
	node.add_child(application_sparks)
	_apply_particle_seed(application_sparks)
	for emitter in application_sparks.find_children("*", "GPUParticles3D", true, false):
		emitter.emitting = false
		emitter.one_shot = true
		emitter.local_coords = true
		emitter.fixed_fps = int(parameters.simulation_hz)
		emitter.process_material.color = Color(str(settings.palette[3])) * 1.1


func advance_lifecycle(_delta: float) -> void:
	tick += 1
	var age: float = float(tick) / float(parameters.simulation_hz)
	var reveal: float = smoothstep(0.12, 0.70, age)
	aspect_glyph.position = Vector3(0.0, 2.9 + 0.15 * reveal, 0.0)
	aspect_glyph.scale = Vector3.ONE * lerpf(0.72, 1.0, reveal)
	application_sparks.position = aspect_glyph.position
	if not application_started and age >= float(settings.application.start_seconds):
		application_started = true
		for emitter in application_sparks.find_children("*", "GPUParticles3D", true, false):
			emitter.restart()
			emitter.emitting = true
	var retire: float = 1.0 - smoothstep(float(settings.close) / 144.0, float(settings.frames) / 144.0, age)
	for material in materials:
		material.set_shader_parameter("support_clock", age)
		material.set_shader_parameter("support_envelope", retire)
		if material.has_meta("aspect_glyph"):
			material.set_shader_parameter("glyph_reveal", reveal)

const VfxPackageIO_c7e1caf3b6 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
