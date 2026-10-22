extends "res://assets/vfx/extensions/spirit-receiver-20261022/sources/aa6d31e0db538a4bab5e/assembly.gd"
## Exact existing stable leaf paths; no per-draw native path discovery.


static func preparation_resources(input: Dictionary) -> Array:
	return preload("res://assets/vfx/extensions/spirit-receiver-20261022/sources/aa6d31e0db538a4bab5e/assembly.gd").preparation_resources(input)


static func make_component(input: Dictionary) -> Node3D:
	var node: Node3D = VfxPackageIO_8086f5cea7.resource("res://assets/vfx/extensions/spirit-receiver-20261022/sources/8086f5cea73028bb1c00/path_assembly.gd").new()
	node.selections = input.entries.duplicate(true)
	node.opacity_control = input.get("opacity_control", false)
	return node


func _prepare() -> void:
	super._prepare()
	var paths := PackedStringArray()
	for entry: Dictionary in entries:
		# This opt-in source family has exactly one prepared leaf per entry.
		# Unknown future compositions retain the conservative existing path.
		if entry.composition.components.size() != 1:
			return
		var leaf: Node3D = entry.composition.components.values()[0]
		if not leaf.has_meta("prepared_timed_bank") or not leaf.has_meta("prepared_timed_subject"):
			return
		var bank: Resource = leaf.get_meta("prepared_timed_bank")
		if not bank.stable_paths_prepared:
			return
		var subject: Node3D = leaf.get_meta("prepared_timed_subject")
		var prefix := str(get_path_to(subject))
		for path: NodePath in bank.geometry_paths:
			var relative := str(path).trim_prefix("./")
			paths.append(prefix if relative == "." else prefix + "/" + relative)
	if paths.size() == cached_bindings.geometry.size():
		cached_bindings.geometry_paths = paths

const VfxPackageIO_8086f5cea7 = preload("res://assets/vfx/extensions/spirit-receiver-20261022/scoped_resource_io.gd")
