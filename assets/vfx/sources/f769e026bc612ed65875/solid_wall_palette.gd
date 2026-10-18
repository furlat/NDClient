extends "res://assets/vfx/sources/41bda60be893f43ae18e/solid_wall.gd"
## Retain the actual quarry geometry/UV while restoring its selected brown finish.
const SourcePalette = preload("res://assets/vfx/sources/78d0d61e6bbc2955588b/source_nearest_palette.gd")

static func make_component(input: Dictionary) -> Node3D:
	assert(input.settings.kind == "stone", "This candidate restores the documented non-emissive stone finish only")
	return construct("res://assets/vfx/sources/f769e026bc612ed65875/solid_wall_palette.gd", input)

func make_material(index: int, core: bool) -> ShaderMaterial:
	var material := super.make_material(index, core)
	SourcePalette.apply(material, parameters.finishing)
	return material
