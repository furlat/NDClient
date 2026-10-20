extends Resource
## Two exact source materials and the immutable native cone; no patch layout.
const Bindings = preload("res://assets/vfx/sources/dabf568b4506db4883ad/occurrence_bindings.gd")
const Interfaces = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
const Clock = preload("res://assets/vfx/sources/c0017ad639184b208deb/occurrence_clock.gd")
@export var source_material := ""
@export var cone: Mesh
@export var materials: Array[ShaderMaterial] = []
@export var specifications: Array[Dictionary] = []
@export var provenance: Dictionary = {}
var interface_ready := false


func private_material(index: int) -> ShaderMaterial:
	var result := ShaderMaterial.new()
	result.shader = materials[index].shader
	result.render_priority = specifications[index].render_priority
	for name: String in specifications[index].parameters:
		result.set_shader_parameter(name,specifications[index].parameters[name])
	for name: String in specifications[index].metadata:
		result.set_meta(name,specifications[index].metadata[name])
	return result


func prepare_immutable_interface() -> void:
	if interface_ready:
		return
	Clock.ensure_pool()
	Bindings.methods(VfxPackageIO_d4402b1bf5.resource("res://assets/vfx/extensions/continuation42-20261020/sources/e8a6016779c40c17dd0a/field.gd"))
	Bindings.methods(VfxPackageIO_d4402b1bf5.resource("res://assets/vfx/extensions/continuation42-20261020/sources/427e33ec633145d58dd7/surface.gd"))
	for material: ShaderMaterial in materials:
		material.get_rid()
		material.get_property_list()
		Interfaces.declared_uniforms(material.shader)
	cone.get_rid()
	interface_ready = true

const VfxPackageIO_d4402b1bf5 = preload("res://assets/vfx/extensions/continuation42-20261020/scoped_resource_io.gd")
