extends "res://assets/vfx/sources/a0c9b57365844320e9a9/elemental_shield_readable.gd"
## Follow-up colour balance; the full source shield/contact layers are retained.


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/d90168cefe58abda9ad9/elemental_shield_contact.gd", input)


func ramp(cold: bool, line: bool = false) -> GradientTexture1D:
	var texture: GradientTexture1D = super.ramp(cold, line)
	if not cold:
		return texture
	# Summing two pale endpoint gradients made the transparent cold film grey.
	# Keep a coloured blue endpoint, and a quieter line contribution, without
	# replacing the native noise, dissolver, fresnel or gradient alpha.
	var source_colours: PackedColorArray = texture.gradient.colors
	var blue_colours := PackedColorArray([
		Color(0.035, 0.12, 0.24),
		Color(0.06, 0.24, 0.48),
		Color(0.10, 0.43, 0.74),
		Color(0.20, 0.65, 0.92),
		Color(0.10, 0.48, 0.83),
		Color(0.32, 0.78, 1.0)
	])
	for index in blue_colours.size():
		if line:
			blue_colours[index] *= 0.35
		blue_colours[index].a = source_colours[index].a
	texture.gradient.colors = blue_colours
	return texture
