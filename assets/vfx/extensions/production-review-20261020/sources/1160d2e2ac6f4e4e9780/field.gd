extends "res://assets/vfx/extensions/production-review-20261020/sources/c3eed67edc995b07c7e7/support_aura_of_life.gd"
## Existing main-owner petals. No embedded encounter lease, body or spatial UUID.
const Readiness = preload("res://assets/vfx/extensions/production-review-20261020/sources/7dd1897cdd5ee8a903b9/source_readiness.gd")
const OWNER_CONDITION := "condition.spell.aura_of_life.owner"
var bank: Resource
var binding := {}
var owner_state := {}
var input_error := ""


static func preparation_resources(input: Dictionary) -> Array:
	return [str(input.get("aura_field_bank", ""))]


static func make_component(input: Dictionary) -> Node3D:
	var prepared: Resource = Readiness.resources.get(str(input.get("aura_field_bank", "")))
	if prepared == null or not prepared.get("interface_prepared"):
		return null
	var node := preload("res://assets/vfx/extensions/production-review-20261020/sources/1160d2e2ac6f4e4e9780/field.gd").new()
	node.bank = prepared
	node.settings = prepared.art_settings.duplicate(true)
	node.material = prepared.program.material.duplicate(false)
	node._prepare_pieces(6)
	node.gpu_paths = GpuPaths.new(node, 0, prepared.program)
	node.sample(0.)
	return node


func set_owner_binding(value: Dictionary) -> void:
	for field in ["owner_uuid", "source_entity_uuid", "recipient_entity_uuid"]:
		if not value.get(field) is String or str(value[field]).is_empty():
			_reject("Actual aura owner, source and recipient identities are required")
			return
	if value.get("condition_id") != OWNER_CONDITION or value.source_entity_uuid != value.recipient_entity_uuid:
		_reject("Main aura owner must be the actual self-owned condition, not a member benefit")
		return
	if not binding.is_empty() and binding != value:
		_reject("A live main aura cannot switch its bound owner identity")
		return
	binding = value.duplicate(true)
	input_error = ""
	sample(local_clock)


func set_lease_input(value: Dictionary) -> void:
	owner_state = value.duplicate(true)
	sample(local_clock)


func set_owner_state(value: Dictionary) -> void:
	set_lease_input(value)


func set_entity_geometry(_value: Dictionary) -> void:
	# The field's actual kind0/part1 equation does not read body support.
	pass


func set_live_endpoints(_value: Array) -> void:
	# Placement is the actual condition owner's source root, not a hand socket.
	pass


func _reject(reason: String) -> void:
	input_error = reason
	envelope = 0.
	if material != null:
		material.set_shader_parameter("support_envelope", 0.)
	for piece: MeshInstance3D in pieces:
		piece.hide()


func owner_admitted() -> bool:
	if binding.is_empty() or not input_error.is_empty() or typeof(owner_state.get("observed")) != TYPE_BOOL \
			or typeof(owner_state.get("present")) != TYPE_BOOL or not owner_state.observed:
		return false
	var state: Variant = owner_state.get("condition_state")
	if not state is Dictionary or state.get("condition_uuid") != binding.owner_uuid or state.get("behavior_id") != OWNER_CONDITION:
		return false
	var suppression: Variant = state.get("suppression_provider_uuids", [])
	if not suppression is Array or not suppression.is_empty():
		return false
	if owner_state.get("source_entity_uuid") != binding.source_entity_uuid or owner_state.get("target_entity_uuid") != binding.recipient_entity_uuid:
		return false
	var removal: Variant = owner_state.get("removal_at_seconds")
	if removal != null and (typeof(removal) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(removal)) or float(removal) < 0.):
		return false
	return owner_state.present or removal != null


func sample(seconds: float) -> void:
	if material == null:
		return
	if not is_finite(seconds) or seconds < 0.:
		_reject("Actual nonnegative owner age is required")
		return
	local_clock = seconds
	envelope = smoothstep(0., float(settings.apply_seconds), seconds) * owner_visibility
	if not owner_admitted():
		envelope = 0.
	var removal: Variant = owner_state.get("removal_at_seconds")
	if removal != null and not bool(owner_state.get("present", false)) and typeof(removal) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(removal)):
		envelope *= 1. - smoothstep(float(removal), float(removal) + float(settings.retire_seconds), seconds)
	material.set_shader_parameter("support_clock", seconds)
	material.set_shader_parameter("support_envelope", envelope)
	_rebuild()


func refresh_live_inputs(seconds: float) -> void:
	sample(seconds)


func _rebuild() -> void:
	for piece: MeshInstance3D in pieces:
		piece.hide()
	if envelope <= .0001 or not global_position.is_finite():
		return
	# AuraOfLifeZone inherits Sphere(radius_feet=30); Sphere.radius is30//5.
	# This is a verified authored source size, not an undisclosed area object.
	var radius := float(settings.radius_cells)
	material.set_shader_parameter("gpu_support_seconds", local_clock)
	material.set_shader_parameter("gpu_support_radius", radius)
	var reach := radius * .98 + float(settings.width_cells)
	var bounds := AABB(Vector3(-reach, -.1, -reach), Vector3(2. * reach, .4, 2. * reach))
	for piece: MeshInstance3D in pieces:
		piece.global_transform = Transform3D(Basis.IDENTITY, global_position)
		piece.custom_aabb = bounds
		piece.show()


func capture_observation() -> Dictionary:
	return {"aura_owner": {"owner_uuid": binding.get("owner_uuid", ""),
		"owner_admitted": owner_admitted(), "source_age": local_clock,
		"actual_anchor": global_position, "radius_cells": settings.radius_cells, "envelope": envelope,
		"visible_pieces": pieces.filter(func(piece: MeshInstance3D) -> bool: return piece.visible).size(),
		"source_field_pieces": 6, "member_effect_reused_as_owner": false,
		"input_error": input_error, "review_lease_or_age_limit": false, "rules_evaluated": false}}
