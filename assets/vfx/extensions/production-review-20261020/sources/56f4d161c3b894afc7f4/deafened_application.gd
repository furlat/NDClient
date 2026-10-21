extends "res://assets/vfx/sources/0bc74974aa945fc9593d/control_status_overhead.gd"
## Finite application using the existing Deafened donor, radial flow and glyph.
## The persistent condition marker remains a separate source/lifetime.
var source_age_seconds := 0.0
var application_emitters: Array[GPUParticles3D] = []


static func make_component(input: Dictionary) -> Node3D:
	if input.get("settings", {}).get("kind", "") != "deafened":
		return null
	var duration := float(input.get("application_seconds", 1.2))
	var fade := float(input.get("fade_seconds", .3))
	if not is_finite(duration) or not is_finite(fade) or duration <= 0.0 or fade <= 0.0 or fade > duration:
		return null
	return construct("res://assets/vfx/extensions/production-review-20261020/sources/56f4d161c3b894afc7f4/deafened_application.gd", input)


func apply_scene_edits(node: Node) -> void:
	super.apply_scene_edits(node)
	for emitter: GPUParticles3D in node.find_children("*", "GPUParticles3D", true, false):
		if emitter.layers != 0:
			application_emitters.append(emitter)


func update_geometry() -> void:
	super.update_geometry()
	if head_endpoints.is_empty() or not head_endpoints[0].get("point") is Vector3:
		return
	# The existing optical endpoint owns emission placement. Preserve every
	# native donor extent/material/velocity; remove only the obsolete fixed
	# source-height assumption, which floated the wisps above the actual head.
	var head: Vector3 = head_endpoints[0].point
	for emitter: GPUParticles3D in application_emitters:
		emitter.global_position = head


func application_envelope(seconds: float) -> float:
	var duration := float(parameters.get("application_seconds", 1.2))
	var fade := float(parameters.get("fade_seconds", .3))
	if seconds < 0.0 or seconds >= duration:
		return 0.0
	return 1.0 - smoothstep(duration - fade, duration, seconds)


func sample(seconds: float) -> void:
	super.sample(maxf(0.0, seconds))
	source_age_seconds = seconds
	var envelope := application_envelope(seconds)
	for material: ShaderMaterial in materials:
		material.set_shader_parameter("support_envelope", envelope)
	visible = envelope > 0.0 and not head_endpoints.is_empty()


func capture_observation() -> Dictionary:
	var result := super.capture_observation()
	result.kind = "deafened"
	result.phase = "finite_application"
	result.source_age_seconds = source_age_seconds
	result.envelope = application_envelope(source_age_seconds)
	result.persistent_marker_owned = false
	return result
