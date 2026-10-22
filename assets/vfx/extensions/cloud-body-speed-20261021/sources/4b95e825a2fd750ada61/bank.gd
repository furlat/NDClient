extends "res://assets/vfx/extensions/speed-completion-20261021/sources/75b200daec4a20076a81/cloud_bank.gd"
## Owner-local display aliases; native processes and original bank stay exact.
const NativeShaderWorker = preload("res://assets/vfx/extensions/speed-completion-20261021/sources/8e5ce8b7dadc2e8b194d/cloud_bank.gd")
@export var shared_display_program: Script
@export var source_program_sha256 := ""
@export var shared_program_sha256 := ""
var display_sharing_checked := false
var display_sharing_active := false


func _validate_property(property: Dictionary) -> void:
	if str(property.name) in ["shared_display_program", "source_program_sha256", "shared_program_sha256"]:
		return
	super._validate_property(property)


static func _native_interface(shader: Shader) -> Dictionary:
	return NativeShaderWorker._native_interface(shader)


func _configure_display_program() -> void:
	# Unknown layouts keep their original program/materials, including the
	# source's distinct per-cohort priority writer when cohort_count > 2.
	construction_program = original_bank.construction_program
	construction_program_receipt = original_bank.construction_program_receipt
	var original_receipt: Dictionary = original_bank.construction_program_receipt
	if shared_display_program == null or source_program_sha256.is_empty():
		return
	if original_receipt.get("sha256", "") != source_program_sha256:
		return
	if int(parameters.settings.get("cohort_count", 2)) != 2:
		return
	if node_specs.size() != 47 or material_specs.size() != 45 or material_bindings.size() != 22 or cohort_paths.size() != 22:
		return
	for group: Array in cohort_paths:
		if group.size() != 2:
			return
	construction_program = shared_display_program
	construction_program_receipt = original_receipt.duplicate(true)
	construction_program_receipt.sha256 = shared_program_sha256
	construction_program_receipt.owner_local_display_materials = 2
	construction_program_receipt.source_program_sha256 = source_program_sha256
	display_sharing_active = true


func prepare_immutable_interface_step() -> Dictionary:
	if not display_sharing_checked:
		if original_bank == null:
			_preparation_error = "Owner-local display preparation needs its exact original bank"
			return {"complete": false, "error": _preparation_error}
		_configure_display_program()
		display_sharing_checked = true
		return {"complete": false, "operation": "select_exact_owner_local_display_program", "display_sharing_active": display_sharing_active}
	return super.prepare_immutable_interface_step()
