extends "res://assets/vfx/extensions/source-preparation-20261020/sources/3098d8db1dc798de9179/retained_item.gd"
## Preserve corrected owner/anchor/power admission and native source sampling.
const Restore = preload("res://assets/vfx/extensions/late-20261020/sources/cb91ba2e7f30c0ed0811/restore.gd")
var prepared_geometry: Array = []
var prepared_materials: Array = []
var prepared_players: Array = []
var stable_paths := false


static func preparation_resources(input: Dictionary) -> Array:
	return [input.prepared_payload_bank]


static func make_component(input: Dictionary) -> Node3D:
	if input.get("kind","") != "freezing": return null
	var bank: Resource = VfxPackageIO_6190caa0d9.resource(input.prepared_payload_bank)
	if bank == null or not bank.interface_ready: return null
	var node := VfxPackageIO_6190caa0d9.resource("res://assets/vfx/extensions/source-preparation-20261020/sources/6190caa0d9fb53fad87a/retained.gd").new() as Node3D
	node.specification = input.duplicate(true)
	var supplied := 0
	for key in ["item_uuid","lifetime_uuid","original_caster_uuid"]:
		node.specification[key] = str(input.get(key,""))
		if not node.specification[key].is_empty(): supplied += 1
	if supplied != 0 and supplied != 3:
		node.free()
		return null
	node.owner_bound = supplied == 3
	node.set_payload_state(input.get("state",{}))
	return node


func prepare() -> void:
	if not draws.is_empty(): return
	var bank: Resource = VfxPackageIO_6190caa0d9.resource(specification.prepared_payload_bank)
	var restored := Restore.instantiate(bank,self)
	prepared_geometry = restored.geometry
	prepared_materials = restored.materials
	for draw: MeshInstance3D in prepared_geometry: draws.append(draw)
	for material: ShaderMaterial in prepared_materials: materials.append(material)
	stable_paths = bank.verified_stable_paths


func source_bindings() -> Dictionary:
	return Restore.bindings(self)


func prepare_source_layer_mask(mask: int) -> void:
	Restore.layers(self,mask)


func has_verified_stable_paths() -> bool:
	return stable_paths

const VfxPackageIO_6190caa0d9 = preload("res://assets/vfx/extensions/source-preparation-20261020/scoped_resource_io.gd")
