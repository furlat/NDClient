extends "res://assets/vfx/extensions/cloud-body-speed-20261021/sources/70ba4efc12bbd762aa87/kernel.gd"
## Existing explicit shared-host lifetime; no private actor state is cached.


func prepare_immutable_interface_step() -> Dictionary:
	if program == null:
		program = VfxPackageIO_e56893f458.resource("res://assets/vfx/extensions/cloud-body-speed-20261021/sources/08355a94de091c0ca029/program.gd").new()
		program.prepare()
	return super.prepare_immutable_interface_step()

const VfxPackageIO_e56893f458 = preload("res://assets/vfx/extensions/cloud-body-speed-20261021/scoped_resource_io.gd")
