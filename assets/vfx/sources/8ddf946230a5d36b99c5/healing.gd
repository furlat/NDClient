extends "res://assets/vfx/sources/1e83a91767b68e67396e/healing.gd"
## Inherits Healing's integer clocks, including its source-specific Aid envelope.
const Restore = preload("res://assets/vfx/sources/ca69e9e47c9d66bb69fd/restore.gd")

static func preparation_resources(input: Dictionary) -> Array:
	return [input.prepared_recipient_bank]

static func make_component(input: Dictionary) -> Node3D:
	return Restore.make("res://assets/vfx/sources/8ddf946230a5d36b99c5/healing.gd", input)

func source_bindings() -> Dictionary:
	return Restore.declared_bindings(self, true)
