extends Node3D
## One admitted, successful source cancellation. No gameplay or delivery solver.
## Original hand source stays separate from the finite reaction child owner.
const Cast = preload("res://assets/vfx/sources/5bf1f373ac1affd0173c/skeletal_cast.gd")
const Fragments = preload("res://assets/vfx/sources/6e25e2b7f8fcbfdb10c7/counter_fragments.gd")
const SourceSpace = preload("res://assets/vfx/sources/6487dfcacdbd7bcc9361/native_source_space.gd")
const Finish = preload("res://assets/vfx/sources/40040d80ebd5ecc1a6c3/source_finish.gd")

var settings: Dictionary = {}
var observation: Dictionary = {}
var endpoints: Array = []
var source: Node3D
var reaction: Node3D
var source_materials: Array = []
var age_seconds: float = -1.0
var source_age: float = -1.0
var event_admitted: bool = false
var interception_world: Vector3 = Vector3.ZERO
var original_shader_codes: Array = []
var reset_count: int = 0


static func make_component(input: Dictionary) -> Node3D:
	var result: Node3D = VfxPackageIO_23179f9816.resource("res://assets/vfx/sources/23179f981610edc6fd8f/finger_counterspell_source_v193.gd").new()
	result.settings = input.duplicate(true)
	result.observation = input.observation.duplicate(true)
	return result


func admitted(value: Dictionary) -> bool:
	for flag in ["admitted", "succeeded", "canceled"]:
		if typeof(value.get(flag)) != TYPE_BOOL or not value[flag]:
			return false
	for key in ["reaction_uuid", "triggered_event_uuid", "triggered_lineage_uuid", "source_entity_uuid", "target_entity_uuid"]:
		if str(value.get(key, "")) != str(settings.owner[key]) or str(value.get(key, "")).is_empty():
			return false
	return value.get("admitted", false) == true and value.get("succeeded", false) == true \
		and value.get("canceled", false) == true and value.get("reaction_id", "") == settings.owner.reaction_id \
		and value.get("outcome_code", "") == settings.owner.outcome_code \
		and value.get("phase", "") == "completion"


func set_cancellation_observation(value: Dictionary) -> bool:
	# A mismatched update cannot steal or mutate this instance's admitted owner.
	if not admitted(value):
		return false
	observation = value.duplicate(true)
	sample(age_seconds)
	return true


func remove_reaction_owner(reaction_uuid: String) -> bool:
	if reaction_uuid != str(settings.owner.reaction_uuid):
		return false
	observation.admitted = false
	sample(age_seconds)
	return true


func set_live_endpoints(value: Array) -> void:
	endpoints = value
	if source != null:
		source.set_live_endpoints(value)


func set_delivery_timing(launch: float, travel: float) -> void:
	# Retain the selected source's actual endpoint/timing seam. This branch never
	# creates a projectile, even when the surrounding normal recipe has timings.
	if source != null:
		source.set_delivery_timing(launch, travel)


func _build() -> void:
	source = Cast.make_component(settings.hand)
	source.name = "OriginalCounterspellHand"
	add_child(source)
	source.set_live_endpoints(endpoints)
	source.sample(0.0)
	for light in source.find_children("*", "Light3D", true, false):
		light.set_meta("factory_light_role", "geometry_only")
	original_shader_codes.clear()
	var material_seen := {}
	for node in source.find_children("*", "GeometryInstance3D", true, false):
		var material: Material = node.material_override
		if material is ShaderMaterial and not material_seen.has(material):
			material_seen[material] = true
			original_shader_codes.append(material.shader.code)
			Finish.apply(material, settings.hand_finish)
	source_materials = SourceSpace.adapt(source, {}, [])
	reaction = Fragments.make_component(settings.interception)
	reaction.name = "OriginalCoralInterception"
	add_child(reaction)
	reaction.sample(-1.0)


func _reset_source() -> void:
	# Keep registered geometry/material/emitter instances stable while restoring
	# the exact original clock and birth state. The host owns particle stepping.
	# Replacing scene nodes here would invalidate its cached native registrations.
	source.hand.tick = 0
	source.hand.particle_started = false
	source.hand.hand.position.y = -2.5
	source.hand.anim.seek(0.0, true)
	for material in source.hand.mats:
		material.set_shader_parameter("age", 0.0)
		material.set_shader_parameter("env", 0.0)
	for mesh in [source.hand.flare, source.hand.rim]:
		mesh.material_override.set_shader_parameter("env", 0.0)
	for particles in source.hand.magic_particles:
		particles.emitting = false
		particles.restart(true)
		particles.material_override.set_shader_parameter("env", 0.0)
	reset_count += 1


func sample(seconds: float) -> void:
	if source == null:
		_build()
	if seconds < age_seconds - .0000001:
		_reset_source()
	age_seconds = seconds
	source_age = seconds + float(settings.source_clock_offset)
	event_admitted = admitted(observation)
	visible = event_admitted and endpoints.size() >= 2 and source_age >= 0.0 and source_age < float(settings.source_end)
	# Controls are a countersequence study only. The omitted ordinary successful
	# cast belongs to its separate normal resource and is never fabricated here.
	source.visible = visible
	if visible:
		source.set_live_endpoints(endpoints)
		source.sample(source_age)
		if is_zero_approx(source_age):
			# The extracted source initializes env=1 before its first 144 Hz tick;
			# apply the original equation's exact zero boundary without a birth flash.
			for material in source.hand.mats:
				material.set_shader_parameter("env", 0.0)
			for mesh in [source.hand.flare, source.hand.rim]:
				mesh.material_override.set_shader_parameter("env", 0.0)
			for particles in source.hand.magic_particles:
				particles.material_override.set_shader_parameter("env", 0.0)
	for material in source_materials:
		material.set_shader_parameter("factory_world_to_source", Projection(global_transform.affine_inverse()))
	var native: Array = settings.interception_socket_native
	# The authored socket is frozen at index interception; it never follows the
	# later curled finger. The full original rig/portal keep the selected basis.
	interception_world = source.hand.to_global(Vector3(native[0], native[1], native[2]))
	reaction.position = to_local(interception_world)
	var reaction_age := source_age - float(settings.interception_source_seconds)
	reaction.sample(reaction_age)
	reaction.visible = visible and not bool(settings.get("hand_only_control", false)) \
		and reaction_age >= 0.0 and reaction_age < float(settings.reaction_owner_seconds)


func capture_observation() -> Dictionary:
	var turn: Array = settings.wrist_turn_source_seconds
	return {"family": "original_finger_counterspell_source", "source_seconds": source_age,
		"admitted_successful_cancellation": event_admitted, "owner": settings.owner.duplicate(true),
		"incoming_parent_owner": settings.incoming_parent_owner, "parent_owner_required_alive": false,
		"visible": visible, "visible_in_tree": is_visible_in_tree(),
		"source_visible": source != null and source.is_visible_in_tree(),
		"reaction_visible": reaction != null and reaction.is_visible_in_tree() and reaction.fragment.visible,
		"reaction_seconds": source_age - float(settings.interception_source_seconds),
		"interception_world": [interception_world.x, interception_world.y, interception_world.z],
		"wrist_turn_progress": clampf(inverse_lerp(float(turn[0]), float(turn[1]), source_age), 0.0, 1.0),
		"wrist_hold_through_source_seconds": settings.wrist_hold_through_source_seconds,
		"source_animation_position": source.hand.anim.current_animation_position if source != null else 0.0,
		"original_hand_materials": original_shader_codes.size(), "reset_count": reset_count,
		"source_clock_hz": 144, "no_projectile": source != null and source.projectile == null,
		"no_target_impact": true, "no_damage": true, "rule_solver": false,
		"hand_finish": "source pow1.15 six-stop nearest on original material inputs before lighting; historical post-raster/2x2 equivalence not claimed",
		"source_binding": source.capture_observation() if source != null else {}}

const VfxPackageIO_23179f9816 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
