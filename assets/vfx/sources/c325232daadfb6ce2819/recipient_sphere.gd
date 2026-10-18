extends Node3D
## A real force enclosure sized once from the recipient's painted geometry.
## Owner state, accepted ending and movement are supplied facts, never rules.
const FieldMaterial = preload("res://assets/vfx/sources/89da09bf4ca66175808e/field_material.gd")

var specification: Dictionary = {}
var endpoints: Array = []
var surface: Dictionary = {}
var owner_state: Dictionary = {}
var material: ShaderMaterial
var shell: MeshInstance3D
var radius := 0.0
var centre_offset := Vector3.ZERO
var local_clock := 0.0
var visibility := 0.0

static func make_component(input: Dictionary) -> Node3D:
	assert(not str(input.owner_uuid).is_empty())
	var effect: Node3D = VfxPackageIO_c325232daa.resource("res://assets/vfx/sources/c325232daadfb6ce2819/recipient_sphere.gd").new()
	effect.specification = input.duplicate(true)
	effect.material = FieldMaterial.build(input.material)
	effect.shell = MeshInstance3D.new()
	effect.shell.name = "RecipientForceBoundary"
	effect.shell.top_level = true
	effect.shell.material_override = effect.material
	effect.shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	effect.add_child(effect.shell)
	effect.shell.hide()
	return effect

func set_live_endpoints(value: Array) -> void:
	endpoints = value.duplicate(true)
	if radius <= 0.0 and not surface.is_empty():
		set_entity_geometry(surface)
	sample(local_clock)

func set_entity_geometry(value: Dictionary) -> void:
	surface = value
	if radius <= 0.0 and not endpoints.is_empty() and surface.get("points", []).size() >= 8:
		var minimum := Vector3(INF, INF, INF)
		var maximum := -minimum
		for point in surface.points:
			minimum = minimum.min(point.position)
			maximum = maximum.max(point.position)
		# The actual body is enclosed, including a margin, without a pose-driven
		# expanding/contracting bubble on every Idle or Run sample.
		var centre := (minimum + maximum) * .5
		centre_offset = centre - Vector3(endpoints[0].point)
		for point in surface.points:
			radius = maxf(radius, centre.distance_to(point.position))
		radius += float(specification.clearance_cells)
		var mesh := SphereMesh.new()
		mesh.radius = radius
		mesh.height = radius * 2.0
		mesh.radial_segments = 64
		mesh.rings = 32
		shell.mesh = mesh
	sample(local_clock)

func set_owner_state(value: Dictionary) -> bool:
	if str(value.get("owner_uuid", "")) != str(specification.owner_uuid):
		return false
	owner_state = value.duplicate(true)
	sample(local_clock)
	return true

func _observed_state(seconds: float) -> Dictionary:
	var state: Dictionary = specification.state.duplicate(true)
	for row in specification.get("review_states", []):
		if seconds >= float(row.seconds):
			state.merge(row.state, true)
	if not owner_state.is_empty():
		state = owner_state.duplicate(true)
	return state

func sample(seconds: float) -> void:
	local_clock = seconds
	if shell == null or endpoints.is_empty() or radius <= 0.0:
		return
	var state := _observed_state(seconds)
	var active: bool = str(state.get("owner_uuid", "")) == str(specification.owner_uuid)
	active = active and bool(state.get("present", false)) and bool(state.get("observed", false)) and not bool(state.get("suppressed", true))
	visibility = smoothstep(0.0, float(specification.apply_seconds), seconds) if active else 0.0
	if state.has("ending_started_at"):
		var age: float = maxf(0.0, seconds - float(state.ending_started_at))
		visibility *= 1.0 - smoothstep(0.0, float(specification.retire_seconds), age)
	material.set_shader_parameter("field_clock", seconds + float(specification.get("phase_offset_seconds", 0.0)))
	material.set_shader_parameter("field_opacity", visibility * float(specification.opacity))
	if specification.material.get("world_ground_clip", false):
		material.set_shader_parameter("field_ground_height", endpoints[0].point.y)
	shell.global_transform = Transform3D(Basis.IDENTITY, endpoints[0].point + centre_offset)
	shell.visible = visibility > .0001

func capture_observation() -> Dictionary:
	return {"recipient_sphere": {"owner_uuid": specification.owner_uuid, "receiving_actor": surface.get("actor"),
		"point_count": surface.get("points", []).size(), "radius_cells": radius, "clock": local_clock,
		"visibility": visibility, "centre": shell.global_position, "optical_lights": 0,
		"visible_ground_clip": specification.material.get("world_ground_clip", false),
		"ground_height_cells": endpoints[0].point.y if not endpoints.is_empty() else 0.0}}

const VfxPackageIO_c325232daa = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
