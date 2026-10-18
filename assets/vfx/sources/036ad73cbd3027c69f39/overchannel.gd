extends "res://assets/vfx/sources/80654deefe46be85224b/overchannel.gd"
const GPUPaths = preload("res://assets/vfx/sources/dd57e643cd33d5e2c463/wizard_ribbons.gd")


static func make_component(input: Dictionary) -> Node3D:
	var effect: Node3D = VfxPackageIO_036ad73cbd.resource("res://assets/vfx/sources/036ad73cbd3027c69f39/overchannel.gd").new()
	effect.settings = input.duplicate(true)
	effect.prepare()
	return effect


func prepare() -> void:
	super.prepare()
	for index in charge_blades.size():
		GPUPaths.prepare(charge_blades[index], 1, index, 20)
	for index in recoil_strokes.size():
		recoil_strokes[index].mesh = super.recoil_mesh(index)


func charge_mesh(index: int, gathered: float) -> ArrayMesh:
	charge_materials[index].set_shader_parameter("gpu_wizard_motion", gathered)
	return charge_blades[index].mesh


func recoil_mesh(index: int) -> ArrayMesh:
	return recoil_strokes[index].mesh

const VfxPackageIO_036ad73cbd = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
