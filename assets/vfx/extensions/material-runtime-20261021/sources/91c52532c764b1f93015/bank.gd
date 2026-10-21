extends "res://assets/vfx/extensions/material-runtime-20261021/sources/df037c7eda8447288c77/bank.gd"
## Official generated particle programs; immutable operands, private owner materials.
@export var native_processes: Array[Dictionary] = []
const SparseMaterial = preload("res://assets/vfx/extensions/material-runtime-20261021/sources/4c76b6c943d8b445b60b/sparse_material.gd")


func private_shader_process(index: int) -> ShaderMaterial:
	var specification: Dictionary = native_processes[index]
	assert(specification.has("sparse_native") and specification.sparse_native.shader == specification.prototype.shader,
		"Only actual offline-proved native defaults admit sparse process construction")
	return SparseMaterial.make(specification.sparse_native)


func prepare_immutable_interface() -> void:
	if interface_ready:
		return
	for specification: Dictionary in native_processes:
		var prototype: ShaderMaterial = specification.prototype
		prototype.get_property_list()
		prototype.get_rid()
		prototype.shader.get_rid()
		prototype.shader.get_shader_uniform_list()
	super.prepare_immutable_interface()
