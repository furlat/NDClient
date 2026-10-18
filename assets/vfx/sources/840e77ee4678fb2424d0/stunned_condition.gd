extends "res://assets/vfx/sources/02e8eda447821da38634/necrotic.gd"
## Existing three-star artwork, registered to a supplied live head socket.
## The condition owner supplies its lifetime; this component owns no rules.

var socket_point: Vector3
var has_socket: bool = false


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/840e77ee4678fb2424d0/stunned_condition.gd", input)


func set_live_endpoints(endpoints: Array) -> void:
	if endpoints.is_empty():
		return
	socket_point = endpoints[0].point
	has_socket = true
	update_geometry()


func update_geometry() -> void:
	if not has_socket or assembly == null:
		return
	var lifted: Vector3 = socket_point + Vector3.UP * float(parameters.socket_lift_units)
	var source_anchor := Vector3(0.0, 1.55 * sqrt(2.0 / 3.0), 0.0)
	assembly.position = to_local(lifted) - source_anchor
