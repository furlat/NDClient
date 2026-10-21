extends RefCounted
## A derived receiver consumes the exact canonical bank; no bank mutation/copy.
const OriginalRestore = preload("res://assets/vfx/extensions/input-reduction-20261021/sources/0b6e30d472c4c9c2d0b5/restore.gd")


static func make(path: String, original_adapter: String, input: Dictionary) -> Node3D:
	var script: Script = VfxPackageIO_e7f3db6ad5.resource(path)
	assert(script.get_base_script() == VfxPackageIO_e7f3db6ad5.resource(original_adapter), "Only this explicit immediate source derivative can reuse the bank")
	return OriginalRestore.restore(script.new(), input, original_adapter)

const VfxPackageIO_e7f3db6ad5 = preload("res://assets/vfx/extensions/speed-completion-20261021/scoped_resource_io.gd")
