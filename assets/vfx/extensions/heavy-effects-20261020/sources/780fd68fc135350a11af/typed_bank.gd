extends "res://assets/vfx/extensions/late-20261020/sources/2ca6ebd4f1e16e3ce3ba/bank.gd"
## Additional immutable source construction, not another recording/player.
var prepared_geometry_paths := PackedStringArray()
@export var construction_program: Script
@export var construction_operands: Array = []
@export var construction_source: Resource
@export var construction_resource_operands: Array[Dictionary] = []
@export var node_values_by_track: Array = []
@export var node_kinds := PackedByteArray()
@export var node_blend := PackedByteArray()
@export var node_degenerate_by_track: Array = []
@export var initial_node_dispatch: Array = []
@export var initial_material_dispatch: Array = []

func prepare_immutable_interface() -> void:
	if interface_ready: return
	for reference: Dictionary in construction_resource_operands:
		var value: Resource
		match str(reference.kind):
			"scene_property": value = construction_source.scene.get_state().get_node_property_value(int(reference.node), int(reference.property))
			"shader": value = construction_source.materials[int(reference.material)].shader
			"parameter": value = construction_source.materials[int(reference.material)].get_shader_parameter(reference.key)
			"metadata": value = construction_source.materials[int(reference.material)].get_meta(reference.key)
			_: assert(false, "Unknown immutable Ice Storm source operand")
		assert(value != null)
		construction_operands[int(reference.index)] = value
		if value is Mesh or value is MultiMesh or value is Shader or value is Texture: value.get_rid()
	for path: NodePath in geometry_paths:
		var relative := NodePath("Recorded/" + str(path))
		assert(not relative.is_absolute() and relative.get_subname_count() == 0)
		prepared_geometry_paths.append(str(relative).trim_prefix("./"))
	super.prepare_immutable_interface()
	preload("res://assets/vfx/sources/dabf568b4506db4883ad/occurrence_bindings.gd").methods(VfxPackageIO_780fd68fc1.resource("res://assets/vfx/extensions/heavy-effects-20261020/sources/0abf4d3b11f1f4402673/typed_field.gd"))

const VfxPackageIO_780fd68fc1 = preload("res://assets/vfx/extensions/heavy-effects-20261020/scoped_resource_io.gd")
