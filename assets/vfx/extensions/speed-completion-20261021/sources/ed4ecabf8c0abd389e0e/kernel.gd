extends "res://assets/vfx/extensions/speed-completion-20261021/sources/70ba4efc12bbd762aa87/kernel.gd"
## Same actual post-draw readiness and active-owner close refusal. The optional
## native artifact replaces only the original monolithic compiler invocation.
const PreparedProgram = preload("res://assets/vfx/extensions/speed-completion-20261021/sources/4fe42bfa77a875f8e76c/program.gd")
@export var prepared_code: Resource


func prepare_immutable_interface_step() -> Dictionary:
	if program == null:
		program = PreparedProgram.new()
		program.prepared_code = prepared_code
		program.prepare()
	else:
		program.advance_preparation()
	return super.prepare_immutable_interface_step()
