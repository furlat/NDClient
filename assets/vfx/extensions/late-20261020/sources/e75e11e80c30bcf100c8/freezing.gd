extends "res://assets/vfx/extensions/late-20261020/sources/9e01bea27ad66740b60c/blast.gd"
## Exact original sixteen fragment layers and live supplied footprint.
const Restore = preload("res://assets/vfx/extensions/late-20261020/sources/cb91ba2e7f30c0ed0811/restore.gd")
const FootprintState = preload("res://assets/vfx/extensions/late-20261020/sources/044bd38b0183a2110147/footprint_state.gd")
var footprint := FootprintState.new()
var prepared_geometry: Array = []
var prepared_materials: Array = []
var prepared_players: Array = []
var stable_paths := false

static func preparation_resources(input: Dictionary) -> Array:
	return [input.prepared_payload_bank]

static func make_component(input: Dictionary) -> Node3D:
	assert(input.kind == "freezing")
	assert(not str(input.get("source_owner_uuid", "")).is_empty())
	assert(not str(input.get("original_caster_uuid", "")).is_empty())
	var node: Node3D = VfxPackageIO_e75e11e80c.resource("res://assets/vfx/extensions/late-20261020/sources/e75e11e80c30bcf100c8/freezing.gd").new()
	node.specification = input.duplicate(true)
	node.set_blast_event(input.get("event", {}))
	return node

func prepare() -> void:
	if not draws.is_empty(): return
	var bank: Resource = VfxPackageIO_e75e11e80c.resource(specification.prepared_payload_bank)
	var restored: Dictionary = Restore.instantiate(bank, self)
	prepared_geometry = restored.geometry
	prepared_materials = restored.materials
	for draw: MeshInstance3D in prepared_geometry: draws.append(draw)
	for material: ShaderMaterial in prepared_materials: materials.append(material)
	var cells: Array = event.get("admitted_cells", specification.get("admitted_cells", []))
	if not cells.is_empty(): apply_footprint_cells(materials, cells)
	stable_paths = bank.verified_stable_paths

func apply_footprint_cells(selected_materials: Array, cells: Array) -> void:
	footprint.apply(selected_materials, cells)

func source_bindings() -> Dictionary:
	return Restore.bindings(self)

func refresh_live_inputs(seconds: float) -> void:
	# Pure original draw transforms/material operands; no native simulation.
	sample(seconds)

func prepare_source_layer_mask(mask: int) -> void:
	Restore.layers(self, mask)

func has_verified_stable_paths() -> bool:
	return stable_paths

const VfxPackageIO_e75e11e80c = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
