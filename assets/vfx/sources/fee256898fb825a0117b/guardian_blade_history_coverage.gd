extends "res://assets/vfx/sources/59b6ecbb7282e6fe3062/guardian_blade_source_energy.gd"
## Actual sampled history, never interpolated source poses; local ribbon UVs.
const Coverage = preload("res://assets/vfx/sources/2a04d4b8c4ad83595a8f/guardian_blade_coverage.gd")
var history_profile: Dictionary
var fine_history: Dictionary = {}
var history_observation: Dictionary = {}
var last_requested_age: float = -1.0
var history_epoch: int = 0
var omitted_history_gaps: int = 0


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = construct("res://assets/vfx/sources/fee256898fb825a0117b/guardian_blade_history_coverage.gd", input)
	instance.name = "effect"
	return instance


func build() -> void:
	super.build()
	assert(response_data.has("history_coverage") and response_data.history_coverage is Dictionary)
	history_profile = response_data.history_coverage.duplicate(true)
	assert(float(history_profile.sample_hz) == float(parameters.simulation_hz))
	assert(float(history_profile.source_fps) == 32.0 and int(history_profile.window_source_frames) == 4)
	assert(history_profile.missing_tick_policy == "omit_unobserved_pairs")
	assert(history_profile.rewind_policy == "clear_history_require_source_replay")
	Coverage.apply(source_energy_material, history_profile.coverage)


func sample(seconds: float) -> void:
	_observe_requested_age(seconds)
	super.sample(seconds)


func _observe_requested_age(seconds: float) -> void:
	if last_requested_age >= 0.0 and seconds < last_requested_age - 0.0000001:
		# The inherited source is forward sampled. Do not retain future trail data
		# on an unsupported in-place rewind; a fresh source/replay restores its rig.
		fine_history.clear()
		history_epoch += 1
	last_requested_age = seconds


func add_quad(surface: SurfaceTool, points: Array, colour: Color) -> void:
	var uvs: Array[Vector2] = [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
	for index in [0, 1, 2, 0, 2, 3]:
		surface.set_uv(uvs[index])
		surface.set_color(colour)
		surface.add_vertex(to_local(points[index]))


func _refresh_response() -> void:
	# A deferred refresh may run after its live provider was cleared. Never
	# expose the preceding response or its history as a current observation.
	history_observation = {"clock_consistent": false, "required_input": "current source and recipient endpoints"}
	response_observation = {"visible": false}
	if is_instance_valid(response_mesh):
		response_mesh.visible = false
	if not is_instance_valid(response_mesh) or live_endpoints.size() < 2:
		fine_history.clear()
		return
	var source_frame: int = maxi(0, floori(float(tick - 1) * 32.0 / float(parameters.simulation_hz)))
	var strike_frame: int = source_frame - 64
	var blade: Dictionary = actual_blade()
	response_mesh.visible = false
	response_observation = {"visible": false, "strike_frame": strike_frame, "native_tick": tick,
		"actual_tip": [blade.tip.x, blade.tip.y, blade.tip.z], "actual_grip": [blade.grip.x, blade.grip.y, blade.grip.z],
		"historical_blend": "screen", "native_blend": "add", "physical_collision_claimed": false}
	var expected_tick := int(round(response_age * float(parameters.simulation_hz)))
	history_observation = {"sample_hz": history_profile.sample_hz, "source_fps": 32,
		"source_frame": source_frame, "strike_frame": strike_frame, "history_epoch": history_epoch,
		"clock_consistent": expected_tick == tick, "synthetic_pose_interpolation": false,
		"cross_width_feather": history_profile.coverage.fraction, "omitted_history_gaps": omitted_history_gaps}
	if expected_tick != tick:
		fine_history.clear()
		history_observation["fresh_source_replay_required"] = true
		return
	var window_ticks := int(round(float(history_profile.window_source_frames) / float(history_profile.source_fps) * float(history_profile.sample_hz)))
	if not fine_history.has(tick) and not fine_history.is_empty():
		var previous_keys: Array = fine_history.keys()
		previous_keys.sort()
		if tick - int(previous_keys.back()) > 1:
			omitted_history_gaps += 1
	fine_history[tick] = {"grip": blade.grip, "tip": blade.tip, "source_frame": source_frame}
	for key in fine_history.keys():
		if int(key) < tick - window_ticks or int(key) > tick:
			fine_history.erase(key)
	var keys: Array = fine_history.keys()
	keys.sort()
	history_observation.merge({"window_ticks": window_ticks, "observations": keys.size(),
		"oldest_tick": keys.front(), "newest_tick": keys.back(), "omitted_history_gaps": omitted_history_gaps}, true)
	if strike_frame < int(response_data.first_trail_frame) or strike_frame > int(response_data.last_trail_frame) or visor_opacity <= 0.0:
		return
	var camera := get_viewport().get_camera_3d()
	assert(camera != null)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var taper: float = 1.0 - smoothstep(float(response_data.taper_begin_frame), float(response_data.taper_end_frame), float(strike_frame))
	var trail_quads: int = 0
	var held_pairs: int = 0
	for index in range(1, keys.size()):
		var old_tick: int = keys[index - 1]
		var new_tick: int = keys[index]
		if new_tick != old_tick + 1:
			continue
		var current: Dictionary = fine_history[new_tick]
		var previous: Dictionary = fine_history[old_tick]
		if current.tip.distance_to(previous.tip) <= 0.000001 and current.grip.distance_to(previous.grip) <= 0.000001:
			held_pairs += 1
			continue
		var inner: Vector3 = current.grip.lerp(current.tip, 0.8)
		var old_inner: Vector3 = previous.grip.lerp(previous.tip, 0.8)
		# Preserve the accepted source-frame weights, separately from actual
		# 144-Hz observations. Higher sample count does not invent new poses.
		var back: int = source_frame - int(current.source_frame)
		var strength: float = clampf(1.0 - float(back) / 4.0, 0.0, 1.0)
		add_quad(surface, [inner, current.tip, previous.tip, old_inner], source_colour(0, strength * 0.16 * taper))
		add_line(surface, previous.tip, current.tip, float(response_data.stroke_width_cells), source_colour(1, strength * 0.6 * taper), camera)
		trail_quads += 1
	var contact_age: float = response_age - float(response_data.contact_source_tick) / float(parameters.simulation_hz)
	var continuation_alpha: float = smoothstep(-0.07, 0.0, contact_age) * (1.0 - smoothstep(0.04, 0.20, contact_age))
	var target: Vector3 = live_endpoints[1].point
	var segments: int = 0
	if continuation_alpha > 0.0:
		var control: Vector3 = blade.tip.lerp(target, 0.5) + Vector3.UP * float(response_data.continuation_bend_cells)
		var previous: Vector3 = blade.tip
		for index in range(1, 17):
			var progress: float = float(index) / 16.0
			var point: Vector3 = blade.tip.lerp(control, progress).lerp(control.lerp(target, progress), progress)
			add_line(surface, previous, point, float(response_data.continuation_width_cells), source_colour(2, continuation_alpha * 0.85), camera)
			previous = point
			segments += 1
	history_observation.merge({"nondegenerate_trail_links": trail_quads, "held_pose_pairs_omitted": held_pairs}, true)
	if trail_quads == 0 and segments == 0:
		return
	response_mesh.mesh = surface.commit()
	response_mesh.visible = true
	response_observation.merge({"visible": true, "trail_quads": trail_quads, "continuation_segments": segments,
		"continuation_alpha": continuation_alpha * visor_opacity, "target_endpoint": [target.x, target.y, target.z],
		"contact_source_tick": int(response_data.contact_source_tick), "actual_tip_to_endpoint_distance_cells": blade.tip.distance_to(target),
		"source_occurrence_alpha": visor_opacity}, true)


func capture_observation() -> Dictionary:
	var observation: Dictionary = super.capture_observation()
	observation.blade_source_energy.edge_feather_added = true
	observation.blade_source_energy["cross_width_feather"] = source_energy_material.get_shader_parameter("guardian_blade_cross_feather")
	observation["blade_history"] = history_observation.duplicate(true)
	return observation
