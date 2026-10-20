extends "res://assets/vfx/extensions/continuation42-20261020/sources/566cb4376a3c708e14a2/circle_receiving_contact.gd"
## Exact source lifecycle and actual connected recipient geometry remain live.
var prepared_bank: Resource
var prepared_geometry: Array=[]
var prepared_materials: Array=[]
var prepared_players: Array=[]
var prepared_lights: Array=[]
static func preparation_resources(input: Dictionary) -> Array:return [input.solar_contact_bank]
static func make_component(input: Dictionary) -> Node3D:
 var application: Dictionary=input.application
 for key in ["application_id","target_actor","damage_applied","save_succeeded","damage_type"]:assert(application.has(key))
 assert(not str(application.application_id).is_empty() and application.damage_type=="necrotic")
 return VfxPackageIO_d217e369c7.resource(input.solar_contact_bank).restore(input)
func _ready() -> void:
 for path in prepared_bank.restart_paths:get_node(path).restart()
func source_bindings() -> Dictionary:return {"geometry":prepared_geometry,"materials":prepared_materials,"players":prepared_players,"lights":prepared_lights,"static_material_topology":true,"static_geometry_layers":true}
func has_verified_stable_paths() -> bool:return prepared_bank.stable_paths_prepared

const VfxPackageIO_d217e369c7 = preload("res://assets/vfx/extensions/continuation42-20261020/scoped_resource_io.gd")
