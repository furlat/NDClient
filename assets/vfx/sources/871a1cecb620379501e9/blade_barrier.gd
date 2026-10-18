extends Node3D
## Permeable source-metal blades along the supplied single wall segment.
## Native geometry and spinning transforms stay inside the supplied volume.
const AuthoredBlade = preload("res://assets/vfx/sources/d833237419eecdcf8f8b/authored_blade.gd")
const MaterialValues = preload("res://assets/vfx/sources/601eb8db9c55b6ad084e/shader_material.gd")
const PathRibbon = preload("res://assets/vfx/sources/31348bd589e2d41ae443/path_ribbon.gd")

var specification: Dictionary = {}
var endpoints: Array = []
var blades: Array[MeshInstance3D] = []
var stations: Array = []
var material: ShaderMaterial
var wake_material: ShaderMaterial
var wakes: Array[MeshInstance3D] = []
var local_clock := 0.0
var owner_state: Dictionary = {}
var visibility := 0.0
var cached_length := -1.0

static func make_component(input: Dictionary) -> Node3D:
	var effect: Node3D = VfxPackageIO_871a1cecb6.resource("res://assets/vfx/sources/871a1cecb620379501e9/blade_barrier.gd").new()
	effect.specification = input.duplicate(true)
	effect.material = MaterialValues.build(input.material)
	effect.wake_material = MaterialValues.build(input.wake_material)
	# This fixed spatial owner supplies its admitted path length at birth.
	# Register actual source geometry before the native renderer's first scan.
	effect._prepare(float(input.length_cells))
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

func _prepare(length: float) -> void:
	for blade in blades:
		blade.free()
	for wake in wakes:
		wake.free()
	blades.clear()
	wakes.clear()
	stations.clear()
	cached_length = length
	var mesh := AuthoredBlade.mesh(specification.geometry)
	var columns := maxi(1, int(ceil(length / float(specification.station_spacing_cells))))
	var rows := int(specification.height_cells)
	for column in columns:
		for row in rows:
			var blade := MeshInstance3D.new()
			blade.name = "WhirlingSteel%d_%d" % [column, row]
			blade.top_level = true
			blade.mesh = mesh
			blade.material_override = material
			blade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(blade)
			blade.hide()
			blades.append(blade)
			var wake := MeshInstance3D.new()
			wake.name = "ActualBladeTipHistory%d_%d" % [column, row]
			wake.mesh = PathRibbon.build([Vector3.ZERO, Vector3.UP * .001], [.001, .001])
			wake.material_override = wake_material
			wake.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			wake.top_level = true
			add_child(wake)
			wake.hide()
			wakes.append(wake)
			stations.append({"along": (float(column) + .5) / columns, "height": float(row) + .5,
				"phase": float(column) * 2.399963 + float(row) * 1.7})

func blade_pose(station: Dictionary, seconds: float, from: Vector3, to: Vector3) -> Transform3D:
	var direction := (to - from).normalized()
	var cross_direction := direction.cross(Vector3.UP).normalized()
	var phase := seconds * float(specification.spin_radians_per_second) + float(station.phase)
	var centre := from.lerp(to, float(station.along)) + Vector3.UP * float(station.height)
	centre += cross_direction * .18 * cos(phase * .7 + float(station.phase))
	var axis := (direction * cos(phase) + Vector3.UP * sin(phase) + cross_direction * .25 * sin(phase * .7)).normalized()
	var across := cross_direction.slide(axis).normalized()
	# End stations must remain inside the resolved segment, even when a blade
	# rotates parallel to it. Vertical stations likewise stay below its top.
	var along_clearance := minf(float(station.along), 1.0 - float(station.along)) * from.distance_to(to)
	var height_clearance := minf(float(station.height), float(specification.height_cells) - float(station.height))
	var half_length := float(specification.geometry.length_cells) * .5
	var available := minf(along_clearance, height_clearance) - .035
	var scale_factor := minf(1.0, maxf(.01, available) / half_length)
	var orientation := Basis(across, axis, across.cross(axis).normalized()).scaled(Vector3.ONE * scale_factor)
	var hilt := centre - axis * half_length * scale_factor
	return Transform3D(orientation, hilt)

func sample(seconds: float) -> void:
	local_clock = seconds
	if endpoints.size() < 2:
		return
	var from: Vector3 = endpoints[0].point
	var to: Vector3 = endpoints[1].point
	var length := from.distance_to(to)
	assert(length > 0.0)
	assert(is_equal_approx(length, cached_length), "A retained fixed wall uses its supplied birth length; a changed owner needs a new component")
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
	material.set_shader_parameter("field_opacity", visibility)
	material.set_shader_parameter("field_clock", seconds)
	wake_material.set_shader_parameter("field_opacity", visibility)
	_render_blades(seconds,from,to)

func _render_blades(seconds: float,from: Vector3,to: Vector3) -> void:
	for index in blades.size():
		var station: Dictionary = stations[index]
		blades[index].global_transform = blade_pose(station, seconds, from, to)
		blades[index].visible = visibility > .0001
		var history: Array[Vector3] = []
		var widths: Array[float] = []
		for sample_index in 12:
			var weight: float = float(sample_index) / 11.0
			var previous := blade_pose(station, seconds - .16 * (1.0 - weight), from, to)
			history.append(previous * (Vector3.UP * float(specification.geometry.length_cells)))
			widths.append(.028 * sin(weight * PI))
		wakes[index].mesh = PathRibbon.build(history, widths)
		wakes[index].global_transform = Transform3D.IDENTITY
		wakes[index].visible = visibility > .0001

func capture_observation() -> Dictionary:
	return {"blade_barrier": {"owner_uuid": specification.owner_uuid, "length_cells": cached_length,
		"height_cells": specification.height_cells, "width_cells": specification.width_cells,
		"blade_count": blades.size(), "clock": local_clock, "visibility": visibility, "optical_lights": 0,
		"damage_and_crossings": "Authoritative formation/entry/START outcomes supplied separately; no local collision or damage timer"}}

const VfxPackageIO_871a1cecb6 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
