extends Resource
const Bindings = preload("res://assets/vfx/sources/dabf568b4506db4883ad/occurrence_bindings.gd")
## Exact native solid/cold source assembly. No actor, section or damage owner.
@export var scene: PackedScene
@export var source_script := ""
@export var component_script := ""
@export var parameters: Dictionary = {}
@export var state: Dictionary = {}
@export var materials: Array[ShaderMaterial] = []
@export var material_bindings: Array[Dictionary] = []
@export var geometry_paths: Array[NodePath] = []
@export var break_parts: Array[Dictionary] = []
@export var break_motions: Array[Dictionary] = []
@export var legacy_fragments := false
@export var provenance: Dictionary = {}
var interface_ready := false

func prepare_immutable_interface() -> void:
	if interface_ready:
		return
	assert(not component_script.is_empty())
	Bindings.methods(VfxPackageIO_cd8c514c99.resource(component_script))
	for material in materials:
		material.get_property_list()
	for part in break_parts:
		part.shape.get_rid()
	interface_ready = true

const VfxPackageIO_cd8c514c99 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
