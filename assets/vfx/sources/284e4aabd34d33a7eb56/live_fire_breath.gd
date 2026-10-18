extends "res://assets/vfx/sources/e92e35dad9736cc32c30/native_fire_breath.gd"
## Preserve the flame donor; the supplied mouth and ground points own placement.
var endpoints: Array = []


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/284e4aabd34d33a7eb56/live_fire_breath.gd", input)


func set_live_endpoints(value: Array) -> void:
	endpoints = value


func update_geometry() -> void:
	if endpoints.size() < 3:
		return
	var inverse := global_transform.affine_inverse()
	var heading: Vector3 = inverse * endpoints[2].point - inverse * endpoints[0].point
	heading.y = 0.0
	if heading.is_zero_approx():
		return
	heading = heading.normalized()
	var mouth: Vector3 = inverse * endpoints[1].point
	subject.position = mouth
	subject.basis = Basis.looking_at(heading, Vector3.UP)
	subject.scale = Vector3(1.0, 0.866025403784, 1.0)
	for material in breath_materials:
		material.set_shader_parameter("breath_origin", mouth)
		material.set_shader_parameter("breath_direction", Vector2(heading.x, heading.z))


func capture_observation() -> Dictionary:
	if endpoints.size() < 3:
		return {"live_endpoint_count": endpoints.size()}
	var intended: Vector3 = endpoints[2].point - endpoints[0].point
	intended.y = 0.0
	return {
		"live_endpoint_count": endpoints.size(),
		"source_error_cells": subject.global_position.distance_to(endpoints[1].point),
		"heading_dot": (-subject.global_basis.z).normalized().dot(intended.normalized()),
		"range_cells": float(settings.range_units),
		"target_distance_cells": intended.length(),
		"target_in_range": intended.length() <= float(settings.range_units),
		"source_socket": "face",
	}
