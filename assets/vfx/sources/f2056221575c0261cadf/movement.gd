extends "res://assets/vfx/sources/dbbd11d7b37fd1be2bc0/movement.gd"
## Original integer-tick movement clocks and Haste layer changes are inherited.
## Only fixed donor extraction, material adaptation and scene edits move offline.
const Restore = preload("res://assets/vfx/sources/ca69e9e47c9d66bb69fd/restore.gd")

static func preparation_resources(input: Dictionary) -> Array:
	return [input.prepared_recipient_bank]

static func make_component(input: Dictionary) -> Node3D:
	return Restore.make("res://assets/vfx/sources/f2056221575c0261cadf/movement.gd", input)

func source_bindings() -> Dictionary:
	return Restore.declared_bindings(self, false)
