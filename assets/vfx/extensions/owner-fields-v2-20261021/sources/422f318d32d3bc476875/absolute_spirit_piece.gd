extends "res://assets/vfx/extensions/owner-fields-v2-20261021/sources/cbc38797fda0b3191f60/spirit_piece.gd"
## Original wing/clock writes depend only on the final native integer tick.
const ControllerRestore = preload("res://assets/vfx/extensions/owner-fields-v2-20261021/sources/6d7cfd14f2efee6263e2/restore.gd")


static func preparation_resources(input: Dictionary) -> Array:
	return [input.prepared_recipient_bank]


static func make_component(input: Dictionary) -> Node3D:
	var node: Node3D = ControllerRestore.make("res://assets/vfx/extensions/owner-fields-v2-20261021/sources/422f318d32d3bc476875/absolute_spirit_piece.gd", input)
	node.parameters.lifecycle_sampling = "analytical"
	return node


func sample_analytical_tick(desired_tick: int) -> bool:
	tick = desired_tick - 1
	advance_lifecycle(1.0 / float(parameters.simulation_hz))
	return tick == desired_tick
