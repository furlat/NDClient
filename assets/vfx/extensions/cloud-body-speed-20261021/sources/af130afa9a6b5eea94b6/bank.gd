extends Resource
## Unsampled native GPU strips. Immutable resources only; no current actor points.
const Interfaces = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
const Bindings = preload("res://assets/vfx/sources/dabf568b4506db4883ad/occurrence_bindings.gd")
const Clock = preload("res://assets/vfx/sources/c0017ad639184b208deb/occurrence_clock.gd")
@export var scene: PackedScene
@export var source_input: Dictionary = {}
@export var adapter_script: String
@export var piece_paths: Array[NodePath] = []
@export var material_piece_indices: Array[int] = []
@export var materials: Array[ShaderMaterial] = []
@export var native_defaults: Dictionary = {}
@export var provenance: Dictionary = {}
var interface_ready := false


func prepare_immutable_interface() -> void:
	if interface_ready:
		return
	assert(scene != null and not adapter_script.is_empty())
	Bindings.methods(VfxPackageIO_af130afa9a.resource(adapter_script))
	for material: ShaderMaterial in materials:
		if material.get_meta("factory_clock_pool_required", false):
			Clock.ensure_pool()
			break
	for material: ShaderMaterial in materials:
		material.get_rid()
		Interfaces.declared_uniforms(material.shader)
	var state := scene.get_state()
	for index in state.get_node_count():
		for property in state.get_node_property_count(index):
			var value: Variant = state.get_node_property_value(index, property)
			if value is Mesh:
				value.get_rid()
	interface_ready = true

const VfxPackageIO_af130afa9a = preload("res://assets/vfx/extensions/cloud-body-speed-20261021/scoped_resource_io.gd")
