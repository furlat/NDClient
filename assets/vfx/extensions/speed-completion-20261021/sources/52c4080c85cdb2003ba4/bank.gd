extends "res://assets/vfx/extensions/speed-completion-20261021/sources/cb4c06933b5782031b59/bank.gd"
## Only the current frame Shader uses the existing audited interface job.
## No Cloud node/material stage or Cloud immutable-ready state is entered.
const ShaderInterfaceJob = preload("res://assets/vfx/extensions/speed-completion-20261021/sources/75b200daec4a20076a81/cloud_bank.gd")
var shader_job: Resource
var current_shader: Shader
var shader_metadata_pending := false
var native_shader_jobs: Array[Dictionary] = []


func shader_job_error() -> String:
	if shader_job == null or shader_job.get_script() != ShaderInterfaceJob:
		return "Only the exact audited Shader-interface job is admitted"
	if preparation_stage != "frame_shader" or current_shader != frame_shaders[preparation_index]:
		return "Actual source Shader ordinal/identity changed during publication"
	if not shader_job.node_specs.is_empty() or shader_job.material_specs.size() != 1 \
		or shader_job.material_specs[0].size() != 1 or shader_job.material_specs[0].get("shader") != current_shader:
		return "Shader-interface composition requires zero nodes and exactly the current Shader"
	if shader_job.immutable_interface_prepared or shader_job._prepare_node != 0 \
		or shader_job._prepare_material != 0 or shader_job._prepare_material_step != (1 if shader_metadata_pending else 0):
		return "Shader-interface job must never enter a Cloud preparation stage"
	return ""


func prepare_immutable_interface_step() -> Dictionary:
	if preparation_stage != "frame_shader" or not preparation_error.is_empty() or interface_ready:
		return super.prepare_immutable_interface_step()
	var began := Time.get_ticks_usec()
	var ordinal := preparation_index
	var operation := "frame_shader_worker"
	var progress: Dictionary = {}
	if shader_job == null:
		current_shader = frame_shaders[preparation_index]
		shader_job = ShaderInterfaceJob.new()
		shader_job.material_specs.append({"shader": current_shader})
	preparation_error = shader_job_error()
	if preparation_error.is_empty() and shader_metadata_pending:
		# The actual worker already performed both native calls on this exact
		# Shader. Publish only the original shared source-text metadata on main.
		operation = "frame_shader_metadata"
		Materials.declared_uniforms(current_shader)
		shader_job = null
		current_shader = null
		shader_metadata_pending = false
		preparation_index += 1
		if preparation_index == frame_shaders.size():
			preparation_index = 0
			preparation_stage = "frame_component_methods"
	elif preparation_error.is_empty():
		progress = shader_job.prepare_immutable_interface_step()
		preparation_error = str(progress.get("error", ""))
		if progress.get("operation") == "publish_native_shader_interface":
			if shader_job.native_jobs.size() != 1 or shader_job.immutable_interface_prepared:
				preparation_error = "The audited job must publish exactly one native Shader interface"
			else:
				shader_metadata_pending = true
				var native: Dictionary = shader_job.native_jobs[0].duplicate(true)
				native.ordinal = preparation_index
				native.shader_id = current_shader.get_instance_id()
				native_shader_jobs.append(native)
	var observation := {"operation": operation, "ordinal": ordinal,
		"us": Time.get_ticks_usec() - began, "progress": progress}
	preparation_units.append(observation)
	return {"complete": false, "error": preparation_error, "operation": operation,
		"unit": observation, "native_ready": native_ready,
		"original_native_bank_ready": native_bank.interface_ready}


func drain_immutable_interface_step() -> Dictionary:
	if shader_job != null:
		var progress: Dictionary = shader_job.drain_immutable_interface_step()
		if not progress.complete:
			return progress
		# No later Shader, metadata publication or ready claim on cancellation.
		shader_job = null
		current_shader = null
		shader_metadata_pending = false
	if kernel != null and kernel.program != null and kernel.program.unit_pending:
		return {"complete": false, "operation": "drain_current_kernel_callback"}
	return {"complete": true, "operation": "current_actual_resource_work_finished"}
