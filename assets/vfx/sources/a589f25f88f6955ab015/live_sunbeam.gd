extends "res://assets/vfx/sources/3eeeebacf2494b475d88/sunbeam.gd"
## Source axial geometry is +Y; bind it once to the actual horizontal cast.
var endpoints: Array = []
var beam_root: Node3D


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/a589f25f88f6955ab015/live_sunbeam.gd", input)


func set_live_endpoints(value: Array) -> void:
	endpoints = value


func capture_observation() -> Dictionary:
	if endpoints.size() < 3 or not is_instance_valid(beam_root):
		return {"live_endpoint_count": endpoints.size()}
	var intended: Vector3 = endpoints[2].point - endpoints[0].point
	intended.y = 0.0
	return {
		"live_endpoint_count": endpoints.size(),
		"source_error_cells": beam_root.global_position.distance_to(endpoints[1].point),
		"heading_dot": beam_root.global_basis.y.normalized().dot(intended.normalized()),
		"source_world": [beam_root.global_position.x,beam_root.global_position.y,beam_root.global_position.z],
		"range_cells": 12.0,
	}


func apply_scene_edits(node: Node) -> void:
	super.apply_scene_edits(node)
	beam_root = node.get_child(0)
	for emitter in beam_root.find_children("*", "GPUParticles3D", true, false):
		emitter.local_coords = true
	bind_beam()


func bind_beam() -> void:
	if endpoints.size() < 3 or not is_instance_valid(beam_root):
		return
	var inverse: Transform3D = global_transform.affine_inverse()
	var source_ground: Vector3 = inverse * endpoints[0].point
	var target_ground: Vector3 = inverse * endpoints[2].point
	var heading: Vector3 = target_ground - source_ground
	heading.y = 0.0
	if heading.is_zero_approx():
		return
	axis = heading.normalized()
	beam_origin = inverse * endpoints[1].point
	# The donor's native +Y travels forward; its X/Z axes form the cross-section.
	beam_root.basis = Basis(Vector3.UP, axis, Vector3.UP.cross(axis))
	beam_root.scale = Vector3(0.14, 0.24, 0.14)
	beam_root.position = subject.global_transform.affine_inverse() * endpoints[1].point
	for material in mats:
		material.set_shader_parameter("beam_axis", axis)
		material.set_shader_parameter("beam_origin", beam_origin)


func advance_lifecycle(delta: float) -> void:
	super.advance_lifecycle(delta)


func update_geometry() -> void:
	bind_beam()
