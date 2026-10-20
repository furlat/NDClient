extends Resource
## Immutable original sphere/corona operands. No occurrence owner or clock.
const Bindings = preload("res://assets/vfx/sources/dabf568b4506db4883ad/occurrence_bindings.gd")
const Clock = preload("res://assets/vfx/sources/c0017ad639184b208deb/occurrence_clock.gd")
@export var material_parameters: Dictionary = {}
@export var materials: Array[ShaderMaterial] = []
@export var sphere: Mesh
@export var corona: Mesh
@export var provenance: Dictionary = {}
var interface_ready := false


func prepare_immutable_interface() -> void:
	if interface_ready:
		return
	# The original shader really evaluates float32(age)+float32(offset).
	# Register that immutable shared sampler before reflecting/compiling it.
	Clock.ensure_pool()
	Bindings.methods(VfxPackageIO_31232e4f04.resource("res://assets/vfx/extensions/followup-20261020/sources/b886461c95443c086930/field.gd"))
	var programs := {}
	for material in materials:
		material.get_property_list()
		if not programs.has(material.shader):
			material.shader.get_shader_uniform_list()
			programs[material.shader] = true
	sphere.get_rid()
	corona.get_rid()
	interface_ready = true

const VfxPackageIO_31232e4f04 = preload("res://assets/vfx/extensions/followup-20261020/scoped_resource_io.gd")
