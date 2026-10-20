extends "res://assets/vfx/sources/3926584c91ed1f4102cf/hypnotic.gd"
## Exact original lifecycle; only immutable source construction moves offline.
const Restore=preload("res://assets/vfx/extensions/continuation42-20261020/sources/6d7cfd14f2efee6263e2/restore.gd")
static func preparation_resources(input: Dictionary) -> Array:return [input.prepared_recipient_bank]
static func make_component(input: Dictionary) -> Node3D:
 return Restore.make("res://assets/vfx/extensions/continuation42-20261020/sources/fa9cf3f3d9e0897ec463/hypnotic.gd",input)
func source_bindings() -> Dictionary:return Restore.bindings(self)
func _ready() -> void:Restore.start(self)
