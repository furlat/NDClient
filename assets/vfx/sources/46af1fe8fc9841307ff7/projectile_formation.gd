extends Node3D
## Composes a native anticipation donor. Camera, palette and export stay external.
const ClockedSource = preload("res://assets/vfx/sources/843204815cdceaac8544/clocked_source.gd")
var parameters: Dictionary
var donor: Node3D
var initialized: bool = false

static func make_component(input: Dictionary) -> Node3D:
	var component: Node3D = VfxPackageIO_46af1fe8fc.resource("res://assets/vfx/sources/46af1fe8fc9841307ff7/projectile_formation.gd").new()
	component.parameters = input.duplicate(true)
	component.donor = ClockedSource.make_component(input.source)
	if component.donor == null:
		component.free()
		return null
	component.donor.name = "Source"
	component.add_child(component.donor)
	return component

func sample(seconds: float) -> void:
	donor.sample(seconds)
	if not initialized:
		initialized = true
		for geometry in donor.find_children("*", "GeometryInstance3D", true, false):
			geometry.layers = 1
			geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for light in donor.find_children("*", "Light3D", true, false):
			light.visible = false
		for node_path in parameters.get("hidden_nodes", []):
			var target: Node3D = donor.subject.get_node_or_null(node_path)
			if target == null:
				push_error("Missing formation hide target: " + str(node_path))
				return
			target.visible = false
		for node_path in parameters.get("origin_nodes", []):
			var target: Node3D = donor.subject.get_node_or_null(node_path)
			if target == null:
				push_error("Missing formation origin target: " + str(node_path))
				return
			target.position = Vector3.ZERO
	var progress: float = clampf(seconds / float(parameters.duration_seconds), 0.0, 1.0)
	var growth: float = smoothstep(0.0, 0.78, progress)
	var minimum: float = float(parameters.get("minimum_scale", 0.15))
	var factor: float = lerpf(minimum, 1.0, growth)
	if parameters.formation == "compression":
		factor = lerpf(1.25, 0.72, smoothstep(0.0, 1.0, progress))
	elif parameters.formation == "held":
		factor = lerpf(0.3, 1.0, smoothstep(0.0, 0.45, progress))
	elif parameters.formation == "constant":
		factor = 1.0
	var scale_values: Array = parameters.scale
	donor.scale = Vector3(scale_values[0], scale_values[1], scale_values[2]) * factor
	var rotation_values: Array = parameters.get("rotation_degrees", [0, 0, 0])
	donor.rotation_degrees = Vector3(rotation_values[0], rotation_values[1], rotation_values[2])
	var offset: Array = parameters.get("offset", [0, 0, 0])
	donor.position = Vector3(offset[0], offset[1], offset[2])

const VfxPackageIO_46af1fe8fc = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
