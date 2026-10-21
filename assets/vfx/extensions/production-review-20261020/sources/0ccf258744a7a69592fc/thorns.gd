extends "res://assets/vfx/sources/33bb4a6842b90d94f371/wall.gd"
## The approved native source with actual construction, occupancy and events.
const WallInput = preload("res://assets/vfx/extensions/production-review-20261020/sources/f02011b40df3c7fa1160/input.gd")
const Readiness = preload("res://assets/vfx/extensions/production-review-20261020/sources/7dd1897cdd5ee8a903b9/source_readiness.gd")
var wall_context := {}
var wall_state := {}
var state_error := ""
var source_bounds := AABB()


static func preparation_resources(input: Dictionary) -> Array:
	return [str(input.thorns_bank)]


static func make_component(input: Dictionary) -> Node3D:
	var context := WallInput.construction(input, "thorns")
	var prepared: Resource = Readiness.resources.get(str(input.get("thorns_bank", "")))
	if not context.error.is_empty() or prepared == null or not prepared.get("interface_ready"):
		return null
	var node := preload("res://assets/vfx/extensions/production-review-20261020/sources/0ccf258744a7a69592fc/thorns.gd").new()
	node.wall_context = context
	node.bank = prepared
	node.settings = input.duplicate(true)
	node.settings.module_count = context.modules
	node.settings.circular = context.circular
	node.settings.heading = context.heading
	node._build()
	var span: float = context.get("radius", context.length * .5) + context.width + 1.
	node.source_bounds = AABB(Vector3(context.center.x - span, -.5, context.center.y - span), Vector3(span * 2., context.height + 1.5, span * 2.))
	var along: float = 1.0 if context.circular else context.length / (float(context.modules) * CELL)
	for index in node.module_transforms.size():
		var transform: Transform3D = node.module_transforms[index]
		transform.origin.x *= along
		transform.basis = Basis.from_scale(Vector3(along, 1., 1.)) * transform.basis
		node.module_transforms[index] = transform
		node.draws[index].transform = transform * prepared.mesh_transform
		var decal_transform: Transform3D = transform * prepared.decal_properties.transform
		if context.circular:
			var theta := transform.origin.x / (16.0 * CELL) * TAU
			decal_transform.origin = Vector3(sin(theta) * context.radius, decal_transform.origin.y, cos(theta) * context.radius)
			decal_transform.basis = Basis(Vector3.UP, theta) * decal_transform.basis
		else:
			decal_transform = Transform3D(Basis(Vector3.UP, context.heading), Vector3.ZERO) * decal_transform
		decal_transform.origin += Vector3(context.center.x, 0., context.center.y)
		node.decals[index].transform = decal_transform
	node.material.set_shader_parameter("live_wall_center", context.center)
	node.material.set_shader_parameter("live_wall_radius", context.get("radius", 2.0 * CELL))
	node.material.set_shader_parameter("live_wall_width_scale", context.width / CELL)
	node.material.set_shader_parameter("live_wall_height_scale", context.height / (2.0 * CELL))
	node.hide()
	return node


func set_visual_state(value: Dictionary) -> void:
	state_error = WallInput.visual(value, wall_context.owner)
	if not state_error.is_empty():
		wall_state = {}
		hide()
		return
	wall_state = value.duplicate(true)


func refresh_live_inputs(seconds: float) -> void:
	sample(seconds)


func sample(seconds: float) -> void:
	if not is_finite(seconds):
		return
	visible = WallInput.visible(wall_state, seconds, .6)
	if wall_state.is_empty():
		return
	var inverse := global_transform.affine_inverse()
	material.set_shader_parameter("thorns_world_to_source", inverse)
	material.set_shader_parameter("thorns_source_to_world", global_transform)
	var occupants := PackedVector4Array()
	for occupant: Dictionary in wall_state.get("occupants", []):
		var point: Vector3 = inverse * occupant.ground
		var energy := 0.0
		for event: Dictionary in wall_state.get("contacts", []):
			if event.kind == "damage" and event.actor_uuid == occupant.actor_uuid:
				energy = maxf(energy, WallInput.pulse(event, seconds))
		occupants.append(Vector4(point.x, point.z, 1., energy))
	material.set_shader_parameter("occupant_count", occupants.size())
	if not occupants.is_empty():
		material.set_shader_parameter("occupants", occupants)
	retirement = WallInput.retirement(wall_state, seconds, .6)
	material.set_shader_parameter("wall_clock", fmod(maxf(0., seconds), 2.0))
	material.set_shader_parameter("wall_fade", 1. - smoothstep(.65, 1., retirement))
	material.set_shader_parameter("retirement", retirement)
	# Formation is finite; the original final Start key remains held indefinitely.
	var scale_value: Vector3 = _animation_value("scale", seconds)
	var mesh_transform: Transform3D = bank.mesh_transform
	mesh_transform.basis = Basis.from_scale(scale_value)
	for index in draws.size():
		draws[index].transform = module_transforms[index] * mesh_transform
		if absf(draws[index].transform.basis.determinant()) > .000001:
			draws[index].custom_aabb = draws[index].transform.affine_inverse() * source_bounds
		draws[index].set_instance_shader_parameter("DisolverSTEP", _animation_value("dissolve", seconds))
		var modulation: Color = _animation_value("modulate", seconds)
		modulation.a *= 1. - retirement
		decals[index].modulate = modulation
		decals[index].albedo_mix = _animation_value("albedo_mix", seconds)
		decals[index].visible = _animation_value("visible", seconds)
	last_age = seconds


func capture_observation() -> Dictionary:
	return {"wall_uuid": wall_context.get("owner", ""), "geometry": wall_context.get("geometry", {}),
		"state_error": state_error, "source_age": last_age, "retirement": retirement,
		"actual_occupants": wall_state.get("occupants", []).size(), "actual_contacts": wall_state.get("contacts", []).size(),
		"review_damage_or_retirement_timer": false, "native_modules": draws.size()}
