extends Node3D
## Four exact optical poses drive one prebuilt GPU ribbon. No CPU mesh rebuild,
## smoothed emitter, inferred whole sword, idle trail or gameplay event is made.
const CAPACITY := 4
var style: Resource
var material: ShaderMaterial
var draw: MeshInstance3D
var binding: Dictionary = {}
var pose: Dictionary = {}
var samples: Array = []
var source_key: Array = []
var pose_context: Array = []
var last_frame := -1
var last_seconds := -INF
var material_seconds := -INF
var visibility := false
var retired := false
var rejection := "weapon_binding_missing"
var reset_reason := "new_source"
var uploads := 0
var bounds_dirty := false
var root_ready := false


static func preparation_resources(input: Dictionary) -> Array:
	return [str(input.style)]


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = VfxPackageIO_3a6c7e2790.resource("res://assets/vfx/sources/3a6c7e27908861f4c602/component.gd").new()
	instance.style = VfxPackageIO_3a6c7e2790.resource(str(input.style))
	assert(instance.style != null, "Prepared swing style must be supplied")
	return instance


func _ready() -> void:
	material = style.material.duplicate(false)
	draw = MeshInstance3D.new()
	draw.name = "ExactOuterBladeWake"
	draw.mesh = style.mesh
	draw.material_override = material
	draw.layers = 1 << 19
	draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	draw.custom_aabb = AABB(Vector3.ONE * -.5, Vector3.ONE)
	draw.hide()
	add_child(draw)


func set_weapon_binding(value: Dictionary) -> void:
	binding = value


func set_sheet_pose(value: Dictionary) -> void:
	pose = value


func set_root_path(value: Transform3D) -> void:
	if value.origin.is_finite() and value.basis.x.is_finite() and value.basis.y.is_finite() and value.basis.z.is_finite():
		if root_ready and value.origin.distance_squared_to(global_position) > .25:
			_reset("discontinuous_root_translation")
		root_ready = true
		if not global_transform.is_equal_approx(value):
			global_transform = value
			bounds_dirty = true
	else:
		root_ready = false
		_reset("root_path_non_finite")
		_set_visible(false)


func _binding_key() -> Array:
	if retired or not root_ready or not binding.get("present", false) or not binding.get("observed", false) \
		or not binding.get("equipped", false) or binding.get("suppressed", true):
		return []
	for field in ["item_uuid", "holder_uuid", "owner_uuid"]:
		if not binding.get(field) is String or str(binding[field]).is_empty():
			return []
	if binding.get("equipment_slot") not in ["MELEE_MAIN", "MELEE_OFF"]:
		return []
	return [binding.get("owner_kind", ""), binding.owner_uuid, binding.item_uuid,
		binding.holder_uuid, binding.equipment_slot, binding.get("render_slot", "")]


func _valid_pose() -> bool:
	if pose.get("item_uuid") != binding.get("item_uuid") or pose.get("holder_uuid") != binding.get("holder_uuid") \
		or not pose.get("visible_frame", false):
		return false
	var frame: Variant = pose.get("frame_key")
	if not frame is Array or frame.size() != 4 or str(frame[1]) not in ["Attack1", "Attack2"]:
		return false
	if str(frame[0]).is_empty() or not (frame[3] is int or frame[3] is float) \
		or not is_finite(float(frame[3])) or int(frame[3]) < 0:
		return false
	if pose.get("axis_status") not in ["explicit_source_anchor", "authored_orientation_visible_anchors"]:
		return false
	for field in ["near", "far", "normal"]:
		if not pose.get(field) is Vector3 or not pose[field].is_finite():
			return false
	return pose.near.distance_squared_to(pose.far) >= .000225 and pose.normal.length_squared() >= .5


func _reset(reason: String) -> void:
	samples.clear()
	pose_context.clear()
	last_frame = -1
	reset_reason = reason
	if material != null:
		material.set_shader_parameter("wake_count", 0)


func _set_visible(value: bool) -> void:
	if visibility != value:
		visibility = value
		draw.visible = value


func sample(seconds: float) -> void:
	var key := _binding_key()
	if key.is_empty() or not is_finite(seconds):
		_reset("binding_unavailable" if is_finite(seconds) else "clock_non_finite")
		rejection = reset_reason
		_set_visible(false)
		return
	if not _valid_pose():
		_reset("exact_attack_pose_unavailable")
		rejection = reset_reason
		_set_visible(false)
		return
	if key != source_key:
		_reset("actual_owner_or_item_changed")
		source_key = key.duplicate(true)
	if seconds < last_seconds:
		_reset("source_clock_rewind")
	elif is_finite(last_seconds) and seconds-last_seconds > .20:
		_reset("source_clock_gap")
	var frame: Array = pose.frame_key
	var context: Array = [frame[0], frame[1], frame[2], pose.get("camera_key", pose.normal)]
	if context != pose_context:
		_reset("clip_facing_or_camera_changed")
		pose_context = context.duplicate(true)
	var current_frame := int(frame[3])
	if current_frame < last_frame:
		_reset("source_frame_rewind")
		pose_context = context.duplicate(true)
	var changed := false
	var tip: Vector3 = pose.far
	var inner: Vector3 = pose.near.lerp(tip, 1.0 - style.outer_blade_fraction)
	var different_pose: bool = samples.is_empty() or current_frame != last_frame
	if different_pose:
		if seconds == last_seconds and not samples.is_empty():
			_reset("changed_pose_without_source_advance")
			pose_context = context.duplicate(true)
		if not samples.is_empty():
			# The last real sample of the held pose precedes this transition.
			# Preserve both its original measurement and actual last observation;
			# neither its geometry nor a fake intermediate pose is manufactured.
			samples[0].retired_seconds = samples[0].observed_seconds
		samples.push_front({"inner": inner, "tip": tip, "seconds": seconds,
			"observed_seconds": seconds, "retired_seconds": seconds, "frame": frame.duplicate(true)})
		if samples.size() > CAPACITY:
			samples.pop_back()
		changed = true
	elif not samples.is_empty() and (samples[0].inner != inner or samples[0].tip != tip):
		# Retain the exact newest optical position under actual holder movement.
		# It does not manufacture another pose/time sample inside a held frame.
		samples[0].inner = inner
		samples[0].tip = tip
		changed = true
	while samples.size()>1 and seconds-float(samples[-1].retired_seconds)>style.history_seconds:
		samples.pop_back()
		changed = true
	last_frame = current_frame
	last_seconds = seconds
	samples[0].observed_seconds = seconds
	if changed:
		_upload()
	elif bounds_dirty:
		_bounds()
	if material_seconds != seconds:
		material.set_shader_parameter("wake_seconds", seconds)
		material_seconds = seconds
	var has_motion := false
	for index in range(1, samples.size()):
		if samples[index - 1].tip.distance_squared_to(samples[index].tip) > .000004 \
			or samples[index - 1].inner.distance_squared_to(samples[index].inner) > .000004:
			has_motion = true
	_set_visible(has_motion and samples.size() >= 2)
	rejection = "" if visibility else "insufficient_recent_exact_motion"


func _upload() -> void:
	var inner := PackedVector4Array()
	var tip := PackedVector4Array()
	for index in CAPACITY:
		var point: Dictionary = samples[mini(index, samples.size() - 1)]
		inner.append(Vector4(point.inner.x, point.inner.y, point.inner.z, point.retired_seconds))
		tip.append(Vector4(point.tip.x, point.tip.y, point.tip.z, point.retired_seconds))
	material.set_shader_parameter("wake_inner", inner)
	material.set_shader_parameter("wake_tip", tip)
	material.set_shader_parameter("wake_count", samples.size())
	uploads += 1
	_bounds()


func _bounds() -> void:
	if samples.is_empty():
		return
	var inverse := global_transform.affine_inverse()
	var low: Vector3 = inverse * samples[0].tip
	var high := low
	for point in samples:
		for endpoint: Vector3 in [point.inner, point.tip]:
			var local := inverse * endpoint
			low = low.min(local)
			high = high.max(local)
	draw.custom_aabb = AABB(low, high - low).grow(.025)
	bounds_dirty = false


func clear() -> void:
	retired = true
	binding = {}
	pose = {}
	_reset("retired")
	_set_visible(false)


func source_bindings() -> Dictionary:
	return {"geometry": [draw], "materials": [material], "lights": [], "static_material_topology": true}


func capture_observation() -> Dictionary:
	return {"variant_id": style.variant_id, "strength": style.strength, "visible": visibility,
		"rejection": rejection, "reset_reason": reset_reason, "history": samples.duplicate(true),
		"history_capacity": CAPACITY, "history_seconds": style.history_seconds,
		"outer_blade_fraction": style.outer_blade_fraction, "maximum_reach_cells": style.maximum_reach_cells,
		"actual_owner": source_key.duplicate(true), "uploads": uploads, "clock": last_seconds,
		"per_frame_mesh_building": false, "emitter_smoothing": false, "pca_or_axis_averaging": false,
		"idle_trails": false, "new_gameplay_or_damage": false, "lights": 0, "art_status": style.art_status}

const VfxPackageIO_3a6c7e2790 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
