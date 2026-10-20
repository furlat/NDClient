extends Resource
## Immutable actual class-action GPU strip operands; no owner or pose state.
const Clock = preload("res://assets/vfx/sources/c0017ad639184b208deb/occurrence_clock.gd")
@export var scene: PackedScene
@export var strip_mesh: ArrayMesh
@export var materials: Array[ShaderMaterial] = []
@export var piece_paths: Array[NodePath] = []
@export var mote_paths: Array[NodePath] = []
@export var material_parameters: Dictionary = {}
@export var native_defaults: Dictionary = {}
@export var provenance: Dictionary = {}
var interface_ready := false


func prepare_immutable_interface() -> void:
	if interface_ready:
		return
	Clock.ensure_pool()
	var programs := {}
	for material: ShaderMaterial in materials:
		material.get_property_list()
		if not programs.has(material.shader):
			material.shader.get_shader_uniform_list()
			programs[material.shader] = true
	strip_mesh.get_rid()
	interface_ready = true
