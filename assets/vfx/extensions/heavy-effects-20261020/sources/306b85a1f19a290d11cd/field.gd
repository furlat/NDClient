extends "res://assets/vfx/extensions/heavy-effects-20261020/sources/2cd710be3201c544db8f/field.gd"
## Same fixed recorded public source, with explicitly compiled sample operands.
const TableField = preload("res://assets/vfx/extensions/heavy-effects-20261020/sources/2cd710be3201c544db8f/field.gd")
static func preparation_resources(input: Dictionary) -> Array:
	return [str(input.recorded_geometry_bank)]

static func make_component(input: Dictionary) -> Node3D:
	var path := str(input.recorded_geometry_bank)
	assert(Readiness.resources.has(path))
	var retained: Resource = Readiness.resources[path]
	assert(retained.interface_ready and retained.sample_table!=null and retained.sample_table.source==retained.construction_source)
	var node: Node3D = VfxPackageIO_306b85a1f1.resource("res://assets/vfx/extensions/heavy-effects-20261020/sources/306b85a1f19a290d11cd/field.gd").new()
	return TableField.restore(node,retained)

func sample(seconds: float) -> void:
	bank.sample_table.sample(self,seconds)

const VfxPackageIO_306b85a1f1 = preload("res://assets/vfx/extensions/heavy-effects-20261020/scoped_resource_io.gd")
