extends "res://assets/vfx/sources/6570e2018ead9862abda/command_voice_admitted.gd"
## Wave33 is one native half-sphere particle. Evaluate that same mesh/material
## directly so its readable crest reaches the supplied face at original contact.
## The other two donor particle layers retain their ordinary source sampler.
var crest: MeshInstance3D
var crest_material: ShaderMaterial
var crest_age: float = 0.0


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/28daeb3e9bac6c2f277f/command_crest_transport.gd", input)


func prepare_materials(node: Node) -> void:
	super.prepare_materials(node)
	var wave: GPUParticles3D = subject.get_node("Wave33")
	assert(wave.amount == 1, "Command crest port represents the original single source particle")
	crest = MeshInstance3D.new()
	crest.name = "NativeVoiceCrest"
	crest.mesh = wave.draw_pass_1
	crest.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Isolate the mutable material while retaining the original text shader.
	crest_material = ResourceGraph.clone_value(wave.material_override, {})
	var shader := Shader.new()
	var code: String = crest_material.shader.code.replace("shader_type spatial;", "shader_type spatial;\nuniform float crest_curve_alpha=0.0;\nuniform float crest_envelope=0.0;\n")
	if code.contains("void vertex()"):
		code = ClipBindings.finish_function(code, "vertex", "\nCOLOR=vec4(vec3(1.0),crest_curve_alpha);\n")
	else:
		# This fragment-only VisualShader legitimately has no vertex function.
		code += "\nvoid vertex(){COLOR=vec4(vec3(1.0),crest_curve_alpha);}\n"
	code = ClipBindings.finish_fragment(code, "\nALPHA*=crest_envelope;\n")
	shader.code = code
	ClipBindings.replace_shader(crest_material, shader)
	crest.material_override = crest_material
	subject.add_child(crest)
	voice_materials.append(crest_material)
	wave.hide()
	crest.hide()
	# It is the same source-clock material as the native wave, independently owned.
	materials.append(crest_material)


func sample(seconds: float) -> void:
	crest_age = maxf(0.0, seconds)
	super.sample(seconds)
	_update_crest()


func update_geometry() -> void:
	super.update_geometry()
	_update_crest()


func _update_crest() -> void:
	if crest == null or not transport_ready or endpoints.size() < 2:
		return
	var wave: GPUParticles3D = subject.get_node("Wave33")
	var process: ParticleProcessMaterial = wave.process_material
	var travel: float = settings.native_travel_seconds
	var progress := clampf(crest_age / travel, 0.0, 1.0)
	var source_distance: float = endpoints[0].point.distance_to(endpoints[1].point) / float(settings.radius_cells)
	# Retain the donor's own alpha/scale curves. Give the finite crest a readable
	# terminal portion before its original three-layer event finishes; do not
	# make its geometry stretch to the target or create a persistent beam.
	var curve_age := clampf(crest_age / .50, 0.0, 1.0)
	var scale_value: float = process.scale_min * process.scale_curve.curve.sample_baked(curve_age)
	var transform := Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * scale_value), Vector3(0, 0, -source_distance * progress))
	crest.transform = wave.transform * transform
	crest_material.set_shader_parameter("crest_curve_alpha", process.alpha_curve.curve.sample_baked(curve_age))
	var envelope := smoothstep(0.0, .025, crest_age) * (1.0-smoothstep(travel+.025, travel+.15, crest_age))
	crest_material.set_shader_parameter("crest_envelope", envelope)
	crest.visible = envelope > .001


func capture_observation() -> Dictionary:
	var result: Dictionary = super.capture_observation()
	result.crest_source_mesh = subject.get_node("Wave33").draw_pass_1.resource_path if prepared else ""
	result.crest_progress = clampf(crest_age / float(settings.native_travel_seconds), 0.0, 1.0)
	result.crest_same_single_particle_mesh_and_material = true
	result.crest_direct_source_clock = true
	return result
