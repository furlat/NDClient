extends "res://assets/vfx/extensions/owner-fields-v2-20261021/sources/ba8b6424bb87745965ff/sleet_soft_mist.gd"
## Original source geometry and motion; explicit actual-owner continuation.
const Restore = preload("res://assets/vfx/extensions/owner-fields-v2-20261021/sources/6d7cfd14f2efee6263e2/restore.gd")


static func preparation_resources(input: Dictionary) -> Array:
	return [input.prepared_recipient_bank]


static func make_component(input: Dictionary) -> Node3D:
	var node: Node3D = Restore.make("res://assets/vfx/extensions/owner-fields-v2-20261021/sources/6332bac4f8afe417e20b/sleet_leaf.gd", input)
	node.parameters.lifecycle_sampling = "analytical"
	return node


func _ready() -> void:
	Restore.start(self)


func source_bindings() -> Dictionary:
	return Restore.bindings(self)


func sample_analytical_tick(desired_tick: int) -> bool:
	tick = desired_tick - 1
	advance_lifecycle(1.0 / float(parameters.simulation_hz))
	return tick == desired_tick
