extends "res://assets/vfx/extensions/source-preparation-20261020/sources/59e01d16319a5dcc3e14/constructed_occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var actual_clip: Dictionary = Admission.clip_for(Phase, input, "blast")
	if actual_clip.is_empty(): return null
	var instance: Node3D = load("res://assets/vfx/clips/100d3fa73c33c700b8c1d11f/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.clip = actual_clip
	return instance

func set_blast_event(value: Variant) -> void:
	forward("set_blast_event", value)

const Phase = preload("res://assets/vfx/extensions/source-preparation-20261020/sources/7dd318a93f1e6313f6b3/blast.tres")
const Admission = preload("res://assets/vfx/extensions/source-preparation-20261020/sources/5b8a8072f6a6764d6958/freezing_construction.gd")
