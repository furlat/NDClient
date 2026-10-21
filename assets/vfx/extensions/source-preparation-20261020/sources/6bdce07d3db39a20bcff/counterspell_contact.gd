extends Node3D
## Finite original Counterspell fragments at an actual optical contact.
## The producer retains and cancels its existing incoming presentation.
const Fragments = preload("res://assets/vfx/sources/6e25e2b7f8fcbfdb10c7/counter_fragments.gd")
const OWNER_KEYS := ["reaction_uuid", "triggered_event_uuid", "triggered_lineage_uuid"]

var reaction_owner: Dictionary = {}
var reaction: Dictionary = {}
var presentation: Dictionary = {}
var path: Array[Dictionary] = []
var fragment_settings: Dictionary = {}
var interrupted_snapshot: Dictionary = {}
var fragments: Node3D
var age_seconds := -1.0
var rejection := "reaction_unbound"


static func make_component(input: Dictionary) -> Node3D:
	var style: Dictionary = input.get("fragments", {})
	if not style.has("material") or not style.has("palette") or not style.has("scale_cells_per_source_unit"):
		return null
	var result: Node3D = VfxPackageIO_6bdce07d3d.resource("res://assets/vfx/extensions/source-preparation-20261020/sources/6bdce07d3db39a20bcff/counterspell_contact.gd").new()
	result.fragment_settings = style.duplicate(true)
	result.fragment_settings.succeeded = true
	result.fragments = Fragments.make_component(result.fragment_settings)
	result.fragments.name = "OriginalFiniteCounterspellFragments"
	result.add_child(result.fragments)
	result.fragments.sample(-1.0)
	result.hide()
	return result


func _matches_owner(value: Dictionary) -> bool:
	for key: String in OWNER_KEYS:
		if str(value.get(key, "")).is_empty():
			return false
		if not reaction_owner.is_empty() and str(value[key]) != str(reaction_owner[key]):
			return false
	return true


func set_reaction_observation(value: Dictionary) -> bool:
	if not _matches_owner(value) or value.get("phase", "") != "completion":
		return false
	for key in ["admitted", "present", "succeeded", "canceled"]:
		if typeof(value.get(key)) != TYPE_BOOL:
			return false
	if value.succeeded != value.canceled:
		return false
	if not value.get("contact_world") is Vector3 or not value.contact_world.is_finite():
		return false
	if typeof(value.get("contact_seconds")) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value.contact_seconds)) or float(value.contact_seconds) < 0.0:
		return false
	if value.has("suppressed") and typeof(value.suppressed) != TYPE_BOOL:
		return false
	if reaction_owner.is_empty():
		for key: String in OWNER_KEYS:
			reaction_owner[key] = value[key]
	reaction = value.duplicate(true)
	sample(age_seconds)
	return true


func set_interrupted_presentation(value: Dictionary) -> bool:
	if reaction_owner.is_empty():
		return false
	for key in ["triggered_event_uuid", "triggered_lineage_uuid"]:
		if str(value.get(key, "")) != str(reaction_owner[key]):
			return false
	for key in ["presentation_uuid", "source_owner_uuid"]:
		if str(value.get(key, "")).is_empty():
			return false
		if not presentation.is_empty() and str(value[key]) != str(presentation[key]):
			return false
	if typeof(value.get("present")) != TYPE_BOOL:
		return false
	if typeof(value.get("source_seconds")) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value.source_seconds)) or float(value.source_seconds) < 0.0:
		return false
	presentation = value.duplicate(true)
	sample(age_seconds)
	return true


func set_interrupted_path(value: Dictionary) -> bool:
	if presentation.is_empty() or str(value.get("presentation_uuid", "")) != str(presentation.presentation_uuid):
		return false
	var samples: Variant = value.get("samples")
	if not samples is Array or samples.is_empty() or samples.size() > 128:
		return false
	var prepared: Array[Dictionary] = []
	var previous := -INF
	for sample_value: Variant in samples:
		if not sample_value is Dictionary:
			return false
		var seconds: Variant = sample_value.get("source_seconds")
		var transform_value: Variant = sample_value.get("world_transform")
		if typeof(seconds) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(seconds)) or float(seconds) < 0.0 or float(seconds) <= previous:
			return false
		if not transform_value is Transform3D or not transform_value.is_finite():
			return false
		previous = float(seconds)
		prepared.append({"source_seconds": float(seconds), "world_transform": transform_value})
	path = prepared
	sample(age_seconds)
	return true


func _current_presentation_transform() -> Transform3D:
	var source_seconds := float(presentation.source_seconds)
	for index in range(1, path.size()):
		if source_seconds <= float(path[index].source_seconds):
			var first: Dictionary = path[index - 1]
			var second: Dictionary = path[index]
			var fraction := (source_seconds - float(first.source_seconds)) / (float(second.source_seconds) - float(first.source_seconds))
			return first.world_transform.interpolate_with(second.world_transform, fraction)
	return path[-1].world_transform


func sample(seconds: float) -> void:
	age_seconds = seconds
	hide()
	fragments.sample(-1.0)
	rejection = "reaction_unbound"
	if reaction.is_empty() or not reaction.admitted or not reaction.present or bool(reaction.get("suppressed", false)):
		return
	if interrupted_snapshot.is_empty():
		rejection = "existing_presentation_unbound"
		if presentation.is_empty() or not presentation.present or path.is_empty():
			return
		var source_seconds := float(presentation.source_seconds)
		if source_seconds < float(path[0].source_seconds) or source_seconds > float(path[-1].source_seconds):
			rejection = "actual_source_clock_outside_supplied_path"
			return
		if seconds < float(reaction.contact_seconds):
			return
		# Freeze only already-supplied actual optical facts at this contact.
		# The producer can now retire the incoming visual without killing this
		# separately owned finite reaction or changing its source clock.
		interrupted_snapshot = {"presentation": presentation.duplicate(true),
			"world_transform": _current_presentation_transform(),
			"contact_world": reaction.contact_world, "contact_seconds": reaction.contact_seconds,
			"succeeded": reaction.succeeded}
	fragments.settings.succeeded = interrupted_snapshot.succeeded
	fragments.position = global_transform.affine_inverse() * interrupted_snapshot.contact_world
	var elapsed := seconds - float(interrupted_snapshot.contact_seconds)
	fragments.sample(elapsed)
	visible = seconds >= 0.0 and elapsed >= 0.0 and elapsed < .43
	rejection = ""


func capture_observation() -> Dictionary:
	return {"owner": reaction_owner.duplicate(true), "presentation": presentation.duplicate(true),
		"interrupted_snapshot": interrupted_snapshot.duplicate(true),
		"path_samples": path.size(), "incoming_world_transform": _current_presentation_transform() if not presentation.is_empty() and not path.is_empty() else null,
		"contact_world": reaction.get("contact_world"), "age_seconds": age_seconds,
		"visible": visible, "rejection": rejection,
		"incoming_constructed": false, "incoming_clock_written": false,
		"destination_impact": false, "damage_event": false, "condition_event": false}

const VfxPackageIO_6bdce07d3d = preload("res://assets/vfx/extensions/source-preparation-20261020/scoped_resource_io.gd")
