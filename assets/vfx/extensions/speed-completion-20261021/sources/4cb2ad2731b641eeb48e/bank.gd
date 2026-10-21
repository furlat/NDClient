extends "res://assets/vfx/extensions/speed-completion-20261021/sources/de84eb1f92f545a203b4/bank.gd"
## Resource-only publication of the exact closed-mask bank. No owner, clock
## instance, source sample or alternative material is constructed here.
const ShaderJob = preload("res://assets/vfx/extensions/speed-completion-20261021/sources/75b200daec4a20076a81/cloud_bank.gd")
@export var source_bank: Resource:
	set(value):
		source_bank = value
		if value != null:
			original_bank = value.original_bank
			debris_material = value.debris_material
			native_program_sha256 = value.native_program_sha256
			native_uniforms = value.native_uniforms
			albedo_uniform = value.albedo_uniform
			adapter_script = value.adapter_script
			pool_required = value.pool_required
			provenance = value.provenance
var preparation_stage := "validate"
var preparation_index := 0
var preparation_error := ""
var preparation_units: Array[Dictionary] = []
var shaders: Array[Shader] = []
var prepared_shaders: Dictionary = {}
var shader_job: Resource
var current_shader: Shader
var shader_metadata_pending := false
var native_shader_jobs: Array[Dictionary] = []


func _validate_property(property: Dictionary) -> void:
	if str(property.name) != "source_bank" and int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
		# Serializing inherited exports would clone the admitted native graph.
		# Retain only the exact source-bank reference and restore its aliases.
		property.usage = int(property.usage) & ~PROPERTY_USAGE_STORAGE


func validation_error() -> String:
	if source_bank == null or source_bank.original_bank == null or source_bank.original_bank.donor_bank == null:
		return "Exact closed-mask Wind/original donor bank is missing"
	if source_bank.get_script() != preload("res://assets/vfx/extensions/speed-completion-20261021/sources/de84eb1f92f545a203b4/bank.gd"):
		return "Only the qualified closed-mask Wind bank is admitted"
	if original_bank != source_bank.original_bank or debris_material != source_bank.debris_material:
		return "Original Wind Resource identities changed"
	if debris_material == null or debris_material.shader == null:
		return "Exact native debris material is missing"
	if debris_material.shader.code.sha256_text() != native_program_sha256 or albedo_uniform != "albedo" or albedo_uniform not in native_uniforms:
		return "Exact native debris program/binding changed"
	if original_bank.flow_materials.size() != 3 or original_bank.hit_materials.size() != 2:
		return "The qualified Wind source requires its original three flow/two contact materials"
	for material: ShaderMaterial in original_bank.flow_materials + original_bank.hit_materials:
		if material == null or material.shader == null:
			return "Original Wind Shader operand is missing"
	return ""


func shader_job_error() -> String:
	if shader_job == null or shader_job.get_script() != ShaderJob:
		return "Only the exact audited Shader job is admitted"
	if preparation_stage != "shader" or current_shader != shaders[preparation_index]:
		return "Actual Wind Shader ordinal/identity changed"
	if not shader_job.node_specs.is_empty() or shader_job.material_specs.size() != 1 or shader_job.material_specs[0].size() != 1 or shader_job.material_specs[0].get("shader") != current_shader:
		return "Wind composes zero nodes and exactly one actual Shader"
	if shader_job.immutable_interface_prepared or shader_job._prepare_node != 0 or shader_job._prepare_material != 0 or shader_job._prepare_material_step != (1 if shader_metadata_pending else 0):
		return "Wind must never enter a Cloud node/material/ready stage"
	return ""


func _shader_step() -> Dictionary:
	if shader_job == null:
		current_shader = shaders[preparation_index]
		if prepared_shaders.has(current_shader):
			preparation_index += 1
			return {"operation": "original_shader_alias_already_published"}
		shader_job = ShaderJob.new()
		shader_job.material_specs.append({"shader": current_shader})
	preparation_error = shader_job_error()
	if not preparation_error.is_empty():
		return {}
	if shader_metadata_pending:
		Interfaces.declared_uniforms(current_shader)
		prepared_shaders[current_shader] = true
		shader_job = null
		current_shader = null
		shader_metadata_pending = false
		preparation_index += 1
		return {"operation": "original_shader_metadata"}
	var progress: Dictionary = shader_job.prepare_immutable_interface_step()
	preparation_error = str(progress.get("error", ""))
	if progress.get("operation") == "publish_native_shader_interface":
		if shader_job.native_jobs.size() != 1 or shader_job.immutable_interface_prepared:
			preparation_error = "Exact Wind Shader job did not stop at native-interface publication"
		else:
			shader_metadata_pending = true
			var native: Dictionary = shader_job.native_jobs[0].duplicate(true)
			native.ordinal = preparation_index
			native.shader_id = current_shader.get_instance_id()
			native_shader_jobs.append(native)
	return progress


func prepare_immutable_interface_step() -> Dictionary:
	if interface_ready or not preparation_error.is_empty():
		return {"complete": interface_ready, "error": preparation_error}
	var began := Time.get_ticks_usec()
	var operation := preparation_stage
	var ordinal := preparation_index
	var progress: Dictionary = {}
	match preparation_stage:
		"validate":
			preparation_error = validation_error()
			if preparation_error.is_empty():
				donor_bank = original_bank.donor_bank
				flow_materials.assign(original_bank.flow_materials)
				hit_materials.assign(original_bank.hit_materials)
				grid = donor_bank.grid
				debris_mesh = donor_bank.debris_mesh
				hit_mesh = donor_bank.hit_mesh
				feed_material = donor_bank.feed_material
				source_parameters = donor_bank.source_parameters
				source_phase = donor_bank.source_phase
				source_hashes = donor_bank.source_hashes
				for material: ShaderMaterial in flow_materials + hit_materials:
					shaders.append(material.shader)
				shaders.append(debris_material.shader)
				preparation_stage = "clock_pool"
		"clock_pool":
			if pool_required:
				Clock.ensure_pool()
			preparation_stage = "shader"
		"shader":
			progress = _shader_step()
			if preparation_index == shaders.size():
				preparation_index = 0
				preparation_stage = "original_material_properties"
		"original_material_properties":
			var material: ShaderMaterial = (flow_materials + hit_materials)[preparation_index]
			material.get_property_list()
			preparation_index += 1
			if preparation_index == 5:
				preparation_index = 0
				preparation_stage = "original_mesh_rid"
		"original_mesh_rid":
			var mesh: Mesh = [grid, debris_mesh, hit_mesh][preparation_index]
			mesh.get_rid()
			preparation_index += 1
			if preparation_index == 3:
				preparation_index = 0
				preparation_stage = "original_methods"
		"original_methods":
			Methods.methods(adapter_script)
			preparation_stage = "original_material_rid"
		"original_material_rid":
			var material: ShaderMaterial = (flow_materials + hit_materials)[preparation_index]
			material.get_rid()
			preparation_stage = "original_material_metadata"
		"original_material_metadata":
			var material: ShaderMaterial = (flow_materials + hit_materials)[preparation_index]
			Interfaces.declared_uniforms(material.shader)
			preparation_index += 1
			preparation_stage = "original_material_rid" if preparation_index < 5 else "original_feed_properties"
		"original_feed_properties":
			feed_material.get_property_list()
			preparation_stage = "original_feed_rid"
		"original_feed_rid":
			feed_material.get_rid()
			preparation_stage = "debris_properties"
		"debris_properties":
			debris_material.get_property_list()
			preparation_stage = "debris_rid"
		"debris_rid":
			debris_material.get_rid()
			preparation_stage = "debris_metadata"
		"debris_metadata":
			Interfaces.declared_uniforms(debris_material.shader)
			preparation_stage = "publish"
		"publish":
			interface_ready = true
			preparation_stage = "ready"
		_:
			preparation_error = "Unknown Wind immutable preparation stage"
	var unit := {"operation": operation, "ordinal": ordinal, "us": Time.get_ticks_usec() - began, "progress": progress}
	preparation_units.append(unit)
	return {"complete": interface_ready, "error": preparation_error, "operation": operation, "unit": unit}


func prepare_immutable_interface() -> void:
	# Explicit authoring compatibility only. Runtime uses the step hook.
	while not interface_ready and preparation_error.is_empty():
		prepare_immutable_interface_step()
		if shader_job != null:
			if current_shader.has_meta(ShaderJob.CLAIM):
				var claimant: Resource = current_shader.get_meta(ShaderJob.CLAIM).get_ref()
				if claimant != null and claimant != shader_job:
					claimant.prepare_immutable_interface()
			if shader_job._shader_thread != null:
				while shader_job._shader_thread.is_alive():
					RenderingServer.force_sync()
					OS.delay_usec(50)
	if not preparation_error.is_empty():
		push_error(preparation_error)


func drain_immutable_interface_step() -> Dictionary:
	if shader_job != null:
		var progress: Dictionary = shader_job.drain_immutable_interface_step()
		if not progress.complete:
			return progress
		shader_job = null
		current_shader = null
		shader_metadata_pending = false
	return {"complete": true, "operation": "current_actual_wind_resource_finished"}
