extends Node3D
## Moving life-exclusion boundary. Its actual radius and crossing/ending facts
## are supplied by the spatial owner. No projectile or living-type rule here.
const FieldMaterial = preload("res://assets/vfx/sources/89da09bf4ca66175808e/field_material.gd")

var specification: Dictionary = {}
var endpoints: Array = []
var material: ShaderMaterial
var shell: MeshInstance3D
var local_clock := 0.0
var owner_state: Dictionary = {}
var visibility := 0.0

static func make_component(input: Dictionary) -> Node3D:
	assert(float(input.radius_cells) > 0.0 and not str(input.owner_uuid).is_empty())
	var effect: Node3D = VfxPackageIO_2b05da797b.resource("res://assets/vfx/sources/2b05da797b753965e80e/area_shell.gd").new()
	effect.specification = input.duplicate(true)
	effect.material = FieldMaterial.build(input.material)
	effect.shell = MeshInstance3D.new()
	effect.shell.name = "LifeExclusionBoundary"
	effect.shell.top_level = true
	var mesh := SphereMesh.new()
	mesh.radius = float(input.radius_cells)
	mesh.height = mesh.radius * 2.0
	mesh.radial_segments = 96
	mesh.rings = 48
	effect.shell.mesh = mesh
	effect.shell.material_override = effect.material
	effect.shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	effect.add_child(effect.shell)
	effect.shell.hide()
	return effect

func set_live_endpoints(value: Array) -> void:
	endpoints = value.duplicate(true)
	sample(local_clock)

func set_owner_state(value: Dictionary) -> bool:
	if str(value.get("owner_uuid", "")) != str(specification.owner_uuid):
		return false
	owner_state = value.duplicate(true)
	sample(local_clock)
	return true

func sample(seconds: float) -> void:
	local_clock = seconds
	if endpoints.is_empty():
		return
	var state: Dictionary = specification.state.duplicate(true)
	for row in specification.get("review_states", []):
		if seconds >= float(row.seconds):
			state.merge(row.state, true)
	if not owner_state.is_empty():
		state = owner_state.duplicate(true)
	var active: bool = str(state.get("owner_uuid", "")) == str(specification.owner_uuid)
	active = active and bool(state.get("present", false)) and bool(state.get("observed", false)) and not bool(state.get("suppressed", true))
	visibility = smoothstep(0.0, float(specification.apply_seconds), seconds) if active else 0.0
	if state.has("ending_started_at"):
		visibility *= 1.0 - smoothstep(0.0, float(specification.retire_seconds), seconds - float(state.ending_started_at))
	material.set_shader_parameter("field_clock", seconds + float(specification.get("phase_offset_seconds", 0.0)))
	material.set_shader_parameter("field_opacity", visibility * float(specification.opacity))
	shell.global_transform = Transform3D(Basis.IDENTITY, endpoints[0].point + Vector3(0, .012, 0))
	shell.visible = visibility > .0001

func capture_observation() -> Dictionary:
	return {"life_exclusion": {"owner_uuid": specification.owner_uuid, "radius_cells": specification.radius_cells,
		"centre": shell.global_position, "clock": local_clock, "visibility": visibility, "optical_lights": 0,
		"crossing_outcomes": "Supplied authoritative facts; no local movement/type/teleport rule"}}

const VfxPackageIO_2b05da797b = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
