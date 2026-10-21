extends Node3D
## Common native summon manifestation, separate from the summoned entity body.
## Birth/terminal UUIDs, owner visibility and positions are supplied facts.
const Composition = preload("res://assets/vfx/extensions/material-runtime-20261021/sources/628b95849d2163ba8eca/contract_composition.gd")
const SourceSpace = preload("res://assets/vfx/sources/6487dfcacdbd7bcc9361/native_source_space.gd")
const ResourceGraph = preload("res://assets/vfx/sources/1d02b6d800655ef86df2/resource_graph.gd")

var specification: Dictionary = {}
var endpoints: Array = []
var supplied_state: Dictionary = {}
var pieces: Array = []
var local_clock := 0.0

static func make_component(input: Dictionary) -> Node3D:
	assert(not str(input.owner_uuid).is_empty())
	assert(not str(input.birth_event_uuid).is_empty())
	var effect: Node3D = VfxPackageIO_ce29883404.resource("res://assets/vfx/extensions/material-runtime-20261021/sources/ce2988340441bc57f566/manifestation.gd").new()
	effect.specification = input.duplicate(true)
	for entry in input.entries:
		var root := Node3D.new()
		root.name = entry.id
		root.top_level = true
		root.scale = Vector3.ONE * float(entry.scale)
		effect.add_child(root)
		var composition := Composition.new()
		ResourceGraph.native_sampler_scopes += 1
		var issue := composition.make(root, entry.composition)
		composition.sample(0.0)
		ResourceGraph.native_sampler_scopes -= 1
		assert(issue.is_empty(), issue)
		var materials := SourceSpace.adapt(root, {}, [])
		root.hide()
		effect.pieces.append({"root": root, "composition": composition,
			"definition": entry.duplicate(true), "materials": materials})
	return effect

func set_live_endpoints(value: Array) -> void:
	endpoints = value.duplicate(true)
	sample(local_clock)

func set_owner_state(value: Dictionary) -> bool:
	if str(value.get("owner_uuid", "")) != str(specification.owner_uuid):
		return false
	supplied_state = value.duplicate(true)
	sample(local_clock)
	return true

func sample(seconds: float) -> void:
	local_clock = seconds
	var state: Dictionary = specification.initial_state.duplicate(true)
	for change in specification.get("review_states", []):
		if seconds >= float(change.seconds):
			state.merge(change.state, true)
	if not supplied_state.is_empty():
		state = supplied_state.duplicate(true)
	var observed: bool = str(state.get("owner_uuid", "")) == str(specification.owner_uuid)
	observed = observed and bool(state.get("observed", false)) and not bool(state.get("suppressed", true))
	for piece in pieces:
		var definition: Dictionary = piece.definition
		var born: bool = bool(state.get("birth_admitted", false))
		var begin: float = definition.begin_seconds
		if definition.kind == "terminal":
			born = not str(state.get("terminal_event_uuid", "")).is_empty()
			begin = float(state.get("terminal_started_at_seconds", INF))
		var age := seconds - begin
		piece.root.visible = observed and born and age >= 0.0 and age < float(definition.seconds)
		var index: int = definition.endpoint_index
		if index < 0 or index >= endpoints.size():
			piece.root.hide()
			continue
		piece.root.global_transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * float(definition.scale)), endpoints[index].point)
		# Source clocks keep advancing under suppression; restoring an old owner
		# cannot replay its already-finished birth or create a terminal event.
		if born and age >= 0.0:
			ResourceGraph.native_sampler_scopes += 1
			piece.composition.sample(minf(age, float(definition.seconds)))
			ResourceGraph.native_sampler_scopes -= 1
		if not piece.has("last_source_transform") or piece.last_source_transform!=piece.root.global_transform:
			piece.last_source_transform=piece.root.global_transform
			for material in piece.materials:
				material.set_shader_parameter("factory_world_to_source", piece.root.global_transform.affine_inverse())

func capture_observation() -> Dictionary:
	var visible: Array = []
	for piece in pieces:
		if piece.root.visible:
			visible.append(piece.definition.id)
	return {"summon_manifestation": {"owner_uuid": specification.owner_uuid,
		"birth_event_uuid": specification.birth_event_uuid, "clock": local_clock,
		"visible_parts": visible, "form": specification.form,
		"body_is_separate": true, "body_binding_available": false,
		"optical_lights": 0, "lifetime_is_supplied": true}}

const VfxPackageIO_ce29883404 = preload("res://assets/vfx/extensions/material-runtime-20261021/scoped_resource_io.gd")
