extends "res://assets/vfx/extensions/spirit-runtime-20261021/sources/c2cdc14a1757aa6e9391/field_v3.gd"
## These two existing leaf hooks return only their explicit prepared bank path.
## Queue the actual Scripts before those banks instead of loading them during discovery.
const Assembly = preload("res://assets/vfx/extensions/spirit-runtime-20261021/sources/aa6d31e0db538a4bab5e/assembly.gd")
const PIECE := "res://assets/vfx/extensions/spirit-runtime-20261021/sources/07c3d3a385610f2f36bc/piece_v3.gd"
const GROUND := "res://assets/vfx/extensions/spirit-runtime-20261021/sources/7e3b80c759ba5063bd33/flow_hold.gd"


static func preparation_resources(input: Dictionary) -> Array:
	var paths: Array = []
	for entry: Dictionary in input.entries:
		var components: Array = entry.composition.components
		if components.size() != 1:
			return Assembly.preparation_resources(input)
		var leaf: Dictionary = components[0]
		if leaf.script not in [PIECE, GROUND]:
			return Assembly.preparation_resources(input)
		var bank: Variant = leaf.input.get("prepared_recipient_bank")
		if not bank is String or not bank.begins_with("res://"):
			return Assembly.preparation_resources(input)
		for path: String in [leaf.script, bank]:
			if path not in paths:
				paths.append(path)
	return paths


static func make_component(input: Dictionary) -> Node3D:
	if str(input.get("owner_uuid", "")).is_empty():
		return null
	var node: Node3D = VfxPackageIO_c297559f1a.resource("res://assets/vfx/extensions/spirit-runtime-20261021/sources/c297559f1adfaacc1e0c/field_queued.gd").new()
	node.owner_uuid = input.owner_uuid
	node.selections = input.entries.duplicate(true)
	node.opacity_control = input.get("opacity_control", false)
	return node

const VfxPackageIO_c297559f1a = preload("res://assets/vfx/extensions/spirit-runtime-20261021/scoped_resource_io.gd")
