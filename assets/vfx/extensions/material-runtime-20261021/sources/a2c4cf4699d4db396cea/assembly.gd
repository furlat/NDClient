extends "res://assets/vfx/extensions/material-runtime-20261021/sources/425491fe00d93a21a92e/assembly.gd"
## Same generic timed source and private draw state; raw-operand immutable banks.


static func preparation_resources(input: Dictionary) -> Array:
	var paths: Array = []
	for entry: Dictionary in input.entries:
		for specification: Dictionary in entry.composition.components:
			var path: String = specification.input.prepared_recipient_bank
			if path not in paths:
				paths.append(path)
	return paths


static func make_component(input: Dictionary) -> Node3D:
	assert(not input.get("opacity_control", false), "The audited source has no outer opacity writer")
	var node: Node3D = VfxPackageIO_a2c4cf4699.resource("res://assets/vfx/extensions/material-runtime-20261021/sources/a2c4cf4699d4db396cea/assembly.gd").new()
	node.selections = input.entries.duplicate(true)
	node.opacity_control = false
	return node

const VfxPackageIO_a2c4cf4699 = preload("res://assets/vfx/extensions/material-runtime-20261021/scoped_resource_io.gd")
