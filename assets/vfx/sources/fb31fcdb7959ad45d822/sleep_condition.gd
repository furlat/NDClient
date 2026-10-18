extends "res://assets/vfx/sources/d092a75e3b0074bcf468/control_status.gd"
## Existing Zzz source, anchored to the supplied live face socket.
## Source presentation loops while its externally owned condition is admitted.

var socket_point: Vector3
var has_socket: bool = false


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/fb31fcdb7959ad45d822/sleep_condition.gd", input)


func set_live_endpoints(endpoints: Array) -> void:
	if endpoints.is_empty():
		return
	socket_point = endpoints[0].point
	has_socket = true
	update_geometry()


func apply_scene_edits(node: Node) -> void:
	super.apply_scene_edits(node)
	for emitter in node.find_children("*", "GPUParticles3D", true, false):
		if emitter.name == "Aura":
			continue
		# A face-attached condition must carry its particles with the resting face.
		emitter.local_coords = true
		emitter.one_shot = false
		emitter.emitting = true


func advance_lifecycle(_delta: float) -> void:
	tick += 1
	var age: float = float(tick) / float(parameters.simulation_hz)
	for material in materials:
		material.set_shader_parameter("support_clock", age)
		material.set_shader_parameter("support_envelope", 1.0)


func update_geometry() -> void:
	if not has_socket or subject == null:
		return
	var lifted: Vector3 = socket_point + Vector3.UP * float(parameters.socket_lift_units)
	subject.position = to_local(lifted) - Vector3(0.0, 1.7, 0.0)
