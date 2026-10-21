extends "res://assets/vfx/extensions/production-review-20261020/sources/59e01d16319a5dcc3e14/constructed_occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var actual_wall: Variant = input.get("wall")
	if not actual_wall is Dictionary: return null
	var admitted: Dictionary = WallInput.construction(actual_wall, "thorns")
	if not admitted.error.is_empty(): return null
	var actual_clip: Dictionary = Phase.to_clip()
	if actual_clip.components.size() != 1 or actual_clip.components[0].id != "wall": return null
	var source_input: Dictionary = actual_clip.components[0].input
	source_input.wall_uuid = actual_wall.wall_uuid
	source_input.anchor_position = actual_wall.anchor_position.duplicate()
	source_input.wall_geometry = actual_wall.wall_geometry.duplicate(true)
	var instance: Node3D = load("res://assets/vfx/clips/cfcc63404cdd0c6ebf5ffe70/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.clip = actual_clip
	return instance

func set_review_contacts(value: Variant) -> void:
	forward("set_review_contacts", value)

func set_visual_occupants(value: Variant) -> void:
	forward("set_visual_occupants", value)

func set_visual_state(value: Variant) -> void:
	forward("set_visual_state", value)

const Phase = preload("res://assets/vfx/extensions/production-review-20261020/sources/4ca74eba4e2947019be3/thorns_circle.tres")
const WallInput = preload("res://assets/vfx/extensions/production-review-20261020/sources/f02011b40df3c7fa1160/input.gd")
