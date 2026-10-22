extends "res://assets/vfx/extensions/spike-readiness-20261022/sources/5105bf8a41463fcc3e67/direct_restore_bank.gd"
## The existing Spike constructor is unchanged. Only immutable publication is
## split into measured units; each Shader uses the audited interface worker.
const OriginalBank = preload("res://assets/vfx/extensions/spike-readiness-20261022/sources/5105bf8a41463fcc3e67/direct_restore_bank.gd")
const ShaderJob = preload("res://assets/vfx/extensions/speed-completion-20261021/sources/75b200daec4a20076a81/cloud_bank.gd")
const OperandReferences = preload("res://assets/vfx/extensions/owner-fields-v2-20261021/sources/718478933d60b6c71150/scene_operand_references.gd")
const Materials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
const Bindings = preload("res://assets/vfx/sources/dabf568b4506db4883ad/occurrence_bindings.gd")
const AnimationTimes = preload("res://assets/vfx/extensions/continuation42-20261020/sources/e39a2969814c1bbdbded/animation_key_times.gd")
const Clock = preload("res://assets/vfx/sources/c0017ad639184b208deb/occurrence_clock.gd")
@export var original_bank: Resource:
	set(value):
		original_bank = value
		if value != null:
			for property: Dictionary in value.get_property_list():
				if int(property.usage) & PROPERTY_USAGE_STORAGE and int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
					var operand: Variant = value.get(property.name)
					# Container writes belong to this preparation. Native resources
					# remain the exact original references, including nested operands.
					set(property.name, operand.duplicate(true) if operand is Array or operand is Dictionary else operand)
var preparation_stage := "validate_original"
var preparation_error := ""
var preparation_index := 0
var preparation_substep := 0
var scene_node := 0
var scene_property := 0
var construction_state: SceneState
var recipient_state: SceneState
var actual_materials: Dictionary = {}
var animation_seen: Dictionary = {}
var resource_seen: Dictionary = {}
var resource_stack: Array[Dictionary] = []
var prepared_shaders: Dictionary = {}
var shader_job: Resource
var current_shader: Shader
var native_shader_jobs: Array[Dictionary] = []
var preparation_units: Array[Dictionary] = []
var synchronous_authoring_used := false


func _validate_property(property: Dictionary) -> void:
	if str(property.name) != "original_bank" and int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
		property.usage = int(property.usage) & ~PROPERTY_USAGE_STORAGE


func validation_error() -> String:
	if original_bank == null or original_bank.get_script() != OriginalBank:
		return "Only an exact original DirectRestore bank is admitted"
	if construction_source == null or construction_source.scene == null or scene == null:
		return "Both original saved SceneState operands are required"
	if adapter_script == null or adapter_script.resource_path != "res://assets/vfx/extensions/spike-readiness-20261022/sources/3f7c4d0944341cd9d43c/spike_leaf.gd":
		return "Only the unchanged actual-owner Spike leaf is admitted"
	if not provenance.has("seed_instance_aliasing") or plain_flow:
		return "The existing seed-instance Spike preparation is required"
	if construction_program != original_bank.construction_program or construction_source != original_bank.construction_source:
		return "Original generated program and construction-source identities changed"
	return ""


func shader_job_error(shader: Shader) -> String:
	if shader == null or shader_job == null:
		return "A native interface job needs its actual Shader"
	if current_shader != shader or shader_job.get_script() != ShaderJob \
		or not shader_job.node_specs.is_empty() or shader_job.material_specs.size() != 1 \
		or shader_job.material_specs[0].size() != 1 or shader_job.material_specs[0].shader != shader \
		or shader_job.immutable_interface_prepared or shader_job._prepare_node != 0 \
		or shader_job._prepare_material != 0 or shader_job._prepare_material_step != 0:
		return "The job may only publish the current single Shader interface"
	return ""


func _shader_step(shader: Shader) -> Dictionary:
	if shader == null:
		return {"ready": false, "error": "A native material has no actual Shader"}
	if prepared_shaders.has(shader):
		return {"ready": true}
	if shader_job == null:
		current_shader = shader
		shader_job = ShaderJob.new()
		shader_job.material_specs.append({"shader": shader})
	var error := shader_job_error(shader)
	if not error.is_empty():
		return {"ready": false, "error": error}
	var progress: Dictionary = shader_job.prepare_immutable_interface_step()
	if progress.get("operation") == "publish_native_shader_interface":
		if shader_job.native_jobs.size() != 1 or shader_job.immutable_interface_prepared \
			or shader_job._prepare_material_step != 1:
			return {"ready": false, "error": "Unexpected Cloud stage or native Shader publication count"}
		var native: Dictionary = shader_job.native_jobs[0].duplicate(true)
		native.shader_id = shader.get_instance_id()
		native.ordinal = native_shader_jobs.size()
		native_shader_jobs.append(native)
		prepared_shaders[shader] = true
		shader_job = null
		current_shader = null
	# Return after the real worker unit. The original material/metadata operation
	# occurs on the next call; Cloud material/node/ready stages never execute.
	return {"ready": false, "error": str(progress.get("error", "")), "worker": progress}


func _compile_binding_slots() -> void:
	initial_material_slots = _materials(material_bindings)
	world_slots = _materials(world_material_bindings)
	shader_slots = _materials(all_shader_bindings)
	emission_slots = _nodes(emission_start_edges)
	player_slots = _nodes(player_paths)
	light_slots = _nodes(light_paths)
	for field: String in node_members:
		member_slots[field] = _nodes([node_members[field]])[0]
	for field: String in node_arrays:
		array_slots[field] = _nodes(node_arrays[field])
	for field: String in material_members:
		material_member_slots[field] = _description(material_members[field])
	for field: String in material_arrays:
		var slots := PackedInt32Array()
		for description: Dictionary in material_arrays[field]:
			slots.append(_description(description))
		material_array_slots[field] = slots


func _binding_error() -> String:
	var bindings: Array = material_bindings + world_material_bindings + all_shader_bindings
	for description: Dictionary in material_members.values():
		if not description.has("extra"):
			bindings.append(description.binding)
	for descriptions: Array in material_arrays.values():
		for description: Dictionary in descriptions:
			if not description.has("extra"):
				bindings.append(description.binding)
	for binding: Dictionary in bindings:
		if binding.get("kind") != "override" or int(binding.get("next_pass_depth", 0)) != 0 \
			or not material_slots.has(str(binding.get("node", "")).trim_prefix("./")):
			return "An original private material address no longer resolves"
	var paths: Array = []
	paths.append_array(emission_start_edges)
	paths.append_array(player_paths)
	paths.append_array(light_paths)
	paths.append_array(node_members.values())
	for values: Array in node_arrays.values():
		paths.append_array(values)
	for path: Variant in paths:
		if not node_slots.has(str(path).trim_prefix("./")):
			return "An original controller node address no longer resolves"
	return ""


func _operand_step(value: Variant) -> Dictionary:
	if value is ShaderMaterial:
		var progress := _shader_step(value.shader)
		if not progress.ready:
			return progress
		if preparation_substep == 0:
			value.get_property_list()
		elif preparation_substep == 1:
			value.get_rid()
		else:
			Materials.declared_uniforms(value.shader)
		preparation_substep += 1
		if preparation_substep == 3:
			preparation_substep = 0
			preparation_index += 1
	elif value is Shader:
		var progress := _shader_step(value)
		if not progress.ready:
			return progress
		if preparation_substep == 0:
			value.get_rid()
			preparation_substep = 1
		else:
			Materials.declared_uniforms(value)
			preparation_substep = 0
			preparation_index += 1
	else:
		if value is Mesh or value is Shape3D or value is Texture:
			value.get_rid()
		preparation_index += 1
	return {"ready": true}


func _push_resource(value: Resource) -> void:
	if resource_seen.has(value) or value is Script or value is Texture2D or value is Shader:
		return
	resource_seen[value] = true
	resource_stack.append({"value": value, "stage": "animation", "properties": [], "property": 0, "surface": 0})


func _resource_step() -> Dictionary:
	var frame: Dictionary = resource_stack.back()
	var value: Resource = frame.value
	if frame.stage == "animation":
		if value is Animation:
			AnimationTimes.restore_before_publication(value)
		frame.stage = "properties"
	elif frame.stage == "properties":
		if value is ShaderMaterial:
			var progress := _shader_step(value.shader)
			if not progress.ready:
				return progress
		frame.properties = value.get_property_list()
		frame.stage = "rid"
	elif frame.stage == "rid":
		if value is Material or value is Mesh:
			value.get_rid()
		frame.stage = "shader_metadata"
	elif frame.stage == "shader_metadata":
		if value is ShaderMaterial and value.shader != null:
			Materials.declared_uniforms(value.shader)
		frame.stage = "children"
	elif frame.stage == "children":
		if int(frame.property) < frame.properties.size():
			var property: Dictionary = frame.properties[frame.property]
			frame.property += 1
			if int(property.usage) & PROPERTY_USAGE_STORAGE:
				var child: Variant = value.get(property.name)
				if child is Resource:
					_push_resource(child)
		else:
			frame.stage = "surfaces"
	else:
		if value is Mesh and int(frame.surface) < value.get_surface_count():
			var material: Material = value.surface_get_material(frame.surface)
			frame.surface += 1
			if material != null:
				_push_resource(material)
		else:
			resource_stack.pop_back()
	return {"ready": true}


func _next_scene_property(state: SceneState) -> void:
	scene_property += 1
	if scene_property == state.get_node_property_count(scene_node):
		scene_node += 1
		scene_property = 0


func _skip_empty_nodes(state: SceneState) -> void:
	while scene_node < state.get_node_count() and state.get_node_property_count(scene_node) == 0:
		scene_node += 1


func _prepare_unit() -> Dictionary:
	if interface_ready or not preparation_error.is_empty():
		return {"complete": interface_ready, "error": preparation_error, "operation": "complete_or_failed"}
	var began := Time.get_ticks_usec()
	var operation: String = preparation_stage
	var ordinal := preparation_index
	var observation := {"operation": operation, "ordinal": ordinal,
		"substep": preparation_substep, "scene_node": scene_node, "scene_property": scene_property}
	if preparation_stage == "recipient_resource" and not resource_stack.is_empty():
		var frame: Dictionary = resource_stack.back()
		observation.resource_class = frame.value.get_class()
		observation.resource_id = frame.value.get_instance_id()
		observation.resource_stage = frame.stage
		observation.resource_property = frame.property
		observation.resource_surface = frame.surface
	var progress: Dictionary = {}
	if preparation_stage == "validate_original":
		preparation_error = validation_error()
		if preparation_error.is_empty():
			construction_state = construction_source.scene.get_state()
			preparation_stage = "direct_node"
	elif preparation_stage == "direct_node":
		if scene_node < construction_state.get_node_count():
			var path := str(construction_state.get_node_path(scene_node)).trim_prefix("./")
			node_slots[path] = scene_node
			preparation_stage = "direct_property"
		else:
			preparation_stage = "compile_binding_slots"
	elif preparation_stage == "direct_property":
		if scene_property < construction_state.get_node_property_count(scene_node):
			var value: Variant = construction_state.get_node_property_value(scene_node, scene_property)
			if value is ShaderMaterial:
				assert(str(construction_state.get_node_property_name(scene_node, scene_property)) == "material_override")
				if not actual_materials.has(value):
					actual_materials[value] = actual_materials.size()
				var path := str(construction_state.get_node_path(scene_node)).trim_prefix("./")
				material_slots[path] = actual_materials[value]
			scene_property += 1
		else:
			scene_node += 1
			scene_property = 0
			preparation_stage = "direct_node"
	elif preparation_stage == "compile_binding_slots":
		preparation_error = _binding_error()
		if preparation_error.is_empty():
			_compile_binding_slots()
			preparation_stage = "original_operand_reference"
	elif preparation_stage == "original_operand_reference":
		if preparation_index < source_operand_references.size():
			var reference: Dictionary = source_operand_references[preparation_index]
			var actual: Variant = OperandReferences.resolve(construction_source, reference)
			if not OperandReferences.contains_resource(actual):
				preparation_error = "An original resource-bearing operand address no longer resolves"
			else:
				construction_operands[int(reference.index)] = actual
				preparation_index += 1
		else:
			preparation_index = 0
			preparation_stage = "construction_operand"
	elif preparation_stage == "construction_operand":
		# Scalars/containers have no operation in the original native loop.
		# Skip them together rather than introducing hundreds of fake units.
		while preparation_index < construction_operands.size() and not construction_operands[preparation_index] is Resource:
			preparation_index += 1
		if preparation_index < construction_operands.size():
			observation.ordinal = preparation_index
			observation.resource_class = construction_operands[preparation_index].get_class()
			observation.resource_id = construction_operands[preparation_index].get_instance_id()
			progress = _operand_step(construction_operands[preparation_index])
		else:
			preparation_index = 0
			preparation_stage = "native_material_template"
	elif preparation_stage == "native_material_template":
		if preparation_index < native_material_templates.size():
			# Original TypedBank only reflects templates. The same Shader was
			# already admitted when present in construction operands.
			var material: ShaderMaterial = native_material_templates[preparation_index]
			progress = _shader_step(material.shader)
			if progress.ready:
				material.get_property_list()
				preparation_index += 1
		else:
			preparation_index = 0
			preparation_stage = "construction_program_methods"
	elif preparation_stage == "construction_program_methods":
		Bindings.methods(construction_program)
		preparation_stage = "shared_clock_pool"
	elif preparation_stage == "shared_clock_pool":
		if provenance.get("requires_shared_clock", false):
			Clock.ensure_pool()
		recipient_state = scene.get_state()
		scene_node = 0
		scene_property = 0
		preparation_stage = "exact_animation_value"
	elif preparation_stage == "exact_animation_value":
		_skip_empty_nodes(recipient_state)
		if scene_node < recipient_state.get_node_count():
			AnimationTimes._prepare_value(recipient_state.get_node_property_value(scene_node, scene_property), animation_seen)
			_next_scene_property(recipient_state)
		else:
			preparation_stage = "adapter_methods"
	elif preparation_stage == "adapter_methods":
		if adapter_script != null:
			Bindings.methods(adapter_script)
		recipient_state = scene.get_state()
		scene_node = 0
		scene_property = 0
		preparation_stage = "recipient_resource"
	elif preparation_stage == "recipient_resource":
		if not resource_stack.is_empty():
			progress = _resource_step()
		else:
			_skip_empty_nodes(recipient_state)
			if scene_node < recipient_state.get_node_count():
				var value: Variant = recipient_state.get_node_property_value(scene_node, scene_property)
				_next_scene_property(recipient_state)
				if value is Resource:
					_push_resource(value)
			else:
				preparation_stage = "publish_complete"
	elif preparation_stage == "publish_complete":
		construction_state = null
		recipient_state = null
		actual_materials.clear()
		animation_seen.clear()
		resource_seen.clear()
		prepared_shaders.clear()
		interface_ready = true
	else:
		preparation_error = "Unknown Spike immutable publication stage"
	if not str(progress.get("error", "")).is_empty():
		preparation_error = str(progress.error)
	observation.us = Time.get_ticks_usec() - began
	if progress.has("worker"):
		observation.worker = progress.worker
	preparation_units.append(observation)
	var result := {"complete": interface_ready, "error": preparation_error,
		"operation": operation, "unit": observation}
	if progress.has("worker"):
		result.worker = progress.worker
	return result


func prepare_immutable_interface_step() -> Dictionary:
	# Admission calls once per rendered frame. Keep cheap original operations
	# together instead of introducing a frame wait for each scalar/property.
	# The target is inclusive wall time, not a promise that an atomic native
	# call can be split or never exceed it. Its full cost remains in both logs.
	var began := Time.get_ticks_usec()
	var first_unit := preparation_units.size()
	var progress: Dictionary = {}
	while true:
		progress = _prepare_unit()
		if progress.complete or not str(progress.get("error", "")).is_empty() \
			or progress.has("worker") or Time.get_ticks_usec() - began >= 1000:
			break
	var us := Time.get_ticks_usec() - began
	var result := {"complete": interface_ready, "error": preparation_error,
		"operation": "prepare_spike_resource_batch", "last_operation": progress.operation,
		"first_unit": first_unit, "unit_count": preparation_units.size() - first_unit,
		"inclusive_us": us, "target_us": 1000, "target_overshoot_us": maxi(0, us - 1000)}
	if progress.has("worker"):
		result.worker = progress.worker
	return result


func prepare_immutable_interface() -> void:
	if interface_ready:
		return
	# Retain the old explicit synchronous authoring API by delegation. The
	# actual owner path requires ready resources and selects the step hook.
	# Do not mix old synchronous work with a partially started Shader worker.
	if preparation_stage != "validate_original" or shader_job != null:
		push_error("Finish or drain the actual progressive Spike job before synchronous authoring")
		return
	preparation_error = validation_error()
	if not preparation_error.is_empty():
		push_error(preparation_error)
		return
	synchronous_authoring_used = true
	super.prepare_immutable_interface()


func drain_immutable_interface_step() -> Dictionary:
	if shader_job != null:
		var progress: Dictionary = shader_job.drain_immutable_interface_step()
		if not progress.complete:
			return progress
		# Do not publish metadata, advance the ordinal, begin another Shader or
		# mark this bank ready while its cancelled caller drains current work.
		shader_job = null
		current_shader = null
	return {"complete": true, "operation": "current_spike_resource_unit_finished"}
