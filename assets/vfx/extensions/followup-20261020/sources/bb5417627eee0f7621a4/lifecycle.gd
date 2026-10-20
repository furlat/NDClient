extends "res://assets/vfx/sources/7449f867b8ff0e78c354/fireball_turbulence.gd"
## Complete original source/native Init, only construction and repeated pure
## clock writes prepared. World-space particle units remain live per owner.
const UnitState = preload("res://assets/vfx/extensions/followup-20261020/sources/7a626a58244915b1d09e/native_units.gd")
const BankProfile = preload("res://assets/vfx/sources/5e6062cb1efe781a65b7/construction_profile.gd")
var source_bank: Resource
var prepared_geometry: Array = []
var prepared_materials: Array = []
var prepared_players: Array = []
var prepared_lights: Array = []
var world_process_materials: Array = []
var previous_unit_scale := 1.0

static func preparation_resources(input: Dictionary) -> Array:
	return [input.prepared_fireball_bank]

static func make_component(input: Dictionary) -> Node3D:
	var bank: Resource = VfxPackageIO_bb5417627e.resource(input.prepared_fireball_bank)
	assert(bank != null and bank.interface_ready)
	var node: Node3D = VfxPackageIO_bb5417627e.resource("res://assets/vfx/extensions/followup-20261020/sources/bb5417627eee0f7621a4/lifecycle.gd").new()
	node.source_bank = bank
	node.parameters = input.duplicate(true)
	node.settings = input.settings.duplicate(true)
	node.side = input.side
	BankProfile.begin("fireball_scene_instantiate")
	node.subject = bank.scene.instantiate()
	BankProfile.end("fireball_scene_instantiate")
	BankProfile.begin("fireball_private_material_restore")
	var private_materials := {}
	for index in bank.sites.size():
		var site: Dictionary = bank.sites[index]
		var target: GeometryInstance3D = node.subject.get_node(site.node)
		var canonical: int = bank.canonical_indices[index]
		if not private_materials.has(canonical): private_materials[canonical] = bank.private_material(canonical)
		var material: ShaderMaterial = private_materials[canonical]
		if site.kind == "process": target.process_material = material
		else:
			assert(site.kind == "override")
			target.material_override = material
		node.prepared_materials.append(material)
	for index in bank.clock_indices: node.materials.append(node.prepared_materials[index])
	for index in bank.detail_indices: node.detail_materials.append(node.prepared_materials[index])
	for record in bank.world_process_units:
		if not record.operator.is_empty():
			node.world_process_materials.append(UnitState.new(node.prepared_materials[record.index], record.operator))
	for field in bank.runtime_values: node.set(field, bank.runtime_values[field].duplicate(true) if bank.runtime_values[field] is Array or bank.runtime_values[field] is Dictionary else bank.runtime_values[field])
	node.seeds = bank.seed_records.duplicate(true)
	node.prepared_geometry = node.subject.find_children("*", "GeometryInstance3D", true, false)
	for path in bank.player_paths: node.prepared_players.append(node.subject.get_node(path))
	for path in bank.light_paths: node.prepared_lights.append(node.subject.get_node(path))
	node.add_child(node.subject)
	node.prepared = true
	BankProfile.end("fireball_private_material_restore")
	return node

func source_bindings() -> Dictionary:
	return {"geometry": prepared_geometry, "materials": prepared_materials,
		"players": prepared_players, "lights": prepared_lights,
		"static_material_topology": true, "static_geometry_layers": true}

func prepare_source_layer_mask(mask: int) -> void:
	assert(not is_inside_tree() and mask > 0)
	for draw: GeometryInstance3D in prepared_geometry:
		if draw.layers != 0 and draw.layers != mask: draw.layers = mask

func has_verified_stable_paths() -> bool:
	return source_bank.verified_stable_paths

func _refresh_units() -> void:
	var scale_value := global_basis.get_scale().x
	# Repeated unchanged scale reaches the same legacy fixed point after one
	# complete restore/apply. The bounded native witness tests every field.
	if scale_value == previous_unit_scale: return
	for operator in world_process_materials: operator.advance(scale_value)
	previous_unit_scale = scale_value

func refresh_live_inputs(_seconds: float) -> void:
	# The original sampler's held-age path does not rerun particle unit setters.
	# Node placement still follows the real root; preserve its submitted native
	# process operands/delta/player until the next advancing source sample.
	pass

func sample(seconds: float) -> void:
	_refresh_units()
	if not initialized:
		initialized = true
		var matched: bool = settings.animation.is_empty()
		for player: AnimationPlayer in prepared_players:
			if parameters.get("refresh_animation_caches", false): player.clear_caches()
			if settings.animation.is_empty(): continue
			assert(player.has_animation(settings.animation), "Prepared native Init changed")
			player.play(settings.animation)
			matched = true
		assert(matched)
	var desired := roundi(seconds * float(parameters.simulation_hz))
	if tick >= desired: return
	# Audited source ancestors only increment tick and overwrite source_clock /
	# fireball_detail_age. Evaluate their exact final write, not144 redundant
	# intermediate writes. Native players and GPU particles are advanced by the
	# unchanged sampler with the actual requested delta, not by this callback.
	tick = desired - 1
	advance_lifecycle(1.0 / float(parameters.simulation_hz))

const VfxPackageIO_bb5417627e = preload("res://assets/vfx/extensions/followup-20261020/scoped_resource_io.gd")
