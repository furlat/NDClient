extends "res://assets/vfx/sources/0738ff2d24aa41b1b963/native_review_composition.gd"
## Existing composition rules and source transform remain authoritative.
const PreparedRestore = preload("res://assets/vfx/sources/ca69e9e47c9d66bb69fd/restore.gd")
static func make_component(input: Dictionary) -> Node3D:
	var node: Node3D = VfxPackageIO_d620b1c37a.resource("res://assets/vfx/sources/d620b1c37ac78f6f614f/composition.gd").new()
	node.definition = input.duplicate(true)
	return node

static func preparation_resources(input: Dictionary) -> Array:
	return Composition.preparation_resources(input)

func source_bindings() -> Dictionary:
	return composition.source_bindings() if composition != null else {}

func has_verified_stable_paths() -> bool:
	if composition == null or composition.components.is_empty():
		return false
	for key in composition.components:
		var component: Node = composition.components[key]
		if String(component.name) != String(key) or not PreparedRestore.has_verified_stable_paths(component):
			return false
	return true

func prepare_source_interfaces() -> Array:
	# These exact source-space/opacity programs were prepared on the selected
	# source; retain original owner transform writes without rewalking textures.
	var result := []
	for component in composition.components.values():
		assert(component.has_meta("prepared_world_source_materials"))
		for material in component.get_meta("prepared_world_source_materials"):
			if material not in result: result.append(material)
	return result

const VfxPackageIO_d620b1c37a = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
