extends "res://assets/vfx/sources/6e25e2b7f8fcbfdb10c7/counter_fragments.gd"
## Original fragment scale, rotation, palette and finite envelope remain live.
const Restore = preload("res://assets/vfx/extensions/late-20261020/sources/cb91ba2e7f30c0ed0811/restore.gd")
var prepared_geometry: Array = []
var prepared_materials: Array = []
var prepared_players: Array = []
var stable_paths := false


func prepare() -> void:
	var bank: Resource = VfxPackageIO_e08482398a.resource(settings.prepared_visual_bank)
	assert(bank.kind == "counterspell_contact")
	var restored: Dictionary = Restore.instantiate(bank, self)
	prepared_geometry = restored.geometry
	prepared_materials = restored.materials
	assert(prepared_geometry.size() == 1 and prepared_materials.size() == 1)
	fragment = prepared_geometry[0]
	material = prepared_materials[0]
	stable_paths = bank.verified_stable_paths
	sample(0.0)


func source_bindings() -> Dictionary:
	return Restore.bindings(self)

const VfxPackageIO_e08482398a = preload("res://assets/vfx/extensions/source-preparation-20261020/scoped_resource_io.gd")
