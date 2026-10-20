extends "res://assets/vfx/extensions/late-20261020/sources/820df97b3292c59d68f5/bank.gd"
## Immutable, unsampled K1/Torch source operands. No body owner/path is stored.
@export var head_paths: Array[NodePath] = []
@export var core_path: NodePath
@export var flame_root_path: NodePath
@export var native_processes: Array[Resource] = []
@export var original_node_states: Array[Dictionary] = []


func prepare_immutable_interface() -> void:
	if interface_ready:
		return
	super.prepare_immutable_interface()
	# These exact original processes remain native, local-coordinate simulation.
	# Resource interface publication does not create an emitter or consume time.
	for snapshot: Resource in native_processes:
		for property: Dictionary in snapshot.properties:
			if property.value is Texture:
				property.value.get_rid()
			elif property.value is Material:
				property.value.get_rid()
