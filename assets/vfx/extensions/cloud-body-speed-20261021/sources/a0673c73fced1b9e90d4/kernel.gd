extends "res://assets/vfx/extensions/cloud-body-speed-20261021/sources/70ba4efc12bbd762aa87/kernel.gd"
## The existing immutable main-device readiness and host-owned close contract.


func prepare_immutable_interface_step() -> Dictionary:
	if program == null:
		program = VfxPackageIO_a0673c73fc.resource("res://assets/vfx/extensions/cloud-body-speed-20261021/sources/84260a019e9468668dc4/program.gd").new()
		program.prepare()
	return super.prepare_immutable_interface_step()

const VfxPackageIO_a0673c73fc = preload("res://assets/vfx/extensions/cloud-body-speed-20261021/scoped_resource_io.gd")
