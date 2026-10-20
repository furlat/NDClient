extends "res://assets/vfx/extensions/heavy-effects-20261020/sources/f95a9864b1f165d83f44/timed_assembly.gd"
## Keep the selected timeline/orbits/live endpoint contract unchanged.
static func preparation_resources(input: Dictionary) -> Array:
	var paths := []
	for entry in input.entries:
		for path in Composition.preparation_resources(entry.composition):
			if path not in paths: paths.append(path)
	return paths

static func make_component(input: Dictionary) -> Node3D:
	var node: Node3D = VfxPackageIO_c7a11212a2.resource("res://assets/vfx/extensions/heavy-effects-20261020/sources/c7a11212a250b9affac2/assembly.gd").new()
	node.selections = input.entries.duplicate(true)
	node.opacity_control = input.get("opacity_control", false)
	return node

func has_verified_stable_paths() -> bool:
	if not prepared or entries.is_empty(): return false
	for entry in entries:
		for component in entry.composition.components.values():
			if not component.get_meta("summoning_verified_stable_paths", false): return false
	return true

func refresh_live_inputs(seconds: float) -> void:
	# This family is analytical and has no native particles/players. Original
	# sample() updates current endpoints and world uniforms at the same tick.
	sample(seconds)

const VfxPackageIO_c7a11212a2 = preload("res://assets/vfx/extensions/heavy-effects-20261020/scoped_resource_io.gd")
