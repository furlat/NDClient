extends "res://assets/vfx/extensions/late-20261020/sources/2572219a2ddff406e89a/oil_liquid_reflection.gd"
## Explicit derivative: original material/events, live field and immutable GPU draws.
const GPUField = preload("res://assets/vfx/extensions/late-20261020/sources/e1712eaf075bc24a6231/liquid_field.gd")


static func make_component(input: Dictionary) -> Node3D:
	var component: Node3D = VfxPackageIO_3bd1569e74.resource("res://assets/vfx/extensions/late-20261020/sources/3bd1569e74b63608f590/oil_liquid_reflection.gd").new()
	component.settings = input.duplicate(true)
	component.settings.charge_at = 0.0
	component.simulation = JSON.parse_string(VfxPackageIO_3bd1569e74.text(input.simulation))
	component._build()
	return component


func _build() -> void:
	super._build()
	GPUField.install(self)


func _set_fluid(value: PackedVector4Array) -> void:
	GPUField.set_fluid(self, live_particles if not live_particles.is_empty() else value)


func _make_electricity(input: Dictionary) -> Node3D:
	return GPUField.electricity(input)


func _conduction_layout(support: Array[Vector3], values: PackedVector4Array) -> Dictionary:
	return GPUField.FastConduction.layout(support, values)


func _sample_electricity(seconds: float,retirement: float) -> void:
	if GPUField.charge_can_be_visible(self,seconds):
		super._sample_electricity(seconds,retirement)
	else:
		electricity.hide()

const VfxPackageIO_3bd1569e74 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
