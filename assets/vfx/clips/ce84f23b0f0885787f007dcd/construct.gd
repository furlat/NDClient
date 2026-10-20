extends "res://assets/vfx/extensions/continuation42-20261020/sources/59e01d16319a5dcc3e14/constructed_occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var application: Dictionary = input.get("application", {})
	if not ApplicationAdmission.missing(application).is_empty(): return null
	var instance: Node3D = load("res://assets/vfx/clips/ce84f23b0f0885787f007dcd/construct.gd").new()
	instance.parameters = input.duplicate(true)
	var actual_clip: Dictionary = Phase.to_clip()
	var actual_application: Dictionary = application.duplicate(true)
	actual_application.target_entity_uuid = actual_application.target_actor
	actual_clip.components[0].input.components[0].input.application = actual_application
	instance.parameters.clip = actual_clip
	return instance

const Phase = preload("res://assets/vfx/extensions/continuation42-20261020/sources/37b2a683382a6745d17c/circle.tres")
const ApplicationAdmission = preload("res://assets/vfx/extensions/continuation42-20261020/sources/f96e18e08395bac8fbf5/circle_recipient_template.gd")
