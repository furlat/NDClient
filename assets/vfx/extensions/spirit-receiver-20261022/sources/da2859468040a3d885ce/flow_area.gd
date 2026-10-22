extends "res://assets/vfx/sources/6814b201f9d6a0303075/flow_area.gd"
const Restore=preload("res://assets/vfx/extensions/spirit-receiver-20261022/sources/6d7cfd14f2efee6263e2/restore.gd")
static func preparation_resources(input: Dictionary) -> Array:return [input.prepared_recipient_bank]
static func make_component(input: Dictionary) -> Node3D:
 return Restore.make("res://assets/vfx/extensions/spirit-receiver-20261022/sources/da2859468040a3d885ce/flow_area.gd",input)
func source_bindings() -> Dictionary:return Restore.bindings(self)
