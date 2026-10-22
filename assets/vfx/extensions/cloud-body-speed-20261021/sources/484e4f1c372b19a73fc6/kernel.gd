extends "res://assets/vfx/extensions/cloud-body-speed-20261021/sources/70ba4efc12bbd762aa87/kernel.gd"
## Same native post-draw readiness and private-owner close refusal.
const WorkerProgram = preload("res://assets/vfx/extensions/cloud-body-speed-20261021/sources/f2d79bcf15671aa794e8/program.gd")
@export var prepared_code: Resource


func prepare_immutable_interface_step() -> Dictionary:
	if program == null:
		program = WorkerProgram.new()
		program.prepared_code = prepared_code
		program.prepare()
	else:
		program.advance_preparation()
	return super.prepare_immutable_interface_step()


func drain_current_preparation() -> Dictionary:
	if program != null:
		return program.drain_current()
	return {"complete": true, "operation": "no_current_native_unit"}
