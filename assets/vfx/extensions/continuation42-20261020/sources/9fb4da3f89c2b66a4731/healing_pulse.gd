extends "res://assets/vfx/sources/1f4996c92ad61d6c5518/healing_pulse.gd"
## Exact pulse edits are already retained in the prepared native donor.
const Restore = preload("res://assets/vfx/sources/ca69e9e47c9d66bb69fd/restore.gd")


static func preparation_resources(input: Dictionary) -> Array:
	return [input.prepared_recipient_bank]


static func make_component(input: Dictionary) -> Node3D:
	return Restore.make("res://assets/vfx/extensions/continuation42-20261020/sources/9fb4da3f89c2b66a4731/healing_pulse.gd", input)


func source_bindings() -> Dictionary:
	return Restore.declared_bindings(self, true)
