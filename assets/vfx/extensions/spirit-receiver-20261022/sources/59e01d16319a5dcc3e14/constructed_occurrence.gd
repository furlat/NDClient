extends "res://assets/vfx/extensions/spirit-receiver-20261022/sources/6269f7f4cb5f43f5a59c/occurrence.gd"
## Explicit preparation-time public seam. The caller obtains phase.to_clip(),
## privately supplies that source's documented operands, then constructs once.
## This does not project native facts, rewrite actors, or infer successful events.


static func make_component(input: Dictionary) -> Node3D:
	assert(input.get("clip") is Dictionary, "Supply an explicitly prepared public phase clip")
	assert(not input.clip.is_empty(), "Missing construction operands are not a fixture fallback")
	var instance: Node3D = VfxPackageIO_59e01d1631.resource("res://assets/vfx/extensions/spirit-receiver-20261022/sources/59e01d16319a5dcc3e14/constructed_occurrence.gd").new()
	instance.parameters = input.duplicate(true)
	return instance


func construction_clip() -> Dictionary:
	return parameters.clip.duplicate(true)


func set_owner_binding(value: Dictionary) -> void:
	forward("set_owner_binding", value)


func set_lease_input(value: Dictionary) -> void:
	forward("set_lease_input", value)


func set_event_input(value: Dictionary) -> void:
	forward("set_event_input", value)


func body_surface_sample(actual_actor_uuid: String) -> Dictionary:
	if inputs_dirty:
		refresh_input_bindings()
	var providers: Array = input_receivers.get("body_surface_sample", [])
	# One selected material source, not implicit multi-provider composition.
	if providers.size() != 1 or not is_instance_valid(providers[0]):
		return {}
	return providers[0].body_surface_sample(actual_actor_uuid)

const VfxPackageIO_59e01d1631 = preload("res://assets/vfx/extensions/spirit-receiver-20261022/scoped_resource_io.gd")
