extends "res://assets/vfx/sources/e590c9ae3baae472d4aa/liquid_state.gd"
## Explicit derivative: original material/events, live field and immutable GPU draws.
const GPUField = preload("res://assets/vfx/sources/e1712eaf075bc24a6231/liquid_field.gd")


static func make_component(input: Dictionary) -> Node3D:
	var component: Node3D = VfxPackageIO_4417f42a4a.resource("res://assets/vfx/sources/4417f42a4a44367964ba/liquid_state.gd").new()
	component.settings = input.duplicate(true)
	component.simulation = JSON.parse_string(VfxPackageIO_4417f42a4a.text(input.simulation))
	component._build()
	return component


func _build() -> void:
	super._build()
	GPUField.install(self)


func _set_fluid(value: PackedVector4Array) -> void:
	GPUField.set_fluid(self, value)


func _make_electricity(input: Dictionary) -> Node3D:
	return GPUField.electricity(input)


func _conduction_layout(support: Array[Vector3], values: PackedVector4Array) -> Dictionary:
	return GPUField.FastConduction.layout(support, values)

const VfxPackageIO_4417f42a4a = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
