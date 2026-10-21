extends Node3D
## One witnessed finite ground departure. Arrival/body state is not constructed.
const Composition = preload("res://assets/vfx/extensions/material-runtime-20261021/sources/628b95849d2163ba8eca/contract_composition.gd")
const SourceSpace = preload("res://assets/vfx/sources/6487dfcacdbd7bcc9361/native_source_space.gd")
const ResourceGraph = preload("res://assets/vfx/sources/1d02b6d800655ef86df2/resource_graph.gd")
var specification: Dictionary = {}
var composition: RefCounted
var piece_root: Node3D
var materials: Array = []
var endpoints: Array = []
var witness: Dictionary = {}
var admitted := false
var owner_uuid := ""
var terminal_occurrence := -1
var terminal_cause := ""
var terminal_started_at_seconds := 0.0
var departure_point := Vector3.ZERO
var local_clock := 0.0
var source_age := -INF
var suppressed := false


static func preparation_resources(input: Dictionary) -> Array:
	return Composition.preparation_resources(input.entry.composition)


static func make_component(input: Dictionary) -> Node3D:
	assert(input.entry.kind == "terminal", "A terminal source never constructs an arrival entry")
	assert(float(input.entry.seconds) > 0.0 and is_finite(float(input.entry.seconds)))
	var node: Node3D = VfxPackageIO_fbfea3bf1c.resource("res://assets/vfx/extensions/material-runtime-20261021/sources/fbfea3bf1c0992d05896/terminal.gd").new()
	node.specification = input.duplicate(true)
	node.owner_uuid = str(input.get("owner_uuid", ""))
	node.piece_root = Node3D.new()
	node.piece_root.name = str(input.entry.id)
	node.piece_root.top_level = true
	node.piece_root.scale = Vector3.ONE * float(input.entry.scale)
	node.add_child(node.piece_root)
	node.composition = Composition.new()
	var issue: String = node.composition.make(node.piece_root, input.entry.composition)
	assert(issue.is_empty(), issue)
	node.composition.sample(0.0)
	var declared: Dictionary = node.composition.source_bindings()
	assert(not declared.is_empty())
	node.materials = SourceSpace.adapt_materials(declared.materials)
	node.piece_root.hide()
	return node


func set_live_endpoints(value: Array) -> void:
	if admitted:
		return
	endpoints = value.duplicate(true)
	_try_admit()
	sample(local_clock)


func set_terminal_departure(value: Dictionary) -> bool:
	# terminal_departure is the actual public completed/uncanceled terminal fact.
	# terminal_cause is disclosed only for a visually witnessed departure.
	var actor: Variant = value.get("entity_uuid")
	var occurrence: Variant = value.get("terminal_occurrence")
	var cause: Variant = value.get("terminal_cause")
	var started: Variant = value.get("terminal_started_at_seconds")
	if typeof(actor) not in [TYPE_STRING, TYPE_STRING_NAME] or str(actor).is_empty():
		return false
	if typeof(occurrence) != TYPE_INT or occurrence < 0:
		return false
	if typeof(cause) not in [TYPE_STRING, TYPE_STRING_NAME] or str(cause).is_empty():
		return false
	if not owner_uuid.is_empty() and actor != owner_uuid:
		return false
	if value.get("kind") != "spatial" or value.get("change_type") != "entity_left":
		return false
	if typeof(value.get("terminal_departure")) != TYPE_BOOL or not value.terminal_departure:
		return false
	if typeof(started) not in [TYPE_FLOAT, TYPE_INT] or not is_finite(float(started)):
		return false
	if admitted:
		return occurrence == terminal_occurrence and str(cause) == terminal_cause and float(started) == terminal_started_at_seconds
	if not witness.is_empty() and (occurrence != witness.terminal_occurrence or float(started) != float(witness.terminal_started_at_seconds)):
		return false
	owner_uuid = str(actor)
	witness = value.duplicate(true)
	_try_admit()
	sample(local_clock)
	return true


func set_owner_state(value: Dictionary) -> bool:
	if owner_uuid.is_empty() or str(value.get("owner_uuid", "")) != owner_uuid:
		return false
	# Actor absence/sight loss cannot erase an already witnessed ground accent.
	# Explicit optical suppression hides it while the original source age advances.
	if value.has("suppressed"):
		if typeof(value.suppressed) != TYPE_BOOL:
			return false
		suppressed = value.suppressed
	sample(local_clock)
	return true


func _try_admit() -> void:
	if admitted or witness.is_empty() or endpoints.size() != 1:
		return
	if not endpoints[0] is Dictionary:
		return
	var point: Variant = endpoints[0].get("point")
	if not point is Vector3 or not point.is_finite():
		return
	departure_point = point
	terminal_occurrence = witness.terminal_occurrence
	terminal_cause = str(witness.terminal_cause)
	terminal_started_at_seconds = float(witness.terminal_started_at_seconds)
	admitted = true
	endpoints.clear()
	witness.clear()
	var transform := Transform3D(
		Basis.IDENTITY.scaled(Vector3.ONE * float(specification.entry.scale)), departure_point)
	if piece_root.is_inside_tree():
		piece_root.global_transform = transform
	else:
		piece_root.transform = transform
	for material: ShaderMaterial in materials:
		material.set_shader_parameter("factory_world_to_source", transform.affine_inverse())


func sample(seconds: float) -> void:
	if not is_finite(seconds):
		piece_root.hide()
		return
	local_clock = seconds
	if not admitted:
		piece_root.hide()
		return
	source_age = seconds - terminal_started_at_seconds
	var duration := float(specification.entry.seconds)
	piece_root.visible = not suppressed and source_age >= 0.0 and source_age < duration
	if source_age >= 0.0:
		ResourceGraph.native_sampler_scopes += 1
		composition.sample(minf(source_age, duration))
		ResourceGraph.native_sampler_scopes -= 1


func refresh_live_inputs(seconds: float) -> void:
	sample(seconds)


func source_bindings() -> Dictionary:
	return composition.source_bindings()


func has_verified_stable_paths() -> bool:
	for component: Node3D in composition.components.values():
		if not component.get_meta("summoning_verified_stable_paths", false):
			return false
	return not composition.components.is_empty()


func capture_observation() -> Dictionary:
	return {"summon_terminal": {"owner_uuid": owner_uuid, "terminal_occurrence": terminal_occurrence,
		"terminal_cause": terminal_cause,
		"admitted": admitted, "clock": local_clock, "source_age": source_age,
		"visible": piece_root.visible, "departure_point": departure_point,
		"form": specification.form, "birth_required": false, "body_required": false}}

const VfxPackageIO_fbfea3bf1c = preload("res://assets/vfx/extensions/material-runtime-20261021/scoped_resource_io.gd")
