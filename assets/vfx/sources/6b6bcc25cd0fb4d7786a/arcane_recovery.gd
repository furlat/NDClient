extends "res://assets/vfx/sources/70c05cebd9bbb511e6b9/arcane_recovery.gd"
const GPUPaths = preload("res://assets/vfx/sources/dd57e643cd33d5e2c463/wizard_ribbons.gd")


static func make_component(input: Dictionary) -> Node3D:
	var effect: Node3D = VfxPackageIO_6b6bcc25cd.resource("res://assets/vfx/sources/6b6bcc25cd0fb4d7786a/arcane_recovery.gd").new()
	effect.settings = input.duplicate(true)
	effect.prepare()
	return effect


func prepare() -> void:
	super.prepare()
	for index in strokes.size():
		GPUPaths.prepare(strokes[index], 0, index, 16)


func stroke_mesh(index: int, contraction: float) -> ArrayMesh:
	materials[index].set_shader_parameter("gpu_wizard_motion", contraction)
	return strokes[index].mesh

const VfxPackageIO_6b6bcc25cd = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
