extends "res://assets/vfx/extensions/continuation42-20261020/sources/75c46e5e5be336467d9c/terrain_growth.gd"
## Exact original lifecycle; only immutable source construction moves offline.
const Restore=preload("res://assets/vfx/extensions/continuation42-20261020/sources/6d7cfd14f2efee6263e2/restore.gd")
static func preparation_resources(input: Dictionary) -> Array:return [input.prepared_recipient_bank]
static func make_component(input: Dictionary) -> Node3D:
 var node: Node3D=Restore.make("res://assets/vfx/extensions/continuation42-20261020/sources/9346732eb88b10b1c0bb/terrain_growth.gd",input)
 # Audited source writes only absolute final-tick transforms/uniforms. No
 # RNG/history/player/emission edge is consumed by advance_lifecycle().
 node.parameters.lifecycle_sampling="analytical"
 return node
func source_bindings() -> Dictionary:return Restore.bindings(self)
func _ready() -> void:Restore.start(self)

func sample_analytical_tick(desired_tick: int) -> bool:
 tick=desired_tick-1
 advance_lifecycle(1./float(parameters.simulation_hz))
 return tick==desired_tick
