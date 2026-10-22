extends "res://assets/vfx/extensions/spike-readiness-20261022/sources/355a1b1e609d6615199c/filtered_bank.gd"
## Keep every getter-elision/Shader/restore operation. Only an actual immutable
## native StandardMaterial RID unit moves to its current exclusive worker.
const MaterialJob = preload("res://assets/vfx/extensions/spike-readiness-20261022/sources/53d9797431f8763b5604/material_job.gd")
var material_job: Resource
var current_material: StandardMaterial3D
var native_material_jobs: Array[Dictionary] = []
var drained_material_jobs: Array[Dictionary] = []
var immutable_standard_materials: Dictionary = {}
var standard_materials_resolved := false


func _resolve_standard_materials() -> void:
	# Binding addresses refer to the original saved scene, not private Nodes.
	# Unknown binding kinds/resources remain on the old synchronous fallback.
	var state: SceneState = construction_source.scene.get_state()
	for binding: Dictionary in immutable_material_bindings:
		if binding.get("kind") != "override" or int(binding.get("next_pass_depth", 0)) != 0:
			continue
		var path := str(binding.get("node", "")).trim_prefix("./")
		if not node_slots.has(path):
			continue
		var node: int = node_slots[path]
		for property: int in state.get_node_property_count(node):
			if state.get_node_property_name(node, property) != "material_override":
				continue
			var value: Variant = state.get_node_property_value(node, property)
			if value is StandardMaterial3D and value.get_class() == "StandardMaterial3D" \
				and value.get_script() == null and value.next_pass == null:
				immutable_standard_materials[value] = true
	standard_materials_resolved = true


func material_job_error() -> String:
	if material_job == null or material_job.get_script() != MaterialJob:
		return "Only the exact native Material RID job is admitted"
	if current_material == null or not immutable_standard_materials.has(current_material):
		return "Current Material is not an actual original immutable override"
	if resource_stack.is_empty() or resource_stack.back().value != current_material \
		or resource_stack.back().stage != "rid":
		return "Current original Material RID traversal stage changed"
	if material_job.material != null and material_job.material != current_material:
		return "Native Material job identity differs from the actual source"
	return ""


func _resource_step() -> Dictionary:
	var frame: Dictionary = resource_stack.back()
	if frame.stage != "rid" or not frame.value is StandardMaterial3D:
		return super._resource_step()
	if not standard_materials_resolved:
		_resolve_standard_materials()
	var value: StandardMaterial3D = frame.value
	if not immutable_standard_materials.has(value):
		return super._resource_step()
	if material_job == null:
		current_material = value
		material_job = MaterialJob.new()
	var guard := material_job_error()
	if not guard.is_empty():
		return {"ready": false, "error": guard}
	var progress: Dictionary = material_job.prepare_step(value)
	if progress.get("complete", false) and str(progress.get("error", "")).is_empty():
		var native: Dictionary = progress.native_job.duplicate(true)
		native.ordinal = native_material_jobs.size()
		native.material_path = value.resource_path
		native_material_jobs.append(native)
		material_job = null
		current_material = null
		# Exactly the original get_rid call is complete. Property reflection
		# and all remaining traversal stay on main, at the original next stage.
		frame.stage = "shader_metadata"
	return {"ready": false, "error": str(progress.get("error", "")), "worker": progress}


func drain_immutable_interface_step() -> Dictionary:
	var drained: Dictionary = {}
	if material_job != null:
		var progress: Dictionary = material_job.drain_step()
		if not progress.complete:
			return progress
		drained = progress.get("drained_native_job", {}).duplicate(true)
		if not drained.is_empty():
			drained.material_path = current_material.resource_path
			drained_material_jobs.append(drained)
		material_job = null
		current_material = null
		# Keep the RID stage/ordinal unadvanced and bank unready on cancel.
	var inherited: Dictionary = super.drain_immutable_interface_step()
	if not drained.is_empty():
		inherited.drained_native_job = drained
	return inherited
