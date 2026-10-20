extends "res://assets/vfx/sources/a589f25f88f6955ab015/live_sunbeam.gd"
var prepared_bank: Resource
var prepared_geometry: Array=[]
var prepared_materials: Array=[]
var prepared_players: Array=[]
var prepared_lights: Array=[]
static func preparation_resources(input: Dictionary) -> Array:return [input.solar_contact_bank]
static func make_component(input: Dictionary) -> Node3D:return VfxPackageIO_d9df6cbeb2.resource(input.solar_contact_bank).restore(input)
func source_bindings() -> Dictionary:return {"geometry":prepared_geometry,"materials":prepared_materials,"players":prepared_players,"lights":prepared_lights,"static_material_topology":true,"static_geometry_layers":true}
func has_verified_stable_paths() -> bool:return prepared_bank.stable_paths_prepared

const VfxPackageIO_d9df6cbeb2 = preload("res://assets/vfx/extensions/continuation42-20261020/scoped_resource_io.gd")
