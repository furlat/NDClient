extends "res://assets/vfx/extensions/late-20261020/sources/820df97b3292c59d68f5/bank.gd"
## One exact native hierarchy; every controller and actual native state is live.
const Composition = preload("res://assets/vfx/extensions/heavy-effects-20261020/sources/628b95849d2163ba8eca/contract_composition.gd")
const NativeRestore = preload("res://assets/vfx/extensions/heavy-effects-20261020/sources/ca69e9e47c9d66bb69fd/restore.gd")
const Profile = preload("res://assets/vfx/sources/5e6062cb1efe781a65b7/construction_profile.gd")
@export var controllers: Array[Dictionary] = []
@export var material_sites: Array[Dictionary] = []
@export var resource_prototypes: Array[Resource] = []
@export var composition_records: Array[Dictionary] = []
@export var geometry_paths: Array[NodePath] = []
@export var player_records: Array[Dictionary] = []
@export var light_paths: Array[NodePath] = []
@export var actual_input_bindings: Array[Dictionary] = []
@export var native_birth_commands: Array[Dictionary] = []
@export var immutable_process_indices: Array[int] = []
@export var family := ""
@export var retain_exact_animation_key_times := false
var restoration_fields: Array[Dictionary] = []


func prepare_immutable_interface() -> void:
	if interface_ready:
		return
	if retain_exact_animation_key_times:
		var restored: int = preload("res://assets/vfx/extensions/continuation42-20261020/sources/e39a2969814c1bbdbded/animation_key_times.gd").prepare_scene(scene)
		assert(restored > 0, "Actual native Guardian Animation key times must restore before publication")
	var replaced_fields: Dictionary = {}
	for binding: Dictionary in actual_input_bindings:
		if not replaced_fields.has(binding.node):
			replaced_fields[binding.node] = []
		replaced_fields[binding.node].append(binding.field)
	for record: Dictionary in controllers:
		Bindings.methods(record.script)
		var retained: Dictionary = {}
		for field: String in record.fields:
			if field not in replaced_fields.get(record.node, []):
				retained[field] = record.fields[field]
		restoration_fields.append(retained)
	super.prepare_immutable_interface()


func decode(record: Dictionary, owner: Node3D, materials: Array, resources: Array) -> Variant:
	match String(record.kind):
		"literal":
			var value: Variant = record.value
			if value is Array or value is Dictionary:
				return value.duplicate(true)
			if typeof(value) >= TYPE_PACKED_BYTE_ARRAY and typeof(value) <= TYPE_PACKED_VECTOR4_ARRAY:
				# Godot PackedArray objects obtained from Resource/Dictionary
				# fields retain shared storage identity. Mutable ripple/velocity
				# state needs an explicit private buffer; read-only topology has
				# its separate audited immutable record above.
				return value.duplicate()
			return value
		"immutable":
			return record.value
		"node":
			return owner.get_node(record.path)
		"material":
			return materials[int(record.index)]
		"resource_site":
			var node: Node = owner.get_node(record.path)
			return node.get(record.property)
		"material_site":
			return NativeRestore.resource_material(owner, record.binding)
		"resource":
			return resources[int(record.index)]
		"array":
			var values: Array = []
			for child: Dictionary in record.values:
				values.append(decode(child, owner, materials, resources))
			return values
	assert(false, "Unknown exact native composition state")
	return null


func input_at(input: Dictionary, path: Array) -> Variant:
	var value: Variant = input
	for key: Variant in path:
		value = value[key]
	return value


func restore(input: Dictionary) -> Node3D:
	assert(interface_ready, "Immutable native composition readiness must precede admission")
	Profile.begin("native_composition_scene_restore")
	var owner: Node3D = scene.instantiate()
	Profile.end("native_composition_scene_restore")
	Profile.begin("native_composition_material_restore")
	var materials: Array = []
	for index in material_templates.size():
		materials.append(material_templates[index] if index in immutable_process_indices else private_material(index))
	for site: Dictionary in material_sites:
		var draw: GeometryInstance3D = owner.get_node(site.node)
		match String(site.kind):
			"override":
				draw.material_override = materials[int(site.index)]
			"process":
				draw.process_material = materials[int(site.index)]
			_:
				assert(false, "Unknown exact prepared material site")
	var resources: Array = []
	for prototype: Resource in resource_prototypes:
		resources.append(prototype.duplicate(false))
	Profile.end("native_composition_material_restore")
	Profile.begin("native_composition_controller_restore")
	for record: Dictionary in controllers:
		var controller: Node = owner.get_node(record.node)
		controller.set_script(record.script)
	var late_setters: Array[Dictionary] = []
	for index in controllers.size():
		var record: Dictionary = controllers[index]
		var node: Node = owner.get_node(record.node)
		for field: String in restoration_fields[index]:
			var value: Variant = decode(restoration_fields[index][field], owner, materials, resources)
			if field == "visor_opacity":
				late_setters.append({"node": node, "field": field, "value": value})
				continue
			var current: Variant = node.get(field)
			if current is Array and value is Array:
				current.assign(value)
			else:
				node.set(field, value)
	for record: Dictionary in actual_input_bindings:
		var value: Variant = input_at(input, record.path)
		if value is Dictionary:
			value = value.duplicate(true)
			value.erase("prepared_native_composition_bank")
			value.merge(record.get("overrides", {}), true)
		elif value is Array:
			value = value.duplicate(true)
		owner.get_node(record.node).set(record.field, value)
	for record: Dictionary in late_setters:
		record.node.set(record.field, record.value)
	for record: Dictionary in composition_records:
		var actual: RefCounted = Composition.new()
		for key: String in record.components:
			actual.components[key] = owner.get_node(record.components[key])
		for original: Dictionary in record.bindings:
			var binding: Dictionary = original.duplicate(true)
			binding.node = actual.components[binding.component]
			actual.bindings.append(binding)
		owner.get_node(record.node).composition = actual
	Profile.end("native_composition_controller_restore")
	Profile.begin("native_composition_native_bindings")
	owner.prepared_bank = self
	owner.prepared_geometry = geometry_paths.map(func(path): return owner.get_node(path))
	owner.prepared_materials = materials
	owner.prepared_players = []
	for record: Dictionary in player_records:
		var player: AnimationPlayer = owner.get_node(record.node)
		if not String(record.animation).is_empty():
			player.play(record.animation)
			player.seek(float(record.position), true)
			if record.paused:
				player.pause()
		owner.prepared_players.append(player)
	owner.prepared_lights = light_paths.map(func(path): return owner.get_node(path))
	Profile.end("native_composition_native_bindings")
	return owner


func apply_consumer_callback_policy(owner: Node3D) -> void:
	# Tree entry automatically enables overridden native callbacks. Apply the
	# original conservative registration policy after descendant admission, at
	# the prepared root's ready boundary and before its first public sample0.
	# Explicit sample/lifecycle calls and registered native players are intact.
	assert(owner.is_inside_tree())
	for record: Dictionary in controllers:
		var controller: Node = owner.get_node(record.node)
		controller.set_process(false)
		controller.set_physics_process(false)


func replay_native_birth(owner: Node3D) -> void:
	# Exactly audited original fixed-seed commands, at their original live-tree
	# boundary. No restart, invented random baseline or emission setter.
	assert(owner.is_inside_tree())
	for record: Dictionary in native_birth_commands:
		var emitter: GPUParticles3D = owner.get_node(record.node)
		assert(emitter.is_inside_tree() and emitter.use_fixed_seed == record.before_fixed)
		emitter.use_fixed_seed = true
		emitter.seed = int(record.authored_seed)
