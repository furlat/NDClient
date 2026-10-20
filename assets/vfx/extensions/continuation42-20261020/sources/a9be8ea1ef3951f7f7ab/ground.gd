extends "res://assets/vfx/sources/0bbbce20d9e5bebc4ff3/ground_strips.gd"
## Exact original Rage/Frenzy pressure state, source clock and GPU equations.
const Restore = preload("res://assets/vfx/extensions/continuation42-20261020/sources/c0afafcb85ad41652932/restore.gd")
var bank: Resource


static func preparation_resources(input: Dictionary) -> Array:
	return [str(input.prepared_strips_bank)]


static func make_component(input: Dictionary) -> Node3D:
	var node: Node3D = VfxPackageIO_a9be8ea1ef.resource("res://assets/vfx/extensions/continuation42-20261020/sources/a9be8ea1ef3951f7f7ab/ground.gd").new()
	node.bank = Restore.ready_bank(input)
	node.settings = input.duplicate(true)
	node.settings.erase("prepared_strips_bank")
	assert(node.set_owner_projection(input.owner_projection))
	assert(node.set_activation_projection(input.activation_projection))
	node._build()
	node.sample(0.0)
	return node


func _build() -> void:
	Restore.build(self, bank)


func build_strip(_index: int, _seconds: float) -> ArrayMesh:
	return bank.strip_mesh


func source_bindings() -> Dictionary:
	return Restore.bindings(self)

const VfxPackageIO_a9be8ea1ef = preload("res://assets/vfx/extensions/continuation42-20261020/scoped_resource_io.gd")
