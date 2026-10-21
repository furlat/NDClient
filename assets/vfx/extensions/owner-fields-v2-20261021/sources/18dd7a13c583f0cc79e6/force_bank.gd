extends Resource
## One exact existing blue field mesh/program, without review controllers.
const Materials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
const Clock = preload("res://assets/vfx/sources/c0017ad639184b208deb/occurrence_clock.gd")
const Bindings = preload("res://assets/vfx/sources/dabf568b4506db4883ad/occurrence_bindings.gd")
@export var mesh: ArrayMesh
@export var shader: Shader
@export var original_shader: Shader
@export var settings := {}
@export var dome := false
@export var source_dimensions := Vector3.ZERO
@export var provenance := {}
var interface_ready := false


func prepare_immutable_interface() -> void:
	if interface_ready:
		return
	assert(mesh != null and shader != null and original_shader != null)
	assert(source_dimensions.x > 0.0 and source_dimensions.y > 0.0)
	if settings.metadata.get("factory_clock_pool_required", false):
		Clock.ensure_pool()
	mesh.get_rid()
	mesh.get_aabb()
	shader.get_rid()
	shader.get_shader_uniform_list()
	Materials.declared_uniforms(shader)
	Bindings.methods(VfxPackageIO_18dd7a13c5.resource("res://assets/vfx/extensions/owner-fields-v2-20261021/sources/0ab0ccb672dd38856a68/force.gd"))
	interface_ready = true


func private_material() -> ShaderMaterial:
	assert(interface_ready, "Exact immutable source interfaces must publish before any owner")
	var result := ShaderMaterial.new()
	result.shader = shader
	result.render_priority = int(settings.render_priority)
	for name: String in settings.parameters:
		result.set_shader_parameter(name, settings.parameters[name])
	for name: String in settings.metadata:
		result.set_meta(name, settings.metadata[name])
	return result

const VfxPackageIO_18dd7a13c5 = preload("res://assets/vfx/extensions/owner-fields-v2-20261021/scoped_resource_io.gd")
