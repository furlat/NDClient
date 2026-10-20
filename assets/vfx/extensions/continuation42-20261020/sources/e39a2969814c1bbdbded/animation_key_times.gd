extends RefCounted
## Native Animation serialization stores its key times as float32, even in a
## binary Resource. Retimed source clocks need an explicit float64 witness.
const KEY := "factory_exact_animation_key_times_v1"
const RESTORED := "factory_exact_animation_key_times_restored_v1"


static func capture(animation: Animation) -> void:
	var tracks: Array = []
	for track in animation.get_track_count():
		var times := PackedFloat64Array()
		for index in animation.track_get_key_count(track):
			times.append(animation.track_get_key_time(track, index))
		tracks.append({"path": animation.track_get_path(track),
			"type": animation.track_get_type(track), "times": times})
	animation.set_meta(KEY, tracks)
	animation.remove_meta(RESTORED)


static func prepare_scene(scene: PackedScene) -> int:
	var state := scene.get_state()
	var seen := {}
	var count := 0
	for node in state.get_node_count():
		for property in state.get_node_property_count(node):
			count += _prepare_value(state.get_node_property_value(node, property), seen)
	return count


static func _prepare_value(value: Variant, seen: Dictionary) -> int:
	var count := 0
	if value is Animation:
		if not seen.has(value):
			seen[value] = true
			count += restore_before_publication(value)
	elif value is AnimationLibrary:
		if not seen.has(value):
			seen[value] = true
			for name: String in value.get_animation_list():
				count += _prepare_value(value.get_animation(name), seen)
	elif value is Array:
		for child in value:
			count += _prepare_value(child, seen)
	elif value is Dictionary:
		for child in value.values():
			count += _prepare_value(child, seen)
	return count


static func restore_before_publication(animation: Animation) -> int:
	if not animation.has_meta(KEY):
		return 0
	var tracks: Array = animation.get_meta(KEY)
	assert(animation.get_track_count() == tracks.size(), "Exact animation track structure changed")
	var restored := 0
	var already_exact := animation.has_meta(RESTORED)
	for track in tracks.size():
		var record: Dictionary = tracks[track]
		var times: PackedFloat64Array = record.times
		assert(animation.track_get_path(track) == record.path and animation.track_get_type(track) == record.type)
		assert(animation.track_get_key_count(track) == times.size(), "Collapsed/changed native key count needs a separate source audit")
		for index in times.size():
			var actual := animation.track_get_key_time(track, index)
			var rounded := float(PackedFloat32Array([times[index]])[0])
			assert(actual == times[index] or actual == rounded, "Unknown animation clock state must not be overwritten")
			if actual != times[index]:
				# A previously prepared Resource may be saved again by a native
				# package converter. Its metadata survives, but Godot rounds the
				# actual keys again; the old marker is not a precision guarantee.
				already_exact = false
				animation.track_set_key_time(track, index, times[index])
			assert(animation.track_get_key_time(track, index) == times[index])
			restored += 1
	animation.set_meta(RESTORED, true)
	return 0 if already_exact else restored
