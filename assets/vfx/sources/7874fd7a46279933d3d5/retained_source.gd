extends Node3D
## A native retained scene with explicit owner phases. No original spell timer.
## Analytical geometry/materials seek directly; GPU particles explicitly do not.
const ResourceGraph = preload("res://assets/vfx/sources/1d02b6d800655ef86df2/resource_graph.gd")
const ConditionClock = preload("res://assets/vfx/sources/605e963db6160617a696/condition_clock.gd")
const BaneOrbit = preload("res://assets/vfx/sources/2139f1dd82074ad7f33f/bane_orbit.gd")
var specification: Dictionary = {}
var lifecycle_context: Dictionary = {}
var state: Dictionary = {}
var retained: Node3D
var materials: Array[ShaderMaterial] = []
var players: Array[AnimationPlayer] = []
var particles: Array[GPUParticles3D] = []
var endpoints: Array = []
var previous_age := -1.0
var particle_seek_invalid := false
var previous_animation_age := -1.0
var material_parameters: Dictionary = {}


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = VfxPackageIO_7874fd7a46.resource("res://assets/vfx/sources/7874fd7a46279933d3d5/retained_source.gd").new()
	instance.specification = input.duplicate(true)
	instance.retained = VfxPackageIO_7874fd7a46.resource(input.scene).instantiate()
	instance.retained.name = "Retained"
	ResourceGraph.isolate_node(instance.retained, {})
	instance.add_child(instance.retained)
	instance._collect(instance.retained, {})
	return instance


func prepared_state_capability() -> Dictionary:
	return {"schema": "vfxfactory.prepared_state.v1", "mode": "native_scene_instance",
		"direct_time_sampling": particles.is_empty(), "requires_warmup": not particles.is_empty(),
		"particle_state_serializable": false, "geometry_and_materials_direct_time_sampling": true,
		"on_nonsequential_particle_seek": "restart_and_replay_from_application; do not claim GPU state restored",
		"phase_transition": "retain_instance; set_lifecycle_context", "source": specification.scene}


func _collect(node: Node, seen: Dictionary) -> void:
	if node is GeometryInstance3D:
		_collect_material(node.material_override, seen)
	if node is MeshInstance3D and node.mesh != null:
		for index in node.mesh.get_surface_count():
			_collect_material(node.get_active_material(index), seen)
	if node is GPUParticles3D and node.visible and node.layers != 0:
		particles.append(node)
		for index in node.draw_passes:
			var mesh: Mesh = node.get_draw_pass_mesh(index)
			if mesh != null:
				for surface in mesh.get_surface_count():
					_collect_material(mesh.surface_get_material(surface), seen)
	if node is AnimationPlayer:
		node.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		node.autoplay = ""
		players.append(node)
	for child in node.get_children():
		_collect(child, seen)


func _collect_material(material: Material, seen: Dictionary) -> void:
	if material is ShaderMaterial and not seen.has(material):
		seen[material] = true
		materials.append(material)
		var parameters := {}
		for uniform in material.shader.get_shader_uniform_list():
			parameters[str(uniform.name)] = true
		material_parameters[material] = parameters


func set_lifecycle_context(value: Dictionary) -> void:
	lifecycle_context = value.duplicate(true)


func set_live_endpoints(value: Array) -> void:
	endpoints = value


func sample(seconds: float) -> void:
	var phase: String = lifecycle_context.get("phase", specification.phase)
	var phase_age: float = lifecycle_context.get("phase_age_seconds", seconds)
	var clock_spec := specification.duplicate()
	clock_spec.phase_seconds = specification.durations[phase]
	state = ConditionClock.evaluate(phase, phase_age, clock_spec, lifecycle_context)
	var age: float = state.source_age_seconds
	if not particles.is_empty() and ((previous_age < 0.0 and age > .1) or (previous_age >= 0.0 and (age < previous_age or age - previous_age > .25))):
		particle_seek_invalid = true
	previous_age = age
	var animation_age := minf(age, float(specification.hold_animation_seconds))
	if not is_equal_approx(animation_age, previous_animation_age):
		for player in players:
			if player.has_animation(specification.animation):
				player.play(specification.animation)
				player.seek(animation_age, true)
				player.pause()
		previous_animation_age = animation_age
	if specification.get("motion", "") == "bane_orbit":
		BaneOrbit.sample(retained.get_node("Donor"), age, specification.source_height, specification.source_scale)
	for material in materials:
		var parameters: Dictionary = material_parameters[material]
		var shader_age := fposmod(age, 6.0) if specification.get("motion", "") == "bane_orbit" else age
		for parameter in specification.clock_parameters:
			if parameters.has(parameter):
				material.set_shader_parameter(parameter, shader_age)
		var envelope: float = float(specification.gain)
		if specification.get("body_surface", false):
			envelope *= float(state.opacity)
		for parameter in ["support_envelope", "vfx_alpha"]:
			if parameters.has(parameter):
				material.set_shader_parameter(parameter, envelope)
		if parameters.has("condition_opacity"):
			material.set_shader_parameter("condition_opacity", state.opacity)
	for emitter in particles:
		if specification.continuous_emitters.has(str(retained.get_path_to(emitter))):
			emitter.one_shot = false
			emitter.emitting = state.opacity > 0.0
	if not endpoints.is_empty():
		retained.global_position = endpoints[0].point
	if endpoints.size() > 1 and retained.has_node("Donor/SanctuaryMark"):
		var mark: Node3D = retained.get_node("Donor/SanctuaryMark")
		mark.global_position = endpoints[1].point + Vector3.UP * .16
		if endpoints[1].has("view_basis"):
			mark.global_basis = endpoints[1].view_basis.orthonormalized().scaled(mark.global_basis.get_scale())
	if specification.get("emits_light", false):
		for light in retained.find_children("*", "OmniLight3D", true, false):
			light.light_energy = float(specification.light_energy) * float(state.opacity)
			light.visible = state.opacity > 0.0


func capture_observation() -> Dictionary:
	var particle_count := 0
	for emitter in particles:
		particle_count += emitter.amount
	return {"lifecycle": state.duplicate(true), "owner_controls_expiry": true,
		"prepared_capability": prepared_state_capability(), "particle_seek_invalid": particle_seek_invalid,
		"source_materials": materials.size(), "particle_capacity": particle_count,
		"body_surface_slots": 1 if specification.get("body_surface", false) else 0}

const VfxPackageIO_7874fd7a46 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
