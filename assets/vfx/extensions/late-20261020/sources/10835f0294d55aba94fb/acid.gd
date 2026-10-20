extends "res://assets/vfx/extensions/late-20261020/sources/4a37178235b24c862238/acid_splash_mass.gd"
## Original causal admission, source AnimationPlayer and all source motion stay
## live. Only immutable shader/material/geometry construction moves offline.
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
	assert(input.kind == "acid")
	assert(not str(input.get("source_owner_uuid", "")).is_empty())
	assert(not str(input.get("original_caster_uuid", "")).is_empty())
	var node: Node3D = VfxPackageIO_10835f0294.resource("res://assets/vfx/extensions/late-20261020/sources/10835f0294d55aba94fb/acid.gd").new()
	node.specification = input.duplicate(true)
	node.set_blast_event(input.get("event", {}))
	node.prepare()
	return node

func prepare() -> void:
	if splash != null: return
	var bank: Resource = VfxPackageIO_10835f0294.resource(specification.prepared_payload_bank)
	var restored: Dictionary = Restore.instantiate(bank, self)
	prepared_geometry = restored.geometry
	prepared_materials = restored.materials
	splash = restored.root.get_node(bank.splash_path)
	for index in bank.material_paths.size():
		var draw: GeometryInstance3D = prepared_geometry[index]
		if draw is GPUParticles3D: splash_materials.append(prepared_materials[index])
	for path: NodePath in bank.liquid_paths:
		var draw: MeshInstance3D = restored.root.get_node(path)
		liquid_draws.append(draw)
		liquid_materials.append(draw.material_override)
	# The original donor starts all six emitters false, then Init.advance(0)
	# starts spheres before tree entry. Replay that exact native setter edge,
	# rather than confusing serialized `emitting=true` with one-shot birth.
	for index in bank.particle_paths.size():
		var emitter: GPUParticles3D = restored.root.get_node(bank.particle_paths[index])
		emitter.emitting = bank.particle_initial_emitting[index]
	var player: AnimationPlayer = restored.root.get_node(bank.player_path)
	prepared_players.append(player)
	var cells: Array = event.get("admitted_cells", specification.get("admitted_cells", []))
	apply_footprint_cells(prepared_materials, cells)
	player.stop()
	player.play("Init")
	player.advance(0.0)
	splash.hide()
	stable_paths = bank.verified_stable_paths

func apply_footprint_cells(selected_materials: Array, cells: Array) -> void:
	footprint.apply(selected_materials, cells)

func source_bindings() -> Dictionary:
	return Restore.bindings(self)

func refresh_live_inputs(seconds: float) -> void:
	# These inherited methods write only owner placement, footprint origin and
	# draw clocks/alpha. Native players/emitter delta/restart stay sampler-owned.
	sample(seconds)

func prepare_source_layer_mask(mask: int) -> void:
	Restore.layers(self, mask)

func has_verified_stable_paths() -> bool:
	return stable_paths

const VfxPackageIO_10835f0294 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
