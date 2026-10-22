extends "res://assets/vfx/extensions/cloud-body-speed-20261021/sources/c4f4d4ddde2bc2618e33/bank.gd"
## Exact immutable backing identity, never reserialize its scene/shader copies.
@export var original_frame_bank: Resource:
	set(value):
		original_frame_bank = value
		if value != null:
			native_bank = value.native_bank
			frame_shaders = value.frame_shaders
var typed_methods_prepared := false


func _validate_property(property: Dictionary) -> void:
	if property.name in ["native_bank", "frame_shaders"]:
		property.usage = int(property.usage) & ~PROPERTY_USAGE_STORAGE


func prepare_immutable_interface_step() -> Dictionary:
	if not typed_methods_prepared:
		Bindings.methods(VfxPackageIO_74aff669a5.resource("res://assets/vfx/extensions/cloud-body-speed-20261021/sources/6e801bbcee540821f1cf/component.gd"))
		typed_methods_prepared = true
	return super.prepare_immutable_interface_step()

const VfxPackageIO_74aff669a5 = preload("res://assets/vfx/extensions/cloud-body-speed-20261021/scoped_resource_io.gd")
