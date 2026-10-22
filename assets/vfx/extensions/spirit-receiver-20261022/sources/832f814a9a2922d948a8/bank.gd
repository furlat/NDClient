extends Resource
## Immutable masked programs only; never constructs an owner or a private mask.
const References = preload("res://assets/vfx/extensions/owner-fields-v2-20261021/sources/718478933d60b6c71150/scene_operand_references.gd")
const Materials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
const ShaderJob = preload("res://assets/vfx/extensions/speed-completion-20261021/sources/75b200daec4a20076a81/cloud_bank.gd")
const SpiritBank = preload("res://assets/vfx/extensions/spirit-receiver-20261022/sources/0228862d3241f77bc1d4/bank_ready.gd")
const GroundBank = preload("res://assets/vfx/extensions/spirit-receiver-20261022/sources/5105bf8a41463fcc3e67/direct_restore_bank.gd")
@export var original_banks: Array[Resource] = []
@export var descriptors: Array[Dictionary] = []
@export var programs: Array[Shader] = []
var originals: Array[Shader] = []
var interface_ready := false
var preparation_error := ""
var preparation_index := 0
var preparation_stage := "resolve"
var shader_job: Resource
var native_parameters: Array[Dictionary] = []
var parameter_index := 0
var native_shader_jobs: Array[Dictionary] = []
var preparation_units: Array[Dictionary] = []


func resolve_original(description: Dictionary) -> Shader:
	if typeof(description.get("bank")) != TYPE_INT or int(description.bank) < 0 or int(description.bank) >= original_banks.size() \
		or typeof(description.get("rid_bank")) != TYPE_BOOL or typeof(description.get("material_value")) != TYPE_BOOL \
		or not description.get("reference") is Dictionary:
		return null
	var bank: Resource = original_banks[int(description.bank)]
	if bank == null or bank.get_script() != (SpiritBank if description.rid_bank else GroundBank):
		return null
	var source: Resource = bank.source_bank.construction_source if description.rid_bank else bank.construction_source
	var value: Variant = References.resolve(source, description.reference)
	if description.material_value:
		return value.shader if value is ShaderMaterial else null
	return value as Shader


func _resolve() -> String:
	if original_banks.size() != 2 or descriptors.size() != 2 or programs.size() != 2:
		return "Exact Spirit leaf/ground mask programs and original banks required"
	for bank: Resource in original_banks:
		if not bank.interface_ready:
			return "The actual original Spirit bank must be ready before mask publication"
	for index: int in descriptors.size():
		var original := resolve_original(descriptors[index])
		if original == null or programs[index] == null or original in originals:
			return "Missing or repeated actual original Shader identity"
		if original.code.sha256_text() != str(descriptors[index].get("source_code_sha256", "")) \
			or programs[index].code.sha256_text() != str(descriptors[index].get("masked_code_sha256", "")):
			return "The exact immutable source/masked Shader code changed"
		originals.append(original)
	return ""


func replacement(original: Shader) -> Shader:
	if not interface_ready:
		return null
	var index := originals.find(original)
	return null if index < 0 else programs[index]


func _job_error() -> String:
	if shader_job == null or shader_job.get_script() != ShaderJob:
		return "Only the exact audited Shader-interface job is admitted"
	if not shader_job.node_specs.is_empty() or shader_job.material_specs.size() != 1 \
		or shader_job.material_specs[0].size() != 1 or shader_job.material_specs[0].shader != programs[preparation_index]:
		return "Mask publication requires exactly the current Shader and no Cloud nodes/materials"
	if shader_job.immutable_interface_prepared or shader_job._prepare_node != 0 \
		or shader_job._prepare_material != 0 or shader_job._prepare_material_step != 0:
		return "Mask job crossed its native-interface-only boundary"
	return ""


func prepare_immutable_interface_step() -> Dictionary:
	var began := Time.get_ticks_usec()
	if not preparation_error.is_empty():
		return {"complete": false, "error": preparation_error}
	if interface_ready:
		return {"complete": true}
	var operation := preparation_stage
	var ordinal := preparation_index
	var progress := {}
	match preparation_stage:
		"resolve":
			preparation_error = _resolve()
			if preparation_error.is_empty():
				preparation_stage = "shader"
		"shader":
			if shader_job == null:
				shader_job = ShaderJob.new()
				shader_job.material_specs.append({"shader": programs[preparation_index]})
			preparation_error = _job_error()
			if preparation_error.is_empty():
				progress = shader_job.prepare_immutable_interface_step()
				preparation_error = str(progress.get("error", ""))
				if progress.get("operation") == "publish_native_shader_interface":
					if shader_job.native_jobs.size() != 1 or shader_job.immutable_interface_prepared \
						or shader_job._prepare_material_step != 1:
						preparation_error = "Expected one completed joined native Shader interface"
					else:
						var native: Dictionary = shader_job.native_jobs[0].duplicate(true)
						native.ordinal = preparation_index
						native_shader_jobs.append(native)
						shader_job = null
						preparation_stage = "default_names"
		"default_names":
			# Original bank already published this exact Shader. New Shader RID
			# creation/reflection completed on its worker before any setter below.
			native_parameters.assign(RenderingServer.get_shader_parameter_list(originals[preparation_index].get_rid()))
			parameter_index = 0
			preparation_stage = "default_texture"
		"default_texture":
			if parameter_index < native_parameters.size():
				var name: StringName = native_parameters[parameter_index].name
				var texture: Texture = originals[preparation_index].get_default_texture_parameter(name)
				if texture != null:
					programs[preparation_index].set_default_texture_parameter(name, texture)
				parameter_index += 1
			else:
				native_parameters.clear()
				preparation_stage = "metadata"
		"metadata":
			Materials.declared_uniforms(programs[preparation_index])
			preparation_index += 1
			interface_ready = preparation_index == programs.size()
			preparation_stage = "ready" if interface_ready else "shader"
	var unit := {"operation": operation, "ordinal": ordinal, "parameter_index": parameter_index,
		"us": Time.get_ticks_usec() - began, "progress": progress}
	preparation_units.append(unit)
	return {"complete": interface_ready, "error": preparation_error, "operation": operation, "unit": unit}


func drain_immutable_interface_step() -> Dictionary:
	if shader_job != null:
		var progress: Dictionary = shader_job.drain_immutable_interface_step()
		if not progress.complete:
			return progress
		shader_job = null
	# No later default/metadata publication, ordinal advance or ready on drain.
	return {"complete": true, "operation": "current_actual_mask_shader_work_finished"}
