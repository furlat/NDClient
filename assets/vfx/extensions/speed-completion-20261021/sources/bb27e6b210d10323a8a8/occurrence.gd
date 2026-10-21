extends "res://assets/vfx/extensions/speed-completion-20261021/sources/59e01d16319a5dcc3e14/constructed_occurrence.gd"
## Same selected Wind public operand seam. Local Phase load avoids a static
## Script -> Phase -> source/bank -> Script ownership cycle.
const PHASE := "res://assets/vfx/extensions/speed-completion-20261021/sources/894bddaf1657d9ef4191/phase.tres"
const WallInput = preload("res://assets/vfx/extensions/production-review-20261020/sources/f02011b40df3c7fa1160/input.gd")


static func make_component(input: Dictionary) -> Node3D:
	var actual_wall: Variant = input.get("wall")
	if not actual_wall is Dictionary:
		return null
	var admitted: Dictionary = WallInput.construction(actual_wall, "wind")
	if not admitted.error.is_empty():
		return null
	var phase: Resource = VfxPackageIO_bb27e6b210.resource(PHASE)
	if phase == null:
		return null
	var actual_clip: Dictionary = phase.to_clip()
	if actual_clip.components.size() != 1 or actual_clip.components[0].id != "wall":
		return null
	var source_input: Dictionary = actual_clip.components[0].input
	source_input.wall_uuid = actual_wall.wall_uuid
	source_input.anchor_position = actual_wall.anchor_position.duplicate()
	source_input.wall_geometry = actual_wall.wall_geometry.duplicate(true)
	var instance: Node3D = VfxPackageIO_bb27e6b210.resource("res://assets/vfx/extensions/speed-completion-20261021/sources/bb27e6b210d10323a8a8/occurrence.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.clip = actual_clip
	return instance


func set_visual_state(value: Variant) -> void:
	forward("set_visual_state", value)

const VfxPackageIO_bb27e6b210 = preload("res://assets/vfx/extensions/speed-completion-20261021/scoped_resource_io.gd")
