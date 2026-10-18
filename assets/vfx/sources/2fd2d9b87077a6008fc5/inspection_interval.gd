extends Node3D
## Explicit finite inspection interval for renderer-owned actor/equipment effects.
## It supplies no replacement sprite or fake native geometry.
static func make_component(_input: Dictionary) -> Node3D:
	return VfxPackageIO_2fd2d9b870.resource("res://assets/vfx/sources/2fd2d9b87077a6008fc5/inspection_interval.gd").new()
func sample(_seconds: float) -> void:
	pass

const VfxPackageIO_2fd2d9b870 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
