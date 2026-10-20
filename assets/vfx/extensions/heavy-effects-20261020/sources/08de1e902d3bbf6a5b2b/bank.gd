extends Resource
## Immutable native donor and station meshes. No endpoint or occurrence state.
const Bindings = preload("res://assets/vfx/sources/dabf568b4506db4883ad/occurrence_bindings.gd")
const SourceMaterials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
@export var source_parameters: Dictionary = {}
@export var materials: Array[ShaderMaterial] = []
@export var draws: Array[Dictionary] = []
@export var groups: Dictionary = {}
@export var material_roles: Dictionary = {}
@export var atlas_definitions: Array[Dictionary] = []
@export var provenance: Dictionary = {}
var interface_ready := false
var bow_shape: Dictionary = {}

func prepare_immutable_interface() -> void:
	if interface_ready:
		return
	var along := PackedFloat64Array()
	var bend := PackedFloat64Array()
	var height := PackedFloat64Array()
	var radii: Array[float] = []
	var core_radii: Array[float] = []
	for index in 41:
		var weight: float = float(index) / 40.0
		var vertical: float = weight * 2.0 - 1.0
		var angle: float = vertical * PI * 0.5
		along.append(0.34 * (cos(angle) - 1.0) + 0.06 * pow(absf(vertical), 10.0))
		bend.append(sin(absf(vertical) * PI))
		height.append(sin(angle) * 0.58)
		radii.append(0.017 + 0.022 * pow(sin(weight * PI), 0.6))
		core_radii.append(radii[-1] * 0.42)
	bow_shape = {"along": along, "bend": bend, "height": height, "radii": radii, "core_radii": core_radii}
	Bindings.methods(VfxPackageIO_08de1e902d.resource("res://assets/vfx/extensions/heavy-effects-20261020/sources/d7935024e5867aba3106/delivery.gd"))
	for material in materials:
		material.get_property_list()
		material.shader.get_shader_uniform_list()
		SourceMaterials.declared_uniforms(material.shader)
	# Primitive donor/drop meshes may defer their actual native surface/RID
	# creation until first use. This immutable work belongs before publication.
	var visited := {}
	for record in draws:
		if not visited.has(record.mesh):
			record.mesh.get_rid()
			visited[record.mesh] = true
	interface_ready = true

const VfxPackageIO_08de1e902d = preload("res://assets/vfx/extensions/heavy-effects-20261020/scoped_resource_io.gd")
