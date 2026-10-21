extends "res://assets/vfx/extensions/input-reduction-20261021/sources/d4e1dbdbf18cb3f9bbc5/sequence.gd"


static func preparation_resources(input: Dictionary) -> Array:
	return [str(input.skeletal_sequence_bank)]


static func make_component(input: Dictionary) -> Node3D:
	var bank: Resource = VfxPackageIO_b26a329835.resource(input.skeletal_sequence_bank)
	return bank.restore(input)


func source_bindings() -> Dictionary:
	var result: Dictionary = super.source_bindings()
	result.geometry_paths = source_bank.prepared_geometry_paths
	return result

const VfxPackageIO_b26a329835 = preload("res://assets/vfx/extensions/input-reduction-20261021/scoped_resource_io.gd")
