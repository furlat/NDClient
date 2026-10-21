extends "res://assets/vfx/extensions/public-admission-20261020/sources/59e01d16319a5dcc3e14/constructed_occurrence.gd"
## Existing public occurrence/private-clip path, no saved observation defaults.
const Phase = preload("res://assets/vfx/extensions/public-admission-20261020/sources/6033ff6a0d8ffe5824a1/phase.tres")
const Admission = preload("res://assets/vfx/extensions/public-admission-20261020/sources/ebff964087bc8be5083e/public_explosion_construction.gd")


static func make_component(input: Dictionary) -> Node3D:
	var actual_clip := Admission.clip_for(Phase,input)
	if actual_clip.is_empty(): return null
	var node := preload("res://assets/vfx/extensions/public-admission-20261020/sources/d34f187453abd42ddb8a/public_explosion_occurrence.gd").new()
	node.parameters = input.duplicate(true)
	node.parameters.clip = actual_clip
	return node


func set_observed_explosion(value: Dictionary) -> void:
	forward("set_observed_explosion",value)
