extends "res://assets/vfx/extensions/source-preparation-20261020/sources/b591822f9528266545bf/freezing_delivery.gd"
## Original hand/flight/mist equations; fixed native construction is offline.
const Restore = preload("res://assets/vfx/extensions/late-20261020/sources/cb91ba2e7f30c0ed0811/restore.gd")
var prepared_geometry: Array = []
var prepared_materials: Array = []
var prepared_players: Array = []
var stable_paths := false


static func preparation_resources(input: Dictionary) -> Array:
	return [input.prepared_payload_bank]


static func make_component(input: Dictionary) -> Node3D:
	if input.get("kind","") != "freezing": return null
	var bank: Resource = VfxPackageIO_5893135c57.resource(input.prepared_payload_bank)
	if bank == null or not bank.interface_ready: return null
	var node := VfxPackageIO_5893135c57.resource("res://assets/vfx/extensions/source-preparation-20261020/sources/5893135c57e28e4bc834/delivery.gd").new() as Node3D
	node.specification = input.duplicate(true)
	node.prepare()
	return node


func prepare() -> void:
	if not draws.is_empty(): return
	var bank: Resource = VfxPackageIO_5893135c57.resource(specification.prepared_payload_bank)
	var restored := Restore.instantiate(bank,self)
	prepared_geometry = restored.geometry
	prepared_materials = restored.materials
	for index in 2:
		draws.append(prepared_geometry[index])
		materials.append(prepared_materials[index])
	mist = prepared_geometry[2]
	mist_material = prepared_materials[2]
	stable_paths = bank.verified_stable_paths


func source_bindings() -> Dictionary:
	return Restore.bindings(self)


func prepare_source_layer_mask(mask: int) -> void:
	Restore.layers(self,mask)


func has_verified_stable_paths() -> bool:
	return stable_paths

const VfxPackageIO_5893135c57 = preload("res://assets/vfx/extensions/source-preparation-20261020/scoped_resource_io.gd")
