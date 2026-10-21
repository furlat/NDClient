extends "res://assets/vfx/extensions/source-preparation-20261020/sources/59e01d16319a5dcc3e14/constructed_occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var actual_clip: Dictionary = Admission.clip_for(Phase, input, "delivery")
	if actual_clip.is_empty(): return null
	var instance: Node3D = load("res://assets/vfx/clips/86c54c615be9b8dfefcd9051/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.clip = actual_clip
	return instance

func set_accepted_release(value: Variant) -> void:
	forward("set_accepted_release", value)

const Phase = preload("res://assets/vfx/extensions/source-preparation-20261020/sources/4283b96dc005240b8b57/delivery.tres")
const Admission = preload("res://assets/vfx/extensions/source-preparation-20261020/sources/5b8a8072f6a6764d6958/freezing_construction.gd")
