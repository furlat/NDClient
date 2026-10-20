extends "res://assets/vfx/extensions/heavy-effects-20261020/sources/d707add0ebd05c501c49/fire_explosion_readable.gd"
## Original five native layers, readable edits, native Init/birth and committed
## event/restart semantics. Immutable construction alone moves offline.
const Restore = preload("res://assets/vfx/extensions/late-20261020/sources/cb91ba2e7f30c0ed0811/restore.gd")
var prepared_geometry: Array = []
var prepared_materials: Array = []
var prepared_players: Array = []
var stable_paths := false
var footprint_state := preload("res://assets/vfx/extensions/late-20261020/sources/044bd38b0183a2110147/footprint_state.gd").new()


static func preparation_resources(input: Dictionary) -> Array:
	return [input.prepared_payload_contact_bank]


static func make_component(input: Dictionary) -> Node3D:
	assert(input.kind == "delayed_fire")
	assert(not str(input.get("source_owner_uuid", "")).is_empty() and not str(input.get("original_caster_uuid", "")).is_empty())
	var node: Node3D = VfxPackageIO_b81d41aab7.resource("res://assets/vfx/extensions/heavy-effects-20261020/sources/b81d41aab78fa413036d/retirement_fire.gd").new()
	node.specification = input.duplicate(true)
	node.set_blast_event(input.get("event", {}))
	node.prepare()
	return node


func prepare() -> void:
	if explosion != null: return
	var bank: Resource = VfxPackageIO_b81d41aab7.resource(specification.prepared_payload_contact_bank)
	assert(bank.kind == "retirement_fire")
	var restored: Dictionary = Restore.instantiate(bank, self)
	prepared_geometry = restored.geometry
	prepared_materials = restored.materials
	explosion = restored.root.get_node(bank.splash_path)
	for material: ShaderMaterial in prepared_materials: explosion_materials.append(material)
	# The original canonical emitter defaults precede its exact original
	# play/advance0 commands. Serialized emitting=true is not a birth command.
	for index in bank.particle_paths.size():
		var emitter: GPUParticles3D = restored.root.get_node(bank.particle_paths[index])
		emitter.emitting = bank.particle_initial_emitting[index]
	var cells: Array = event.get("admitted_cells", specification.get("admitted_cells", []))
	_set_footprint_cells(cells)
	var player: AnimationPlayer = restored.root.get_node(bank.player_path)
	prepared_players.append(player)
	player.play("Init")
	player.advance(0.0)
	explosion.hide()
	stable_paths = bank.verified_stable_paths


func _set_footprint_cells(cells: Array) -> void:
	footprint_state.apply(explosion_materials, cells)


func source_bindings() -> Dictionary:
	return Restore.bindings(self)


func prepare_source_layer_mask(mask: int) -> void:
	Restore.layers(self, mask)


func has_verified_stable_paths() -> bool:
	return stable_paths


func refresh_live_inputs(seconds: float) -> void:
	# Original sample writes only the current blast origin, uniforms and visible
	# envelope; original event setters still own restarts and native player cues.
	sample(seconds)


func capture_observation() -> Dictionary:
	# The original readable observer assumes editable ParticleProcessMaterial.
	# Its native scale is already an explicit, proven generated-program operand;
	# preserve the observation without accessing that absent editable property.
	var process: ShaderMaterial = explosion.get_node("muzzle").process_material
	var scale_min: Variant = process.get_shader_parameter("scale_min")
	assert(typeof(scale_min) == TYPE_FLOAT, "Exact captured native flash scale operand required")
	return {"kind": specification.kind, "admitted_blast": event,
		"consumed_event_uuids": consumed.keys(), "rejection": rejection,
		"current_payload_origin": last_origin,
		"native_resolved_cell_count": event.get("admitted_cells", []).size(),
		"all_item_retirement_external": true, "computes_area_or_damage": false, "optical_lights": 0,
		"source_scene": EXPLOSION_SCENE, "native_emitter_layers": 5,
		"excluded_demo_layers": ["Decal", "OmniLight3D"], "seek_qualified": false,
		"native_flash_process_scale": scale_min, "native_volume_receiving_weight": .5,
		"cooling_ring_edge": "native age/noise with finite coverage band and gradual tail"}


const VfxPackageIO_b81d41aab7 = preload("res://assets/vfx/extensions/heavy-effects-20261020/scoped_resource_io.gd")
