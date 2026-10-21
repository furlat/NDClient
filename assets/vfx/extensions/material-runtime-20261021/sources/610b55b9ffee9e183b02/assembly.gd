extends "res://assets/vfx/extensions/material-runtime-20261021/sources/f95a9864b1f165d83f44/timed_assembly.gd"
## Preserve all six original selections and their exact timed composition.
const PreparedRestore = preload("res://assets/vfx/extensions/material-runtime-20261021/sources/35243558c7ef77ec849b/restore.gd")
var source_call_fit := preload("res://assets/vfx/extensions/continuation42-20261020/sources/5bfb0a8d6113c8a6470c/body_fit.gd").new()


static func preparation_resources(input: Dictionary) -> Array:
	var paths := []
	for entry: Dictionary in input.entries:
		for specification: Dictionary in entry.composition.components:
			var path: String = specification.input.prepared_recipient_bank
			if path not in paths:
				paths.append(path)
	return paths


static func make_component(input: Dictionary) -> Node3D:
	var node: Node3D = VfxPackageIO_610b55b9ff.resource("res://assets/vfx/extensions/material-runtime-20261021/sources/610b55b9ffee9e183b02/assembly.gd").new()
	node.selections = input.entries.duplicate(true)
	node.opacity_control = input.get("opacity_control",false)
	return node


func sample(seconds: float) -> void:
	if not prepared:
		_prepare()
	source_call_fit.clear()
	for entry: Dictionary in entries:
		for component in entry.composition.components.values():
			component.source_call_fit = source_call_fit
	super.sample(seconds)
	# The packet and all transforms are released before returning to the owner.
	source_call_fit.clear()


func refresh_live_inputs(seconds: float) -> void:
	sample(seconds)


func source_bindings() -> Dictionary:
	# The old generic assembly collector predates declared native players.
	# Keep every real child player rather than freezing its emission keys.
	var result := {"geometry":[],"materials":[],"lights":[],"players":[],
		"static_material_topology":true,"static_geometry_layers":true}
	for entry: Dictionary in entries:
		var declared: Dictionary = entry.composition.source_bindings()
		if declared.is_empty():
			return {}
		result.static_geometry_layers = result.static_geometry_layers and declared.get("static_geometry_layers",false)
		for field in ["geometry","materials","lights","players"]:
			for value in declared.get(field,[]):
				if value not in result[field]:
					result[field].append(value)
	return result


func has_verified_stable_paths() -> bool:
	if not prepared or entries.size() != selections.size():
		return false
	for entry: Dictionary in entries:
		for component in entry.composition.components.values():
			if not PreparedRestore.stable_paths(component):
				return false
	return true

const VfxPackageIO_610b55b9ff = preload("res://assets/vfx/extensions/material-runtime-20261021/scoped_resource_io.gd")
