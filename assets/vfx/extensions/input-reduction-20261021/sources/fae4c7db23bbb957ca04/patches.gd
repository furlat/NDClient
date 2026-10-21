extends "res://assets/vfx/extensions/input-reduction-20261021/sources/3c63e176f9d16e1b5d1f/receiving_patches.gd"
## Immutable native pieces; all actual geometry and source equations inherited.
const Restore = preload("res://assets/vfx/extensions/input-reduction-20261021/sources/0b6e30d472c4c9c2d0b5/restore.gd")
var bank: Resource
var prepared_root: Node3D


static func preparation_resources(input: Dictionary) -> Array:
	return [str(input.prepared_receiving_bank)]


static func make_component(input: Dictionary) -> Node3D:
	var path := "res://assets/vfx/extensions/input-reduction-20261021/sources/fae4c7db23bbb957ca04/patches.gd"
	return Restore.restore(VfxPackageIO_fae4c7db23.resource(path).new(), input, path)


func source_bindings() -> Dictionary:
	return {"geometry": pieces, "materials": materials, "lights": [], "players": [],
		"static_material_topology": true, "static_geometry_layers": true}

const VfxPackageIO_fae4c7db23 = preload("res://assets/vfx/extensions/input-reduction-20261021/scoped_resource_io.gd")
