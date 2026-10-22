extends "res://assets/vfx/extensions/spirit-receiver-20261022/sources/c297559f1adfaacc1e0c/field_queued.gd"
## Preparation-only wrapper. The actual owner/controller stays the frozen class.
const Original = preload("res://assets/vfx/extensions/spirit-receiver-20261022/sources/c297559f1adfaacc1e0c/field_queued.gd")


static func preparation_resources(input: Dictionary) -> Array:
	var paths := Original.preparation_resources(input)
	paths.append(input.prepared_area_mask_bank)
	return paths


static func make_component(input: Dictionary) -> Node3D:
	return Original.make_component(input)
