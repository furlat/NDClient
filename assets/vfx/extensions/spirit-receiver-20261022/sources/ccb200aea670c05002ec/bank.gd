extends "res://assets/vfx/extensions/spirit-receiver-20261022/sources/0250a3f89c551f4fc017/bank.gd"
## Exact source leaf handles; no owner, placement, orbit or endpoint is saved.
@export var node_arrays: Dictionary={}
@export var material_members: Dictionary={}
@export var material_arrays: Dictionary={}
@export var value_members: Dictionary={}
@export var extra_materials: Array[ShaderMaterial]=[]
@export var restart_paths: Array[NodePath]=[]
@export var all_shader_bindings: Array[Dictionary]=[]
@export var geometry_paths: Array[NodePath]=[]
@export var plain_flow:=false

func prepare_immutable_interface() -> void:
 if interface_ready:return
 if provenance.get("requires_shared_clock",false):preload("res://assets/vfx/sources/c0017ad639184b208deb/occurrence_clock.gd").ensure_pool()
 super.prepare_immutable_interface()
