extends "res://assets/vfx/sources/6814b201f9d6a0303075/flow_area.gd"
## The source ground current continues; only the finite review retirement is removed.
const Restore = preload("res://assets/vfx/extensions/spirit-runtime-20261021/sources/6d7cfd14f2efee6263e2/restore.gd")


static func preparation_resources(input: Dictionary) -> Array:
	return [input.prepared_recipient_bank]


static func make_component(input: Dictionary) -> Node3D:
	return Restore.make("res://assets/vfx/extensions/spirit-runtime-20261021/sources/7e3b80c759ba5063bd33/flow_hold.gd", input)


func source_bindings() -> Dictionary:
	return Restore.bindings(self)


func sample(seconds: float) -> void:
	material.set_shader_parameter("clock", seconds)
	material.set_shader_parameter("envelope", smoothstep(0.0, .3, seconds))
