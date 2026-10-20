extends "res://assets/vfx/sources/ec9cb8f39586b3f03214/support.gd"
## The original Base lifecycle, native players and particle clocks remain live.
const Restore = preload("res://assets/vfx/sources/ca69e9e47c9d66bb69fd/restore.gd")

static func preparation_resources(input: Dictionary) -> Array:
	return [input.prepared_recipient_bank]

static func make_component(input: Dictionary) -> Node3D:
	return Restore.make("res://assets/vfx/sources/12b876b2908476545b90/support.gd", input)

func source_bindings() -> Dictionary:
	return Restore.declared_bindings(self, true)
