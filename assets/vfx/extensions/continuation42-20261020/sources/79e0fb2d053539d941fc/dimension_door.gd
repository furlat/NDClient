extends "res://assets/vfx/extensions/continuation42-20261020/sources/8908139b773a8a0602aa/dimension_door.gd"
## Exact original lifecycle; only immutable source construction moves offline.
const Restore=preload("res://assets/vfx/extensions/continuation42-20261020/sources/6d7cfd14f2efee6263e2/restore.gd")
static func preparation_resources(input: Dictionary) -> Array:return [input.prepared_recipient_bank]
static func make_component(input: Dictionary) -> Node3D:
 return Restore.make("res://assets/vfx/extensions/continuation42-20261020/sources/79e0fb2d053539d941fc/dimension_door.gd",input)
func source_bindings() -> Dictionary:return Restore.bindings(self)
func _ready() -> void:Restore.start(self)
