extends Node3D
## Explicit occurrence alpha after a source's own material/animation envelope.
## Source geometry, native material values, seed and source clock stay separate.
const NativeOpacity = preload("res://assets/vfx/sources/39f30ee3f172ac269cd6/native_opacity.gd")
var source_component: Node3D
var opacity_prepared: bool = false


static func make_component(input: Dictionary) -> Node3D:
	var source_script: Script = VfxPackageIO_3966d6cc72.resource(input.constructor_script)
	assert(source_script != null and source_script.has_method("make_component"))
	assert(input.constructor_script != "res://assets/vfx/sources/3966d6cc724927baedcb/occurrence_opacity.gd")
	var instance := preload("res://assets/vfx/sources/3966d6cc724927baedcb/occurrence_opacity.gd").new()
	instance.source_component = source_script.make_component(input.source_input.duplicate(true))
	assert(instance.source_component != null)
	instance.source_component.name = "Source"
	instance.add_child(instance.source_component)
	return instance


func sample(local_seconds: float) -> void:
	source_component.sample(local_seconds)
	if not opacity_prepared:
		NativeOpacity.apply(source_component)
		opacity_prepared = true


func set_entity_geometry(geometry: Dictionary) -> void:
	if source_component.has_method("set_entity_geometry"):
		source_component.set_entity_geometry(geometry)


func capture_observation() -> Dictionary:
	var result: Dictionary = source_component.capture_observation() if source_component.has_method("capture_observation") else {}
	result["occurrence_opacity"] = {
		"source_constructor": source_component.get_script().resource_path,
		"prepared": opacity_prepared,
		"neutral_uniform": NativeOpacity.UNIFORM,
		"source_envelope_preserved": true
	}
	return result

const VfxPackageIO_3966d6cc72 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
