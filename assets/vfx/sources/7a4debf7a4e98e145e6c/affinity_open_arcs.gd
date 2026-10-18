extends "res://assets/vfx/sources/5944248dd6bb52ef8394/class_action.gd"
## Affinity keeps its own five native Arc materials, palette and activation.
## Short separated side crescents replace nearly full coils across the face.


static func make_component(input: Dictionary) -> Node3D:
	assert(str(input.kind) == "affinity")
	var component: Node3D = VfxPackageIO_7a4debf7a4.resource("res://assets/vfx/sources/7a4debf7a4e98e145e6c/affinity_open_arcs.gd").new()
	component.settings = input.duplicate(true)
	component.kind = "affinity"
	component._build()
	return component


func _point(index: int, u: float, seconds: float) -> Vector3:
	var phase := TAU * seconds / 2.0
	var angle := float(index) * TAU / 5.0 + u * .80 + .14 * sin(phase + index)
	var radius := .40 + .025 * sin(PI*u)
	var height := .20 + float(index % 3) * .12 + .42 * sin(u * PI * .5)
	return Vector3(cos(angle)*radius, height, sin(angle)*radius)

const VfxPackageIO_7a4debf7a4 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
