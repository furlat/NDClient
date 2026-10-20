extends "res://assets/vfx/extensions/heavy-effects-20261020/sources/fee256898fb825a0117b/guardian_blade_history_coverage.gd"
## Intentional native RESPONSE interpolation; original measured poses untouched.
const TailCoverage = preload("res://assets/vfx/sources/81195a632dc374162f09/guardian_blade_tail_coverage.gd")
var arc_profile: Dictionary
var arc_observation: Dictionary = {}


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = construct("res://assets/vfx/extensions/heavy-effects-20261020/sources/8c0f7de15cd6d11e943d/guardian_blade_arc_trail.gd", input)
	instance.name = "effect"
	return instance


func build() -> void:
	super.build()
	assert(response_data.has("arc_trail") and response_data.arc_trail is Dictionary)
	arc_profile = response_data.arc_trail.duplicate(true)
	assert(arc_profile.profile == "observed_endpoints_shortest_direction_arc")
	assert(float(arc_profile.max_segment_degrees) > 0.0 and float(arc_profile.max_segment_degrees) <= 5.0)
	TailCoverage.apply(source_energy_material, arc_profile.tail)


static func direction_angle(first: Dictionary, last: Dictionary) -> float:
	var a: Vector3 = (first.tip - first.grip).normalized()
	var b: Vector3 = (last.tip - last.grip).normalized()
	return acos(clampf(a.dot(b), -1.0, 1.0))


static func arc_sample(first: Dictionary, last: Dictionary, progress: float) -> Dictionary:
	if progress <= 0.0:
		return {"grip": first.grip, "tip": first.tip}
	if progress >= 1.0:
		return {"grip": last.grip, "tip": last.tip}
	var first_vector: Vector3 = first.tip - first.grip
	var last_vector: Vector3 = last.tip - last.grip
	assert(first_vector.length() > 0.000001 and last_vector.length() > 0.000001)
	var first_direction: Vector3 = first_vector.normalized()
	var rotation := Quaternion(first_direction, last_vector.normalized())
	var direction: Vector3 = Quaternion.IDENTITY.slerp(rotation, progress) * first_direction
	var length: float = lerpf(first_vector.length(), last_vector.length(), progress)
	var grip: Vector3 = first.grip.lerp(last.grip, progress)
	return {"grip": grip, "tip": grip + direction.normalized() * length}


func emit_quad(surface: SurfaceTool, points: Array, colour: Color, first_age: float, last_age: float) -> void:
	var uvs: Array[Vector2] = [Vector2(0, first_age), Vector2(1, first_age), Vector2(1, last_age), Vector2(0, last_age)]
	for index in [0, 1, 2, 0, 2, 3]:
		surface.set_uv(uvs[index])
		surface.set_color(colour)
		surface.add_vertex(to_local(points[index]))


func emit_line(surface: SurfaceTool, first: Vector3, last: Vector3, width: float, colour: Color, camera: Camera3D, first_age: float, last_age: float) -> void:
	var direction: Vector3 = last - first
	if direction.length_squared() < 0.0000000001:
		return
	var across: Vector3 = direction.cross(camera.global_basis.z).normalized()
	if across.is_zero_approx():
		across = camera.global_basis.x
	across *= width * 0.5
	emit_quad(surface, [first - across, first + across, last + across, last - across], colour, first_age, last_age)


func begin_response_surface() -> SurfaceTool:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	return surface


func commit_response_surface(surface: SurfaceTool) -> ArrayMesh:
	return surface.commit()


func response_interval(first: Dictionary, last: Dictionary, _old_tick: int, _new_tick: int) -> Dictionary:
	# Pure solution of an actual already-observed endpoint pair. Colour, UV,
	# current camera width and current root conversion remain in publication.
	var angle: float = direction_angle(first, last)
	var count: int = maxi(1, ceili(angle / deg_to_rad(float(arc_profile.max_segment_degrees))))
	var old_pose: Dictionary = arc_sample(first, last, 0.0)
	var endpoint_exact: bool = old_pose.grip == first.grip and old_pose.tip == first.tip
	var parts: Array = []
	for part in range(1, count + 1):
		var old_progress: float = float(part - 1) / float(count)
		var progress: float = float(part) / float(count)
		var pose: Dictionary = arc_sample(first, last, progress)
		var step: float = direction_angle(old_pose, pose)
		var expected_length: float = lerpf(first.grip.distance_to(first.tip), last.grip.distance_to(last.tip), progress)
		var length_error: float = absf(pose.grip.distance_to(pose.tip) - expected_length)
		parts.append({"old_pose": old_pose, "pose": pose, "old_progress": old_progress,
			"progress": progress, "step": step, "length_error": length_error})
		old_pose = pose
	endpoint_exact = endpoint_exact and old_pose.grip == last.grip and old_pose.tip == last.tip
	return {"angle": angle, "count": count, "parts": parts, "endpoint_exact": endpoint_exact,
		"from_length": first.grip.distance_to(first.tip), "to_length": last.grip.distance_to(last.tip)}


func _refresh_response() -> void:
	# Parent owns observation/rewind/gap/window policy. Its temporary four-link
	# mesh is replaced in this same callback before a render; no extra draw node.
	super._refresh_response()
	arc_observation = {"visible": false, "source_pose_changed": false,
		"synthetic_response_geometry": true, "measured_144Hz_motion_claimed": false}
	if not is_instance_valid(response_mesh) or not response_mesh.visible:
		return
	assert(history_observation.get("clock_consistent", false) and history_observation.has("source_frame") and history_observation.has("strike_frame"), "Visible blade response requires an admitted current history observation")
	var source_frame: int = history_observation.source_frame
	var strike_frame: int = history_observation.strike_frame
	var keys: Array = fine_history.keys()
	keys.sort()
	var first_source_frame: int = source_frame - int(history_profile.window_source_frames)
	var source_frame_window: float = float(history_profile.window_source_frames)
	var camera := get_viewport().get_camera_3d()
	assert(camera != null)
	var surface: SurfaceTool = begin_response_surface()
	var taper: float = 1.0 - smoothstep(float(response_data.taper_begin_frame), float(response_data.taper_end_frame), float(strike_frame))
	var total_segments: int = 0
	var source_links: int = 0
	var max_step: float = 0.0
	var max_length_error: float = 0.0
	var intervals: Array = []
	for index in range(1, keys.size()):
		var old_tick: int = keys[index - 1]
		var new_tick: int = keys[index]
		if new_tick != old_tick + 1:
			continue
		var current: Dictionary = fine_history[new_tick]
		var previous: Dictionary = fine_history[old_tick]
		if current.tip.distance_to(previous.tip) <= 0.000001 and current.grip.distance_to(previous.grip) <= 0.000001:
			continue
		var interval: Dictionary = response_interval(previous, current, old_tick, new_tick)
		var angle: float = interval.angle
		var count: int = interval.count
		var strength: float = clampf(1.0 - float(source_frame - int(current.source_frame)) / 4.0, 0.0, 1.0)
		var fill_colour: Color = source_colour(0, strength * 0.16 * taper)
		var stroke_colour: Color = source_colour(1, strength * 0.6 * taper)
		for part: Dictionary in interval.parts:
			var old_progress: float = part.old_progress
			var progress: float = part.progress
			var old_pose: Dictionary = part.old_pose
			var pose: Dictionary = part.pose
			max_step = maxf(max_step, part.step)
			max_length_error = maxf(max_length_error, part.length_error)
			# Longitudinal UV follows the original four SOURCE-frame window.
			# Repeated held native samples cannot leave a nonzero oldest cap.
			var old_age: float = clampf((lerpf(float(previous.source_frame), float(current.source_frame), old_progress) - float(first_source_frame)) / source_frame_window, 0.0, 1.0)
			var age: float = clampf((lerpf(float(previous.source_frame), float(current.source_frame), progress) - float(first_source_frame)) / source_frame_window, 0.0, 1.0)
			emit_quad(surface, [pose.grip.lerp(pose.tip, 0.8), pose.tip, old_pose.tip, old_pose.grip.lerp(old_pose.tip, 0.8)], fill_colour, age, old_age)
			emit_line(surface, old_pose.tip, pose.tip, float(response_data.stroke_width_cells), stroke_colour, camera, old_age, age)
			total_segments += 1
		intervals.append({"from_tick": old_tick, "to_tick": new_tick, "segments": count,
			"angle_degrees": rad_to_deg(angle), "observed_endpoints_exact": interval.endpoint_exact,
			"from_length": interval.from_length, "to_length": interval.to_length})
		source_links += 1
	# Same actual current tip/target/finite envelope as V196. UV.y=1 exempts the
	# continuation from the oldest-history tail fade; cross-width softness stays.
	var blade: Dictionary = actual_blade()
	var target: Vector3 = live_endpoints[1].point
	var segments: int = 0
	var continuation_alpha: float = response_observation.get("continuation_alpha", 0.0)
	if continuation_alpha > 0.0:
		var contact_age: float = response_age - float(response_data.contact_source_tick) / float(parameters.simulation_hz)
		var pulse: float = smoothstep(-0.07, 0.0, contact_age) * (1.0 - smoothstep(0.04, 0.20, contact_age))
		var control: Vector3 = blade.tip.lerp(target, 0.5) + Vector3.UP * float(response_data.continuation_bend_cells)
		var previous: Vector3 = blade.tip
		var continuation_colour: Color = source_colour(2, pulse * 0.85)
		for index in range(1, 17):
			var progress: float = float(index) / 16.0
			var point: Vector3 = blade.tip.lerp(control, progress).lerp(control.lerp(target, progress), progress)
			emit_line(surface, previous, point, float(response_data.continuation_width_cells), continuation_colour, camera, 1.0, 1.0)
			previous = point
			segments += 1
	response_mesh.visible = total_segments > 0 or segments > 0
	if response_mesh.visible:
		response_mesh.mesh = commit_response_surface(surface)
	response_observation.trail_quads = total_segments
	arc_observation.merge({"visible": response_mesh.visible, "source_links": source_links,
		"arc_segments": total_segments, "max_step_degrees": rad_to_deg(max_step),
		"max_linear_measured_length_error_cells": max_length_error,
		"observed_endpoints_all_exact": intervals.all(func(value: Dictionary) -> bool: return value.observed_endpoints_exact),
		"intervals": intervals, "continuation_segments": segments, "continuation_uses_exact_current_tip": true,
		"tail_fraction": arc_profile.tail.fraction, "continuation_tail_coverage": 1.0}, true)


func capture_observation() -> Dictionary:
	var observation: Dictionary = super.capture_observation()
	observation["blade_arc"] = arc_observation.duplicate(true)
	return observation
