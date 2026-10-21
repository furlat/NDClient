extends "res://assets/vfx/extensions/speed-completion-20261021/sources/74aff669a545ff78af32/bank.gd"
## Family-only staging of the exact original immutable publication order.
## Native scene/material/Shader operands remain the original Resource objects.
const OriginalTypedBank = preload("res://assets/vfx/extensions/speed-completion-20261021/sources/74aff669a545ff78af32/bank.gd")
const NativeBank = preload("res://assets/vfx/extensions/speed-completion-20261021/sources/af130afa9a6b5eea94b6/bank.gd")
const PreparedKernel = preload("res://assets/vfx/extensions/speed-completion-20261021/sources/ed4ecabf8c0abd389e0e/kernel.gd")
const OriginalClock = preload("res://assets/vfx/sources/c0017ad639184b208deb/occurrence_clock.gd")
var preparation_stage := "typed_methods"
var preparation_index := 0
var preparation_error := ""
var stored_meshes: Array[Mesh] = []
var preparation_units: Array[Dictionary] = []


func validation_error() -> String:
	if original_frame_bank == null or original_frame_bank.get_script() != OriginalTypedBank:
		return "The exact original typed Patches bank is required"
	if native_bank == null or native_bank.get_script() != NativeBank \
		or native_bank != original_frame_bank.native_bank or native_bank.scene == null:
		return "The unchanged actual native Patches bank/scene identity is required"
	if frame_shaders != original_frame_bank.frame_shaders or frame_shaders.size() != native_bank.material_piece_indices.size():
		return "The unchanged actual frame Shader identities are required"
	if kernel == null or kernel.get_script() != PreparedKernel or kernel.prepared_code == null:
		return "The explicit prepared frame kernel/code is required"
	return kernel.prepared_code.validate_data()


func prepare_immutable_interface_step() -> Dictionary:
	if interface_ready and kernel != null and not kernel.available():
		# Original Bank always revisits the kernel hook. Closing the shared host
		# invalidates only pipeline readiness, not completed immutable materials.
		interface_ready = false
		preparation_stage = "kernel"
	if interface_ready or not preparation_error.is_empty():
		return {"complete": interface_ready, "error": preparation_error, "operation": "already_complete_or_failed"}
	var began := Time.get_ticks_usec()
	var operation: String = preparation_stage
	var observation := {"operation": operation, "ordinal": preparation_index}
	var progress: Dictionary = {}
	if preparation_stage == "typed_methods":
		preparation_error = validation_error()
		if preparation_error.is_empty():
			Bindings.methods(VfxPackageIO_cb4c06933b.resource("res://assets/vfx/extensions/speed-completion-20261021/sources/6e801bbcee540821f1cf/component.gd"))
			typed_methods_prepared = true
			# The old NativeBank.prepare call is a no-op if already published.
			preparation_stage = "frame_shader" if native_bank.interface_ready else "native_adapter_methods"
	elif preparation_stage == "native_adapter_methods":
		Bindings.methods(VfxPackageIO_cb4c06933b.resource(native_bank.adapter_script))
		preparation_stage = "native_clock_pool"
	elif preparation_stage == "native_clock_pool":
		for material: ShaderMaterial in native_bank.materials:
			if material.get_meta("factory_clock_pool_required", false):
				OriginalClock.ensure_pool()
				break
		preparation_stage = "native_material" if not native_bank.materials.is_empty() else "native_mesh_inventory"
	elif preparation_stage == "native_material":
		var material: ShaderMaterial = native_bank.materials[preparation_index]
		observation.material_id = material.get_instance_id()
		material.get_rid()
		# Preserve actual native Material admission BEFORE original Shader reflection.
		Materials.declared_uniforms(material.shader)
		preparation_index += 1
		if preparation_index == native_bank.materials.size():
			preparation_index = 0
			preparation_stage = "native_mesh_inventory"
	elif preparation_stage == "native_mesh_inventory":
		var state: SceneState = native_bank.scene.get_state()
		for index: int in state.get_node_count():
			for property: int in state.get_node_property_count(index):
				var value: Variant = state.get_node_property_value(index, property)
				if value is Mesh:
					stored_meshes.append(value)
		observation.mesh_operands = stored_meshes.size()
		preparation_stage = "native_mesh" if not stored_meshes.is_empty() else "native_ready"
	elif preparation_stage == "native_mesh":
		stored_meshes[preparation_index].get_rid()
		preparation_index += 1
		if preparation_index == stored_meshes.size():
			preparation_index = 0
			preparation_stage = "native_ready"
	elif preparation_stage == "native_ready":
		# Exactly the original NativeBank operation list has now completed. No
		# occurrence, actor pose, sample or fake original readiness was substituted.
		native_bank.interface_ready = true
		stored_meshes.clear()
		preparation_stage = "frame_shader" if not frame_shaders.is_empty() else "frame_component_methods"
	elif preparation_stage == "frame_shader":
		var shader: Shader = frame_shaders[preparation_index]
		observation.shader_id = shader.get_instance_id()
		shader.get_rid()
		shader.get_shader_uniform_list()
		Materials.declared_uniforms(shader)
		preparation_index += 1
		if preparation_index == frame_shaders.size():
			preparation_index = 0
			preparation_stage = "frame_component_methods"
	elif preparation_stage == "frame_component_methods":
		Bindings.methods(VfxPackageIO_cb4c06933b.resource("res://assets/vfx/extensions/speed-completion-20261021/sources/c19fb6c081fb50b97c27/component.gd"))
		native_ready = true
		preparation_stage = "kernel"
	elif preparation_stage == "kernel":
		progress = kernel.prepare_immutable_interface_step()
		preparation_error = str(progress.get("error", ""))
		interface_ready = preparation_error.is_empty() and native_ready and bool(progress.complete) and kernel.available()
	else:
		preparation_error = "Unknown prepared Patches bank publication stage"
	observation.us = Time.get_ticks_usec() - began
	preparation_units.append(observation)
	var result := {"complete": interface_ready, "error": preparation_error,
		"operation": operation, "unit": observation, "native_ready": native_ready,
		"original_native_bank_ready": native_bank.interface_ready if native_bank != null else false}
	if not progress.is_empty():
		result.kernel_progress = progress
	return result

const VfxPackageIO_cb4c06933b = preload("res://assets/vfx/extensions/speed-completion-20261021/scoped_resource_io.gd")
