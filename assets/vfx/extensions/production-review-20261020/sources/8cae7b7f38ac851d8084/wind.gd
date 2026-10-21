extends "res://assets/vfx/sources/3f3d6952a3ea933aca3b/wind_wall.gd"
## Native Wind geometry/materials driven by the existing actual wall owner.
const WallInput = preload("res://assets/vfx/extensions/production-review-20261020/sources/f02011b40df3c7fa1160/input.gd")
const Readiness = preload("res://assets/vfx/extensions/production-review-20261020/sources/7dd1897cdd5ee8a903b9/source_readiness.gd")
var wall_context := {}
var wall_state := {}
var state_error := ""
var source_age := 0.0
const CONTACT_SLOTS := 16


static func preparation_resources(input: Dictionary) -> Array:
	return [str(input.wind_bank)]


static func make_component(input: Dictionary) -> Node3D:
	var context := WallInput.construction(input, "wind")
	var prepared: Resource = Readiness.resources.get(str(input.get("wind_bank", "")))
	if not context.error.is_empty() or prepared == null or not prepared.get("interface_ready"):
		return null
	var node := preload("res://assets/vfx/extensions/production-review-20261020/sources/8cae7b7f38ac851d8084/wind.gd").new()
	node.wall_context = context
	node.bank = prepared
	node.parameters = input.duplicate(true)
	node.settings = {"path_points": []}
	for point: Vector2 in context.points:
		node.settings.path_points.append([point.x, point.y])
	node._build()
	# Fixed native contact geometry is allocated once, never per frame/event.
	for index in range(2, CONTACT_SLOTS * 2):
		node.hit_meshes.append(node._draw(prepared.hit_mesh, node.hit_mats[index % 2], "ActualContact%02d" % index))
	for draw: MeshInstance3D in node.hit_meshes:
		draw.set_instance_shader_parameter("live_contact_envelope", 0.)
	for material: ShaderMaterial in node.mats:
		material.set_shader_parameter("live_wall_height", context.height)
		var offset: float = material.get_shader_parameter("wind_sheet_offset")
		material.set_shader_parameter("wind_sheet_offset", offset * context.width / (CELL / 5.))
	for index in node.flow_draws.size():
		var draw: MeshInstance3D = node.flow_draws[index]
		var segment: Dictionary = node.modules[index]
		var a: Vector3 = segment.start
		var b: Vector3 = segment.end
		# Sheet offsets follow actual width; miters can reach twice the offset.
		var margin: float = maxf(1.3, context.width + .5)
		var minimum := Vector3(minf(a.x, b.x) - margin, -.8, minf(a.z, b.z) - margin)
		var maximum := Vector3(maxf(a.x, b.x) + margin, context.height + .8, maxf(a.z, b.z) + margin)
		draw.custom_aabb = AABB(minimum, maximum - minimum)
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
	source_age = maxf(0., seconds)
	visible = WallInput.visible(wall_state, seconds, .6)
	if wall_state.is_empty():
		return
	var inverse := global_transform.affine_inverse()
	var occupants := PackedVector4Array()
	for entry: Dictionary in wall_state.get("occupants", []):
		var local: Vector3 = inverse * entry.ground
		occupants.append(Vector4(local.x, local.z, 1., 0.))
	var fade := 1. - WallInput.retirement(wall_state, seconds, .6)
	for material: ShaderMaterial in source_materials:
		material.set_shader_parameter("factory_world_to_source", Projection(inverse))
	for material: ShaderMaterial in mats:
		material.set_shader_parameter("live_occupant_count", occupants.size())
		if not occupants.is_empty():
			material.set_shader_parameter("live_occupants", occupants)
		material.set_shader_parameter("split_layers", false)
		material.set_shader_parameter("formation_pulse", 0.)
		material.set_shader_parameter("wind_clock", fmod(source_age, 2.))
		material.set_shader_parameter("reveal", 1.12 * smoothstep(0., .75, source_age))
		material.set_shader_parameter("wall_opacity", .36 * fade)
	var active := []
	for event: Dictionary in wall_state.get("contacts", []):
		var elapsed := source_age - float(event.at_seconds)
		if elapsed >= 0. and elapsed < .65:
			active.append(event)
	# Reject excess simultaneous visual contacts rather than silently lose facts.
	if active.size() > CONTACT_SLOTS:
		state_error = "More than sixteen simultaneous Wind contact visuals unsupported"
		hide()
		return
	for slot in CONTACT_SLOTS:
		var phase := 0.
		var envelope := 0.
		var point := Vector3.ZERO
		if slot < active.size():
			var event: Dictionary = active[slot]
			phase = clampf((source_age - float(event.at_seconds)) / .65, 0., 1.)
			envelope = smoothstep(0., .10, phase) * (1. - smoothstep(.55, 1., phase)) * fade
			point = inverse * event.ground
		for layer in 2:
			var draw: MeshInstance3D = hit_meshes[slot * 2 + layer]
			draw.position = point + Vector3(0., 1. + layer * .35, 0.)
			draw.scale = Vector3.ONE * lerpf(.18, .48, phase)
			draw.rotation = Vector3(.12 * layer, layer * 1.9 + phase * .18, 0.)
			draw.set_instance_shader_parameter("live_contact_phase", phase)
			draw.set_instance_shader_parameter("live_contact_envelope", envelope)
	feed_mat.albedo_color = Color(.66, .68, .61, .6 * smoothstep(0., .35, source_age) * fade)
	for index in debris.size():
		var phase := fmod(source_age * .5 + float(index) / 12., 1.)
		debris[index].position = debris_roots[index] + Vector3(.08 * sin(phase * TAU + index), wall_context.height * phase, .07 * cos(phase * TAU + index))
		debris[index].show()
		debris[index].rotation = Vector3(phase * 5., phase * 9. + index, phase * 6.)
		debris[index].scale = Vector3.ONE * smoothstep(0., .08, phase) * (1. - smoothstep(.75, 1., phase)) * smoothstep(0., .3, source_age)


func capture_observation() -> Dictionary:
	return {"wall_uuid": wall_context.get("owner", ""), "geometry": wall_context.get("geometry", {}),
		"source_age": source_age, "state_error": state_error,
		"actual_occupants": wall_state.get("occupants", []).size(), "actual_contacts": wall_state.get("contacts", []).size(),
		"review_damage_or_retirement_timer": false, "native_flow_draws": flow_draws.size(), "contact_capacity": CONTACT_SLOTS}
