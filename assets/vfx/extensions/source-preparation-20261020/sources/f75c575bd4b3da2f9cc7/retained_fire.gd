extends "res://assets/vfx/extensions/source-preparation-20261020/sources/3098d8db1dc798de9179/retained_item.gd"
## Original current-item admission and pure-time material/placement equations.
## Only immutable draw/program construction is replaced by prepared operands.
const Restore = preload("res://assets/vfx/extensions/late-20261020/sources/cb91ba2e7f30c0ed0811/restore.gd")
var prepared_geometry: Array = []
var prepared_materials: Array = []
var prepared_players: Array = []
var stable_paths := false


static func preparation_resources(input: Dictionary) -> Array:
	return [input.prepared_visual_bank]


static func make_component(input: Dictionary) -> Node3D:
	if input.get("kind", "") != "delayed_fire":
		return null
	var result: Node3D = VfxPackageIO_f75c575bd4.resource("res://assets/vfx/extensions/source-preparation-20261020/sources/f75c575bd4b3da2f9cc7/retained_fire.gd").new()
	result.specification = input.duplicate(true)
	var supplied := 0
	for key in ["item_uuid", "lifetime_uuid", "original_caster_uuid"]:
		result.specification[key] = str(input.get(key, ""))
		if not result.specification[key].is_empty():
			supplied += 1
	if supplied != 0 and supplied != 3:
		result.free()
		return null
	result.owner_bound = supplied == 3
	result.set_payload_state(input.get("state", {}))
	return result


func prepare() -> void:
	var bank: Resource = VfxPackageIO_f75c575bd4.resource(specification.prepared_visual_bank)
	assert(bank.kind == "retained_fire")
	var restored: Dictionary = Restore.instantiate(bank, self)
	prepared_geometry = restored.geometry
	prepared_materials = restored.materials
	for draw: MeshInstance3D in prepared_geometry:
		draws.append(draw)
	for material: ShaderMaterial in prepared_materials:
		materials.append(material)
	stable_paths = bank.verified_stable_paths


func source_bindings() -> Dictionary:
	return Restore.bindings(self)


func has_verified_stable_paths() -> bool:
	return stable_paths


func prepare_source_layer_mask(mask: int) -> void:
	Restore.layers(self, mask)


func refresh_live_inputs(seconds: float) -> void:
	sample(seconds)

const VfxPackageIO_f75c575bd4 = preload("res://assets/vfx/extensions/source-preparation-20261020/scoped_resource_io.gd")
