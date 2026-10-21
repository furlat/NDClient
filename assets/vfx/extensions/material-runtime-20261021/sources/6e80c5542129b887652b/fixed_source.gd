extends RefCounted
## Thin authored-resource entrypoint; actual witness/point arrive through setters.
const Terminal = preload("res://assets/vfx/extensions/material-runtime-20261021/sources/fbfea3bf1c0992d05896/terminal.gd")


static func preparation_resources(path: String) -> Array:
	var phase: Resource = VfxPackageIO_6e80c55421.resource(path)
	var result: Array = [path]
	result.append_array(Terminal.preparation_resources(phase.components[0].input))
	return result


static func make(path: String, input: Dictionary) -> Node3D:
	var phase: Resource = VfxPackageIO_6e80c55421.resource(path)
	var parameters: Dictionary = phase.components[0].input.duplicate(true)
	if input.has("owner_uuid"):
		assert(typeof(input.owner_uuid) in [TYPE_STRING, TYPE_STRING_NAME])
		parameters.owner_uuid = str(input.owner_uuid)
	return Terminal.make_component(parameters)

const VfxPackageIO_6e80c55421 = preload("res://assets/vfx/extensions/material-runtime-20261021/scoped_resource_io.gd")
