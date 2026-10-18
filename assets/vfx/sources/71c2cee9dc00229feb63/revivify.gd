extends "res://assets/vfx/sources/a4fd0883f0b17d893a03/base.gd"
## Original Level-Up D rising-ray geometry, with its unrelated HUD text excluded.
## The recipient and life/position changes remain supplied by the caller.
var ring: MeshInstance3D
var ring_curve: Curve
var ring_colors: Gradient
var ring_lifetime_seconds: float
var recipient_geometry: Dictionary = {}


func set_entity_geometry(value: Dictionary) -> void:
	recipient_geometry = value


func update_geometry() -> void:
	var points: Array = recipient_geometry.get("points", [])
	if points.is_empty():
		return
	var center := Vector3.ZERO
	for point in points:
		center += to_local(point.position)
	center /= float(points.size())
	# A lying sprite extends away from its standing registration point. Fit the
	# rising release to the actual current silhouette, while keeping ground Y.
	subject.position.x = center.x
	subject.position.z = center.z


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/71c2cee9dc00229feb63/revivify.gd", input)


func apply_scene_edits(node: Node) -> void:
	node.scale *= float(settings.scale)
	var source: CPUParticles3D = node.get_node("Circle1")
	ring = MeshInstance3D.new()
	ring.name = "RevivalGroundRelease"
	ring.mesh = source.mesh
	ring.material_override = source.material_override
	ring.position = source.position
	ring.position.y = 0.03
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring_curve = source.scale_amount_curve
	ring_colors = source.color_ramp
	ring_lifetime_seconds = source.lifetime
	node.add_child(ring)
	# Convert the single CPU ring to an explicitly sampled source curve. Its
	# material/mesh survive; wall-clock CPU particle playback does not.
	source.hide()
	source.emitting = false
	source.layers = 0
	for particle in node.find_children("*", "GPUParticles3D", true, false):
		particle.local_coords = true
		particle.fixed_fps = int(parameters.simulation_hz)
		particle.visibility_aabb = AABB(Vector3(-3, -1, -3), Vector3(6, 8, 6))


func advance_lifecycle(delta: float) -> void:
	super.advance_lifecycle(delta)
	var age: float = float(tick) / float(parameters.simulation_hz)
	var phase: float = clampf(age / ring_lifetime_seconds, 0.0, 1.0)
	var radius: float = 0.6 * ring_curve.sample_baked(phase)
	ring.scale = Vector3.ONE * radius
	ring.visible = age < ring_lifetime_seconds and radius > 0.001
	var fade: float = smoothstep(0.0, 0.1, age) * (1.0 - smoothstep(1.4, 2.0, age))
	for material in materials:
		material.set_shader_parameter("support_envelope", fade)
	if ring.material_override is ShaderMaterial:
		ring.material_override.set_shader_parameter("support_envelope", fade * ring_colors.sample(phase).a)


func capture_observation() -> Dictionary:
	return {"source": parameters.scene, "sampled_ground_ring": true,
		"recipient_surface_points": recipient_geometry.get("points", []).size(),
		"optical_lights": 0, "changes_gameplay_life_state": false,
		"phase_clock_seconds": float(tick) / float(parameters.simulation_hz)}
