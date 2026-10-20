extends "res://assets/vfx/extensions/late-20261020/sources/ebb0b7e0e5d4e00b112f/steam_cloud.gd"
const Restore = preload("res://assets/vfx/extensions/late-20261020/sources/cb91ba2e7f30c0ed0811/restore.gd")
var prepared_geometry: Array = []
var prepared_materials: Array = []
var prepared_players: Array = []
var stable_paths := false

static func preparation_resources(input: Dictionary) -> Array:
	return [input.prepared_surface_bank]

static func make_component(input: Dictionary) -> Node3D:
	var bank: Resource = VfxPackageIO_97fb9af256.resource(input.prepared_surface_bank)
	var node: Node3D = VfxPackageIO_97fb9af256.resource("res://assets/vfx/extensions/late-20261020/sources/97fb9af256ceebde4f0f/steam.gd").new()
	# These exact immutable shape operands are validated without serializing or
	# hashing the owner's live cells/retirement. Other shapes need preparation.
	for field in bank.static_settings:
		assert(input.get(field) == bank.static_settings[field], "Unprepared native steam shape: " + str(field))
	node.settings = input.duplicate(true)
	node.set_admitted_cells(input.get("cells", []))
	var restored: Dictionary = Restore.instantiate(bank, node)
	node.prepared_geometry = restored.geometry
	node.prepared_materials = restored.materials
	for draw: GPUParticles3D in node.prepared_geometry: node.plumes.append(draw)
	node.stable_paths = bank.verified_stable_paths
	return node

func source_bindings() -> Dictionary:
	return Restore.bindings(self)

func prepare_source_layer_mask(mask: int) -> void:
	Restore.layers(self, mask)

func has_verified_stable_paths() -> bool:
	return stable_paths

func refresh_live_inputs(seconds: float) -> void:
	# No particle time is advanced here. The original source may admit/retire
	# emission only when a changed fact actually crosses its strength gate.
	# An unchanged active emitter is never restarted by Emitters.sample.
	sample(seconds)

const VfxPackageIO_97fb9af256 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
