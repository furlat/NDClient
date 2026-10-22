extends Resource
## Shared immutable pipeline. No actor packet, clock, node or owner prototype.
const Program = preload("res://assets/vfx/extensions/cloud-body-speed-20261021/sources/4eab3ac08359abaa2e9a/program.gd")
var program: RefCounted
var first_ready_frame := -1
var interface_ready := false


func prepare_immutable_interface_step() -> Dictionary:
	if program == null:
		program = Program.new()
		program.prepare()
	var state: Dictionary = program.status()
	var error: String = state.error
	if state.get("closed", false) and error.is_empty(): error = "Flow compute program is closed"
	if not error.is_empty():
		interface_ready = false
		return {"complete": false, "error": error, "pipeline": state}
	if state.ready and first_ready_frame < 0:
		first_ready_frame = Engine.get_frames_drawn()
	interface_ready = state.ready and program.available() and first_ready_frame >= 0 and Engine.get_frames_drawn() > first_ready_frame
	return {"complete": interface_ready, "error": "", "pipeline": state, "first_ready_rendered_frame": first_ready_frame,
		"current_rendered_frame": Engine.get_frames_drawn(),
		"scope": "Immutable native pipeline plus actual rendered-frame admission; no actor or source sample"}


func available() -> bool:
	return interface_ready and program != null and program.available()


func close() -> bool:
	if program != null:
		if not program.close(): return false
		program = null
	interface_ready = false
	first_ready_frame = -1
	return true
