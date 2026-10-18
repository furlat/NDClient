extends "res://assets/vfx/sources/bbc87295a58ed81df700/telekinetic_pinch.gd"
## Private fit of the original animated grip to disclosed visible head support.
## Actor movement, elevation, presence and ownership remain supplied facts.
const GripSurface = preload("res://assets/vfx/sources/aae9abe6af45f05f94c2/telekinetic_grip_surface_v177.gd")
var grip_surface := GripSurface.new()
var reference: Dictionary = {}
var endpoints: Array = []
var suppressed: bool = false
var source_seconds: float = 0.0
var phase_name: String = "grab"
var contact_observation: Dictionary = {}
var admitted_scale: float = NAN

static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/fe7cf3f5da5d199ca45a/telekinetic_contact_v177.gd", input)

func apply_scene_edits(node: Node) -> void:
	super.apply_scene_edits(node)
	# The selected timed assembly joined both historical camera halves. This
	# direct full-hand component expresses that same source choice explicitly.
	for material in mats:
		material.set_shader_parameter("side", 0.0)
	# The disclosed world surface owns placement. Parent carrier changes must not
	# add the actor's movement twice, including a paused source-clock sample.
	subject.top_level = true
	subject.global_transform = Transform3D.IDENTITY
	grip_surface.prepare(subject)
	_seek_original("hold", 0.5)
	reference = grip_surface.closest_pair()
	_seek_original("grab", 0.0)
	subject.hide()

func set_live_endpoints(value: Array) -> void:
	endpoints = value
	if prepared:
		_fit()

func set_suppressed(value: bool) -> void:
	suppressed = value
	if prepared:
		_fit()

func _seek_original(clip: String, seconds: float) -> void:
	var animation := ""
	for name in ap.get_animation_list():
		if name.ends_with(clip):
			animation = name
	assert(not animation.is_empty(), "Original grip animation is missing: " + clip)
	var frame: int = maxi(0, int(floor(seconds * 32.0)))
	ap.play(animation)
	ap.pause()
	ap.seek(minf(float(frame) / 32.0, 0.96875), true)
	for material in mats:
		material.set_shader_parameter("clock", float(frame) / 64.0)

func sample(seconds: float) -> void:
	if not prepared:
		prepare_subject()
	initialized = true
	source_seconds = seconds
	var close_seconds: float = parameters.get("grip_close_seconds", 1.0)
	phase_name = "grab" if seconds < close_seconds else ("hold" if seconds < 3.0 else "release")
	var original_seconds: float = seconds / close_seconds if seconds < close_seconds else (
		seconds - close_seconds if seconds < 3.0 else seconds - 3.0)
	_seek_original(phase_name, maxf(0.0, original_seconds))
	_fit()

func _fit() -> void:
	subject.hide()
	contact_observation = {"fit_valid":false,"phase":phase_name,"source_seconds":source_seconds,
		"suppressed":suppressed,"rules_evaluated":false,"collision_certified":false,
		"anatomy_certified":false,"normal_alignment_certified":false}
	set_meta("telekinetic_contact_v177",contact_observation)
	if suppressed or source_seconds < 0.0 or source_seconds >= 4.0 or endpoints.is_empty():
		return
	var endpoint: Dictionary = endpoints[0]
	var surface: Dictionary = endpoint.get("surface", {})
	var points: Array = surface.get("points", [])
	if points.size() < 8 or reference.is_empty() or reference.distance < 0.0001:
		return
	var low := INF
	var high := -INF
	for point in points:
		low = minf(low, point.position.y)
		high = maxf(high, point.position.y)
	var height: float = high - low
	var face: Vector3 = endpoint.point
	var region := []
	for point in points:
		if point.get("slot", "") in ["head", "helmet"]:
			region.append(point)
	if region.size() < 4:
		region.clear()
		for point in points:
			var horizontal := Vector2(point.position.x - face.x, point.position.z - face.z)
			if absf(point.position.y - face.y) <= height * 0.13 and horizontal.length() <= height * 0.25:
				region.append(point)
	if region.size() < 4:
		return
	var axis: Vector3 = (reference.index - reference.thumb).normalized()
	var thumb_target: Vector3 = region[0].position
	var index_target: Vector3 = region[0].position
	var minimum := INF
	var maximum := -INF
	for point in region:
		var projection: float = (point.position - face).dot(axis)
		if projection < minimum:
			minimum = projection
			thumb_target = point.position
		if projection > maximum:
			maximum = projection
			index_target = point.position
	var target_span: Vector3 = index_target - thumb_target
	var fit_scale: float = target_span.length() / reference.distance
	if fit_scale < 0.05 or fit_scale > 8.0:
		return
	var measured_scale: float = fit_scale
	if is_nan(admitted_scale):
		admitted_scale = measured_scale
	fit_scale = admitted_scale
	var rotation := Basis(Quaternion(axis, target_span.normalized()))
	var basis: Basis = rotation.scaled(Vector3.ONE * fit_scale)
	var midpoint: Vector3 = (thumb_target + index_target) * 0.5
	var reference_midpoint: Vector3 = (reference.thumb + reference.index) * 0.5
	subject.global_transform = Transform3D(basis, midpoint - basis * reference_midpoint)
	var actual_thumb: Vector3 = subject.global_transform * grip_surface.position(reference.thumb_vertex)
	var actual_index: Vector3 = subject.global_transform * grip_surface.position(reference.index_vertex)
	var original_thumb: Vector3 = surface.origin + reference.thumb
	var original_index: Vector3 = surface.origin + reference.index
	var original_thumb_gap := INF
	var original_index_gap := INF
	for point in region:
		original_thumb_gap = minf(original_thumb_gap, original_thumb.distance_to(point.position))
		original_index_gap = minf(original_index_gap, original_index.distance_to(point.position))
	subject.show()
	contact_observation.merge({"fit_valid":true,"actor":surface.get("actor", ""),
		"support_points":points.size(),"head_region_points":region.size(),"fit_scale":fit_scale,
		"measured_head_scale":measured_scale,"scale_locked_at_admission":true,
		"thumb_target":thumb_target,"index_target":index_target,
		"actual_thumb_pad":actual_thumb,"actual_index_pad":actual_index,
		"thumb_gap_cells":actual_thumb.distance_to(thumb_target),
		"index_gap_cells":actual_index.distance_to(index_target),
		"original_thumb_nearest_support_gap_cells":original_thumb_gap,
		"original_index_nearest_support_gap_cells":original_index_gap,
		"source_thumb_vertex":reference.thumb_vertex,"source_index_vertex":reference.index_vertex},true)

func capture_observation() -> Dictionary:
	return {"telekinetic_contact_v177":contact_observation}
