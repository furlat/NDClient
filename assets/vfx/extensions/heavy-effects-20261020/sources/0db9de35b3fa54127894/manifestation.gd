extends "res://assets/vfx/extensions/heavy-effects-20261020/sources/ce2988340441bc57f566/manifestation.gd"
## Same admitted birth/terminal controller, live endpoints and owner state.
## Native analytical ribbon/mote sources are prepared, never owner snapshots.

static func preparation_resources(input: Dictionary) -> Array:
	var paths := []
	for entry in input.entries:
		for path in Composition.preparation_resources(entry.composition):
			if path not in paths: paths.append(path)
	return paths

static func make_component(input: Dictionary) -> Node3D:
	assert(not str(input.owner_uuid).is_empty() and not str(input.birth_event_uuid).is_empty())
	var node: Node3D = VfxPackageIO_0db9de35b3.resource("res://assets/vfx/extensions/heavy-effects-20261020/sources/0db9de35b3fa54127894/manifestation.gd").new()
	node.specification = input.duplicate(true)
	for entry in input.entries:
		var piece_root := Node3D.new()
		piece_root.name = entry.id
		piece_root.top_level = true
		piece_root.scale = Vector3.ONE * float(entry.scale)
		node.add_child(piece_root)
		var composition := Composition.new()
		var issue := composition.make(piece_root, entry.composition)
		assert(issue.is_empty(), issue)
		# The prepared leaf is analytical. This is the original controller's
		# initial age-zero sample, not a hidden warmed occurrence.
		composition.sample(0.0)
		var declared := composition.source_bindings()
		assert(not declared.is_empty())
		piece_root.hide()
		node.pieces.append({"root":piece_root,"composition":composition,
			"definition":entry.duplicate(true),"materials":SourceSpace.adapt_materials(declared.materials)})
	return node

func has_verified_stable_paths() -> bool:
	if pieces.is_empty(): return false
	for piece in pieces:
		for component in piece.composition.components.values():
			if not component.get_meta("summoning_verified_stable_paths", false): return false
	return true

func source_bindings() -> Dictionary:
	var result := {"geometry":[],"materials":[],"lights":[],"static_material_topology":true,"static_geometry_layers":true}
	for piece in pieces:
		var declared: Dictionary = piece.composition.source_bindings()
		for field in ["geometry","materials"]:
			result[field].append_array(declared[field])
	return result

func refresh_live_inputs(seconds: float) -> void:
	# Owner/endpoint admission is analytical; no native particle/player replay.
	sample(seconds)

const VfxPackageIO_0db9de35b3 = preload("res://assets/vfx/extensions/heavy-effects-20261020/scoped_resource_io.gd")
