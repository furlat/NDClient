extends "res://assets/vfx/sources/e8471d2128c6091743c3/gust_front.gd"
## Original source geometry/materials; explicit caster-ground endpoint binding.
var endpoints: Array = []

static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/06b214e81043f90468de/gust_registration.gd", input)


func set_live_endpoints(value: Array) -> void:
	endpoints = value
	if initialized:
		update_geometry()


func sample(seconds: float) -> void:
	var desired_tick: int = maxi(0, int(round(seconds * float(parameters.simulation_hz))))
	if desired_tick < tick:
		tick = desired_tick
	super.sample(maxf(0.0, seconds))


func advance_lifecycle(delta: float) -> void:
	if endpoints.size() >= 3:
		# Host attachment translation is applied after the live packet arrives.
		# The explicit first endpoint is this occurrence's caster-ground origin.
		var inverse_basis: Basis = subject.global_basis.inverse()
		var caster_ground: Vector3 = endpoints[0].point
		var target_offset: Vector3 = inverse_basis * (endpoints[2].point - caster_ground)
		var aim := Vector3(target_offset.x, 0.0, target_offset.z).normalized()
		if not aim.is_zero_approx():
			direction = aim
			hand = inverse_basis * (endpoints[1].point - caster_ground)
			across = Vector3(-direction.z, 0.0, direction.x)
			head.rotation.y = atan2(-direction.x, -direction.z)
			body.rotation.y = head.rotation.y
	super.advance_lifecycle(delta)


func update_geometry() -> void:
	# Both donor particle systems become indexed meshes. The original source
	# function has no accumulated particle state: it evaluates tick/endpoints.
	# Its preincrement needs this offset to evaluate the unchanged held tick.
	tick -= 1
	advance_lifecycle(0.0)


func capture_observation() -> Dictionary:
	var value: Dictionary = super.capture_observation()
	value.live_endpoint_count = endpoints.size()
	value.local_direction = [direction.x, direction.y, direction.z]
	value.local_hand = [hand.x, hand.y, hand.z]
	value.source_material_count = mats.size()
	value.registration_resamples_held_source_tick = true
	return value
