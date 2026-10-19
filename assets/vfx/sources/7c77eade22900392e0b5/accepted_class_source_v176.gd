extends "res://assets/vfx/sources/5944248dd6bb52ef8394/class_action.gd"
## Private source-fidelity study. Keeps the native family; restores its archived
## strip equations and accepts explicit supplied ownership/feedback, never rules.

var owner_projection: Dictionary = {}
var feedback_events: Array = []
var source_seconds := 0.0
var supplied_envelope := 0.0
var selected_feedback_uuid := ""


static func make_component(input: Dictionary) -> Node3D:
	assert(str(input.kind) in ["mantle", "affinity"])
	for key in ["owner_projection", "native_palette", "rise_seconds", "return_seconds"]:
		assert(input.has(key), "Accepted class source needs explicit " + key)
	var instance := preload("res://assets/vfx/sources/7c77eade22900392e0b5/accepted_class_source_v176.gd").new()
	instance.settings = input.duplicate(true)
	instance.kind = str(input.kind)
	instance.owner_projection = input.owner_projection.duplicate(true)
	instance.feedback_events = input.get("feedback_events", []).duplicate(true)
	instance._validate_projection(instance.owner_projection)
	instance._build()
	return instance


func _validate_projection(projection: Dictionary) -> void:
	for key in ["actor_id", "owner_uuid", "behavior_id", "admitted", "begin_seconds"]:
		assert(projection.has(key), "Explicit class owner needs " + key)
	assert(not str(projection.actor_id).is_empty())
	assert(not str(projection.owner_uuid).is_empty())
	var removed: Variant = projection.get("removed_seconds")
	if removed != null:
		assert((removed is float or removed is int) and is_finite(float(removed)))
		assert(float(removed) < 0.0 or float(removed) >= float(projection.begin_seconds))
	assert(float(settings.rise_seconds) > 0.0 and float(settings.return_seconds) > 0.0)
	for event in feedback_events:
		for key in ["feedback_uuid", "owner_uuid", "actor_id", "kind", "admitted", "energy_type", "begin_seconds"]:
			assert(event.has(key), "Explicit resistance feedback needs " + key)


func set_owner_projection(value: Dictionary) -> void:
	_validate_projection(value)
	owner_projection = value.duplicate(true)
	if is_inside_tree():
		sample(source_seconds)


func set_entity_geometry(value: Dictionary) -> void:
	geometry = value
	if is_inside_tree():
		sample(source_seconds)


func _piece(family: String, index: int) -> MeshInstance3D:
	var result := super._piece(family, index)
	if family == "arc":
		# The archived SorcererArc seed differs from the Flow seed.
		result.material_override.set_shader_parameter("seed", float(index) * .19)
	return result


func _strip(index: int, seconds: float) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments := 32 if kind == "mantle" else 48
	var width := .05 if kind == "mantle" else .045
	var offsets: Array = []
	for step in range(segments + 1):
		var u := float(step) / float(segments)
		var point := _point(index, u, seconds)
		var next := _point(index, minf(u + (.01 if kind == "mantle" else .005), 1.0), seconds)
		var tangent := (next - point).normalized()
		var across := tangent.cross(Vector3.UP if kind == "mantle" else Vector3(.5, .7, .5)).normalized()
		if kind == "mantle" and across.length() < .1:
			across = Vector3.RIGHT
		offsets.append([point - across * width, point + across * width])
	for step in segments:
		for coordinate in [Vector2i(step, 0), Vector2i(step, 1), Vector2i(step + 1, 1), Vector2i(step, 0), Vector2i(step + 1, 1), Vector2i(step + 1, 0)]:
			surface.set_uv(Vector2(float(coordinate.x) / float(segments), coordinate.y))
			surface.add_vertex(offsets[coordinate.x][coordinate.y])
	return surface.commit()


func _owner_admitted() -> bool:
	if not bool(owner_projection.admitted) or bool(owner_projection.get("suppressed", false)):
		return false
	if str(geometry.get("actor", "")) != str(owner_projection.actor_id):
		return false
	if geometry.get("points", []).size() < 8:
		return false
	if kind == "mantle":
		if str(owner_projection.behavior_id) != "class_feature.barbarian.raging":
			return false
		if settings.get("frenzied_child_required", false):
			var child: Dictionary = owner_projection.get("frenzied_child", {})
			return bool(child.get("admitted", false)) and not bool(child.get("suppressed", false)) and not str(child.get("owner_uuid", "")).is_empty() and str(child.get("behavior_id", "")) == "class_feature.barbarian.frenzied" and str(child.get("parent_owner_uuid", "")) == str(owner_projection.owner_uuid)
		return true
	return str(owner_projection.behavior_id) == "class_feature.sorcerer.elemental_affinity.resistance" and not str(owner_projection.get("energy_type", "")).is_empty()


func _owner_tail(seconds: float) -> float:
	if seconds < float(owner_projection.begin_seconds):
		return 0.0
	var removed: Variant = owner_projection.get("removed_seconds")
	if removed == null or float(removed) < 0.0:
		return 1.0
	return 1.0 - smoothstep(float(removed), float(removed) + float(settings.return_seconds), seconds)


func sample(seconds: float) -> void:
	source_seconds = seconds
	selected_feedback_uuid = ""
	supplied_envelope = 0.0
	var native_seconds := maxf(0.0, seconds - float(owner_projection.begin_seconds))
	if _owner_admitted():
		if kind == "mantle":
			supplied_envelope = smoothstep(0.0, float(settings.rise_seconds), native_seconds) * _owner_tail(seconds)
		else:
			for event in feedback_events:
				if not bool(event.admitted) or str(event.owner_uuid) != str(owner_projection.owner_uuid) or str(event.actor_id) != str(owner_projection.actor_id):
					continue
				if str(event.kind) not in ["resistance_activated", "resistance_feedback"] or str(event.energy_type) != str(owner_projection.energy_type):
					continue
				var local := seconds - float(event.begin_seconds)
				# An old owner's event cannot be replayed after its explicit removal.
				var removed: Variant = owner_projection.get("removed_seconds")
				if float(event.begin_seconds) < float(owner_projection.begin_seconds) or (removed != null and float(removed) >= 0.0 and float(event.begin_seconds) >= float(removed)):
					continue
				var strength := smoothstep(0.0, .14, local) * (1.0 - smoothstep(.80, 1.25, local)) * _owner_tail(seconds)
				if strength > supplied_envelope:
					supplied_envelope = strength
					native_seconds = local
					selected_feedback_uuid = str(event.feedback_uuid)
	# Native source construction, actual measured fit, mask, noise, motes and
	# explicit palette remain inherited. Only the archived strip frame/seed and
	# supplied finite ownership replace the port's respective policies.
	super.sample(native_seconds)
	var strength := supplied_envelope * float(settings.get("strength_multiplier", 1.0))
	for piece in pieces:
		piece.material_override.set_shader_parameter("strength", strength)
	for mote in motes:
		var color: Color = mote.material_override.albedo_color
		color.a = strength * .65
		mote.material_override.albedo_color = color
	visible = strength > .000001


func capture_observation() -> Dictionary:
	var result: Dictionary = super.capture_observation()
	result.merge({
		"restoration": "archived mantle strip frame/32 segments; archived SorcererArc seed and one-sided source strip tangent",
		"source_seconds": source_seconds, "supplied_envelope": supplied_envelope,
		"owner_uuid": owner_projection.owner_uuid, "actor_id": owner_projection.actor_id,
		"actual_geometry_actor": geometry.get("actor", ""), "selected_feedback_uuid": selected_feedback_uuid,
		"owner_admitted_with_real_geometry": _owner_admitted(), "one_source_assembly": true,
		"native_palette_passes": 1, "body_shimmer_bound": false,
		"passive_math_creates_feedback": false, "rules_solver": false,
	})
	return result
