extends RefCounted
const Appearance=preload("res://assets/vfx/sources/391cb32a84074d4bcb03/appearance.gd")
static func make_component(input: Dictionary) -> Node3D:
	return Appearance.make("devotees_mace",input)
