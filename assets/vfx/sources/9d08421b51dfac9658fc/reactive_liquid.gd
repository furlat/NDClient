extends "res://assets/vfx/sources/979ecf1a1d9d8264d287/reactive_liquid.gd"
## Explicit derivative: original material/events, live field and immutable GPU draws.
const GPUField = preload("res://assets/vfx/sources/e1712eaf075bc24a6231/liquid_field.gd")


static func make_component(input: Dictionary) -> Node3D:
	var component: Node3D = VfxPackageIO_9d08421b51.resource("res://assets/vfx/sources/9d08421b51dfac9658fc/reactive_liquid.gd").new()
	component.settings = input.duplicate(true)
	component.settings.charge_at = 0.0
	component.simulation = JSON.parse_string(VfxPackageIO_9d08421b51.text(input.simulation))
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

const VfxPackageIO_9d08421b51 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
