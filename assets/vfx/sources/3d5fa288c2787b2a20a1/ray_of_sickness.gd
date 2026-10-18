extends Node3D
## Finite, narrow poison ray. The caller supplies attack/save/condition outcomes.
## This component never applies Poisoned or counts recipient turns.
const Materials = preload("res://assets/vfx/sources/0f15a3f72a38e511db8c/acid_sickness_materials.gd")
const Ribbon = preload("res://assets/vfx/sources/31348bd589e2d41ae443/path_ribbon.gd")

var specification: Dictionary = {}
var endpoints: Array = []
var beams: Array[MeshInstance3D] = []
var motes: Array[MeshInstance3D] = []
var materials: Array[ShaderMaterial] = []
var launch_seconds: float = 0.3
var travel_seconds: float = 0.38
var last_source := Vector3.ZERO
var last_recipient := Vector3.ZERO
var last_front := Vector3.ZERO
var last_contact_error_cells: float = 0.0


static func make_component(input: Dictionary) -> Node3D:
	var effect: Node3D = VfxPackageIO_3d5fa288c2.resource("res://assets/vfx/sources/3d5fa288c2787b2a20a1/ray_of_sickness.gd").new()
	effect.specification = input.duplicate(true)
	effect.launch_seconds = float(input.get("launch_seconds", 0.3))
	effect.travel_seconds = float(input.get("travel_seconds", 0.38))
	return effect


func set_live_endpoints(value: Array) -> void:
	endpoints = value


func set_delivery_timing(launch: float, travel: float) -> void:
	launch_seconds = maxf(0.0, launch)
	travel_seconds = maxf(0.001, travel)


func prepare() -> void:
	var source: PackedScene = VfxPackageIO_3d5fa288c2.resource(specification.scene)
	var original: Node3D = source.instantiate()
	var colors: Array = specification.palette
	for selection in ["BeamPivot/BeamScalor/BeamCore", "BeamPivot/BeamScalor/BeamOuter"]:
		var selected: MeshInstance3D = original.get_node(selection)
		var material: ShaderMaterial = Materials.extract(selected.material_override, colors, 0.2)
		material.set_shader_parameter("emission", 1.0)
		material.set_shader_parameter("open_amount", 1.0)
		material.set_shader_parameter("pulse_strength", 0.003)
		material.set_shader_parameter("pulse_speed", 13.0)
		material.set_shader_parameter("pulse_frequency", 18.0)
		materials.append(material)
		beams.append(Materials.draw(self, "RayCore" if beams.is_empty() else "PoisonVeil", null, material))
	var original_contact: MeshInstance3D = original.get_node("BeamEndPivot/BeamEnd")
	var contact_material: ShaderMaterial = Materials.extract(original_contact.material_override, colors, 0.12)
	contact_material.set_shader_parameter("emission", 0.75)
	contact_material.set_shader_parameter("flash_amount", 0.0)
	materials.append(contact_material)
	var mesh := SphereMesh.new()
	mesh.radius = 0.035
	mesh.height = 0.07
	mesh.radial_segments = 12
	mesh.rings = 6
	for index in 7:
		motes.append(Materials.draw(self, "PoisonMote" + str(index), mesh, contact_material))
	original.free()


func sample(seconds: float) -> void:
	if beams.is_empty():
		prepare()
	for draw in beams + motes:
		draw.hide()
	for material in materials:
		Materials.clock(material, seconds, 0.0)
	if endpoints.size() < 2:
		return
	var inverse: Transform3D = global_transform.affine_inverse()
	var hand: Vector3 = inverse * endpoints[0].point
	var recipient: Vector3 = inverse * endpoints[1].point
	var source: Vector3 = inverse * endpoints[2].point if endpoints.size() >= 3 else hand
	last_source = source
	last_recipient = recipient
	var phase: String = specification.phase
	if phase == "impact":
		_sample_contact(seconds, recipient, source)
		return
	if seconds < launch_seconds:
		var preparation: float = smoothstep(0.0, maxf(launch_seconds, 0.001), seconds)
		for index in 3:
			motes[index].position = hand + Vector3(sin(float(index) * 2.1) * 0.045, float(index) * 0.025, cos(float(index) * 2.1) * 0.045)
			motes[index].scale = Vector3(0.7, 1.5, 0.7) * preparation
			motes[index].visible = preparation > 0.001
		Materials.clock(materials[2], seconds, preparation * 0.6)
		last_front = hand
		return
	var after_launch: float = seconds - launch_seconds
	var front_weight: float = clampf(after_launch / travel_seconds, 0.0, 1.0)
	var after_contact: float = after_launch - travel_seconds
	var tail_weight: float = smoothstep(0.0, 0.22, after_contact) if after_contact > 0.0 else 0.0
	var envelope: float = 1.0 - smoothstep(0.03, 0.23, after_contact)
	if envelope <= 0.001 or front_weight - tail_weight <= 0.001:
		return
	var ray_start: Vector3 = source.lerp(recipient, tail_weight)
	var ray_end: Vector3 = source.lerp(recipient, front_weight)
	last_front = ray_end
	last_contact_error_cells = ray_end.distance_to(recipient) if front_weight >= 1.0 else 0.0
	var direction: Vector3 = (recipient - source).normalized()
	var side: Vector3 = direction.cross(Vector3.UP).normalized()
	if side.is_zero_approx():
		side = Vector3.RIGHT
	for layer in beams.size():
		var points: Array[Vector3] = []
		var widths: Array[float] = []
		for index in 25:
			var along: float = float(index) / 24.0
			var bend: float = sin(along * PI) * sin(along * 17.0 - seconds * 11.0) * 0.012 * float(layer + 1)
			points.append(ray_start.lerp(ray_end, along) + side * bend)
			widths.append((0.012 if layer == 0 else 0.042) * (0.55 + 0.45 * sin(along * PI)))
		if specification.get("gpu_paths", false):
			preload("res://assets/vfx/sources/34e0f9ed9a909885cd97/path_ribbon.gd").assign(beams[layer],points,widths,Color.WHITE,Vector2(0,.48 if layer==0 else 1.))
		else:
			var mesh: ArrayMesh = Ribbon.build(points, widths)
			if layer == 0:
				# The native core expects its visible longitudinal UV range below .5.
				var arrays: Array = mesh.surface_get_arrays(0)
				var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
				for index in uv.size():
					uv[index].y *= 0.48
				arrays[Mesh.ARRAY_TEX_UV] = uv
				mesh = ArrayMesh.new()
				mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			beams[layer].mesh = mesh
		beams[layer].show()
		Materials.clock(materials[layer], seconds, envelope * (0.8 if layer == 0 else 0.55))
	for index in 3:
		motes[index].position = ray_end - direction * float(index) * 0.045
		motes[index].scale = Vector3(0.8, 1.2, 0.8)
		motes[index].show()
	Materials.clock(materials[2], seconds, envelope * 0.55)


func _sample_contact(seconds: float, recipient: Vector3, source: Vector3) -> void:
	if specification.get("attack_outcome", "hit") == "miss":
		return
	var envelope: float = smoothstep(0.0, 0.035, seconds) * (1.0 - smoothstep(0.08, 0.4, seconds))
	var toward_source: Vector3 = (source - recipient).normalized()
	var side: Vector3 = toward_source.cross(Vector3.UP).normalized()
	if side.is_zero_approx():
		side = Vector3.RIGHT
	for index in motes.size():
		var angle: float = float(index) * 2.39996
		var spread: Vector3 = side * cos(angle) + Vector3.UP * sin(angle)
		motes[index].position = recipient + toward_source * 0.015 + spread * seconds * (0.2 + float(index % 3) * 0.08)
		motes[index].scale = Vector3(0.6, 1.0, 0.6) * (1.0 + seconds)
		motes[index].visible = envelope > 0.001
	Materials.clock(materials[2], seconds, envelope * 0.65)
	last_front = recipient
	last_contact_error_cells = 0.0


func capture_observation() -> Dictionary:
	return {"phase": specification.phase, "source_scene": specification.scene,
		"source_author": "BinbunVFX", "live_endpoint_count": endpoints.size(),
		"source": last_source, "recipient": last_recipient, "front": last_front,
		"contact_error_cells": last_contact_error_cells, "optical_lights": 0,
		"applies_condition": false, "counts_recipient_turns": false,
		"attack_outcome": specification.get("attack_outcome", "hit")}

const VfxPackageIO_3d5fa288c2 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
