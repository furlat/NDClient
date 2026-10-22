extends "res://assets/vfx/extensions/cloud-body-speed-20261021/sources/52c4080c85cdb2003ba4/bank.gd"
## Preserve every original interface operation; only the exact Kernel changes.
const WorkerKernel = preload("res://assets/vfx/extensions/cloud-body-speed-20261021/sources/484e4f1c372b19a73fc6/kernel.gd")


func validation_error() -> String:
	if original_frame_bank == null or original_frame_bank.get_script() != OriginalTypedBank:
		return "The exact original typed Patches bank is required"
	if native_bank == null or native_bank.get_script() != NativeBank \
		or native_bank != original_frame_bank.native_bank or native_bank.scene == null:
		return "The unchanged actual native Patches bank/scene identity is required"
	if frame_shaders != original_frame_bank.frame_shaders or frame_shaders.size() != native_bank.material_piece_indices.size():
		return "The unchanged actual frame Shader identities are required"
	if kernel == null or kernel.get_script() != WorkerKernel or kernel.prepared_code == null:
		return "The explicit immutable-unit worker kernel/code is required"
	return kernel.prepared_code.validate_data()


func drain_immutable_interface_step() -> Dictionary:
	if shader_job != null:
		# Kernel creation follows all Shader jobs, so no Kernel unit exists at
		# this original current-Shader drain boundary.
		return super.drain_immutable_interface_step()
	if kernel != null:
		return kernel.drain_current_preparation()
	return {"complete": true, "operation": "no_current_immutable_unit"}
