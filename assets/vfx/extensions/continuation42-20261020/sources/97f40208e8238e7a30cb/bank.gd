extends "res://assets/vfx/extensions/late-20261020/sources/820df97b3292c59d68f5/bank.gd"
## Native skeleton/animation instances stay private. Only exact immutable source
## mesh/program/skin/animation data is shared; no posed timeline or layout bank.
@export var controllers: Array[Dictionary]=[]
@export var sites: Array[Dictionary]=[]
@export var geometry_paths: Array[NodePath]=[]
@export var players: Array[Dictionary]=[]
@export var light_paths: Array[NodePath]=[]
@export var composition_components: Dictionary={}
@export var composition_bindings: Array[Dictionary]=[]
@export var construction_inputs: Array[Dictionary]=[]
@export var construction_transforms: Array[Dictionary]=[]
const Profile=preload("res://assets/vfx/sources/5e6062cb1efe781a65b7/construction_profile.gd")
var restoration_fields: Array[Dictionary]=[]

func prepare_immutable_interface() -> void:
	if interface_ready:return
	# Exact original constructor fields below are always replaced by the
	# supplied private input. Compile out their dead baseline deep copies.
	var replaced:={NodePath("."):["definition"]}
	for binding in construction_inputs:
		if not replaced.has(binding.node):replaced[binding.node]=[]
		replaced[binding.node].append(binding.field)
	for record in controllers:
		Bindings.methods(record.script)
		var fields:={}
		for name in record.fields:
			if name not in replaced.get(record.node,[]):fields[name]=record.fields[name]
		restoration_fields.append(fields)
	super.prepare_immutable_interface()

func _decode(value: Dictionary, owner: Node3D, materials: Array, nodes: Dictionary) -> Variant:
	match String(value.kind):
		"literal":
			var actual: Variant=value.value
			return actual.duplicate(true) if actual is Array or actual is Dictionary else actual
		"node":
			var path: NodePath=value.path
			if not nodes.has(path):nodes[path]=owner.get_node(path)
			return nodes[path]
		"material":return materials[int(value.index)]
		"array":
			var result:=[]
			for item in value.values:result.append(_decode(item,owner,materials,nodes))
			return result
	assert(false,"Unknown exact controller-state operand")
	return null

func _input_at(input: Dictionary, path: Array) -> Variant:
	var value: Variant=input
	for key in path:value=value[key]
	return value

func restore(input: Dictionary) -> Node3D:
	assert(interface_ready,"Explicit immutable readiness precedes publication")
	Profile.begin("skeletal_scene_instantiation")
	var owner: Node3D=scene.instantiate()
	Profile.end("skeletal_scene_instantiation")
	Profile.begin("skeletal_private_materials")
	var private_materials:=[]
	for index in material_templates.size():private_materials.append(private_material(index))
	var nodes:={}
	for site in sites:
		var node: GeometryInstance3D=owner.get_node(site.node)
		nodes[site.node]=node
		if site.kind=="override":node.material_override=private_materials[site.material]
		else:
			assert(site.kind=="process" and node is GPUParticles3D)
			node.process_material=private_materials[site.material]
	Profile.end("skeletal_private_materials")
	Profile.begin("skeletal_controller_restoration")
	# Attach only audited original manual controllers (the root has the prepared
	# adapter). Their construction callbacks are bypassed by exact ready state.
	for record in controllers:
		var node: Node=owner.get_node(record.node)
		nodes[record.node]=node
		node.set_script(record.script)
	for index in controllers.size():
		var record: Dictionary=controllers[index]
		var node: Node=nodes[record.node]
		for name in restoration_fields[index]:
			var restored: Variant=_decode(restoration_fields[index][name],owner,private_materials,nodes)
			var existing: Variant=node.get(name)
			if existing is Array and restored is Array:existing.assign(restored)
			else:node.set(name,restored)
	Profile.end("skeletal_controller_restoration")
	Profile.begin("skeletal_actual_constructor_inputs")
	# Preserve original constructor input shape and per-owner cancellation facts.
	# Bank-fixed shader/mesh/rig choices require recipe regeneration, as usual.
	owner.definition=input.duplicate(true)
	owner.definition.erase("skeletal_sequence_bank")
	for binding in construction_inputs:
		var node: Node=owner.get_node(binding.node)
		var value: Variant=_input_at(input,binding.input_path)
		node.set(binding.field,value.duplicate(true) if value is Array or value is Dictionary else value)
	for binding in construction_transforms:
		var node: Node3D=owner.get_node(binding.node)
		var value: float=float(_input_at(input,binding.input_path))
		assert(value>0.)
		node.scale=Vector3.ONE/value
	Profile.end("skeletal_actual_constructor_inputs")
	Profile.begin("skeletal_native_bindings")
	var composition:=preload("res://assets/vfx/sources/628b95849d2163ba8eca/contract_composition.gd").new()
	for key in composition_components:composition.components[key]=owner.get_node(composition_components[key])
	for original in composition_bindings:
		var binding: Dictionary=original.duplicate(true)
		binding.node=composition.components[binding.component]
		composition.bindings.append(binding)
	owner.composition=composition
	owner.source_bank=self
	owner.prepared_geometry=geometry_paths.map(func(path):return owner.get_node(path))
	owner.prepared_materials=private_materials
	owner.prepared_players=[]
	for record in players:
		var player: AnimationPlayer=owner.get_node(record.node)
		# Native PackedScene does not persist runtime playback selection. Keep the
		# original exact clip/play/pause state; normal sampler owns advance(0).
		if not String(record.animation).is_empty():
			player.play(record.animation)
			player.seek(float(record.position),true)
			if record.paused:player.pause()
		owner.prepared_players.append(player)
	owner.prepared_lights=light_paths.map(func(path):return owner.get_node(path))
	Profile.end("skeletal_native_bindings")
	return owner
