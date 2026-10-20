extends "res://assets/vfx/extensions/followup-20261020/sources/2ef1907a408fe4ae0445/receiving_forms.gd"


static func make_component(input: Dictionary) -> Node3D:
	assert(input.profile in ["pressure_folds", "unthreading"])
	return make_gpu("res://assets/vfx/extensions/followup-20261020/sources/798d83cf8e639ee77b17/receiving_forms_readable.gd", input, true)
