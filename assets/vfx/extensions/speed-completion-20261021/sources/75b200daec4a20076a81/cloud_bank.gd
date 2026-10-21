extends "res://assets/vfx/extensions/speed-completion-20261021/sources/8e5ce8b7dadc2e8b194d/cloud_bank.gd"
## New optional bank only. Original bank code/identity/evidence stay frozen.
const FrozenWorker = preload("res://assets/vfx/extensions/speed-completion-20261021/sources/8e5ce8b7dadc2e8b194d/cloud_bank.gd")


static func _native_interface(shader: Shader) -> Dictionary:
	# The original worker binds Callable(get_script(), "_native_interface").
	# Godot does not expose an inherited static method on a derived Script RID.
	# Declare this exact entrypoint locally; keep its original function body,
	# Shader operand and Script-only Callable ownership in the frozen base.
	return FrozenWorker._native_interface(shader)


func drain_immutable_interface_step() -> Dictionary:
	if _shader_thread != null:
		if _shader_thread.is_alive():
			return {"complete": false, "operation": "drain_current_native_shader"}
		# is_alive false establishes completion before this ordinary join.
		# No force_sync, blocking loop, next shader or ready publication here.
		_shader_result = _shader_thread.wait_to_finish()
		_shader_thread = null
	_shader_result.clear()
	_release_claim()
	return {"complete": true, "operation": "current_native_shader_joined"}
