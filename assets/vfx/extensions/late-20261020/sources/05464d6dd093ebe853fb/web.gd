extends "res://assets/vfx/extensions/late-20261020/sources/3c38ae43b109802734cd/reactive_web_lit.gd"
const Restore = preload("res://assets/vfx/extensions/late-20261020/sources/cb91ba2e7f30c0ed0811/restore.gd")
var prepared_geometry: Array = []
var prepared_materials: Array = []
var prepared_players: Array = []
var stable_paths := false

static func preparation_resources(input: Dictionary) -> Array:
	return [input.prepared_surface_bank]

static func make_component(input: Dictionary) -> Node3D:
	var node: Node3D = VfxPackageIO_05464d6dd0.resource("res://assets/vfx/extensions/late-20261020/sources/05464d6dd093ebe853fb/web.gd").new()
	node.settings = input.duplicate(true)
	node._build()
	return node

func _build() -> void:
	var bank: Resource = VfxPackageIO_05464d6dd0.resource(settings.prepared_surface_bank)
	var restored: Dictionary = Restore.instantiate(bank, self)
	prepared_geometry = restored.geometry
	prepared_materials = restored.materials
	material = restored.root.get_node(bank.web_field_path).material_override
	support_points.assign(bank.support_points)
	for path: NodePath in bank.particle_paths:
		flames.append(restored.root.get_node(path))
	set_transition_events(settings.get("events", []))
	stable_paths = bank.verified_stable_paths

func source_bindings() -> Dictionary:
	return Restore.bindings(self)

func prepare_source_layer_mask(mask: int) -> void:
	Restore.layers(self, mask)

func has_verified_stable_paths() -> bool:
	return stable_paths

func refresh_live_inputs(seconds: float) -> void:
	# Native committed-event gates remain causal. This samples the same source
	# clock, never a player/delta; only a genuinely new inactive->active source
	# gate can start emission. Duplicate held input cannot replay active fire.
	sample(seconds)

const VfxPackageIO_05464d6dd0 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
