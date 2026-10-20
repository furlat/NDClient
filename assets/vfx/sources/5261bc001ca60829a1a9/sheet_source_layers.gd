extends Node3D
## Isolated-sheet source study. Consumes disclosed visible-frame anchors, not
## a reconstructed whole blade. Production pose binding is not qualified yet.
const SOURCE := "factory-path:authoring/modular-weapons-20261020/lelu-assembly/"
var flames: Node3D
var trail: GPUParticles3D
var process_material: ShaderMaterial
var binding: Dictionary = {}
var pose: Dictionary = {}
var previous_seconds := -1.0
var swing_active := false
var pose_admitted := false
var previous_pose_key: Array = []
var previous_clip := ""
var trail_from_near := Vector3.ZERO
var trail_from_far := Vector3.ZERO
var trail_near := Vector3.ZERO
var trail_far := Vector3.ZERO
var pose_changed_seconds := 0.0
var trail_was_active := false
var previous_source_row := -1
var motion_wake_enabled := false
var artistic_strength := "medium"
var variant_id := "fire.blade_tongues"
var axial_material: ShaderMaterial
var ready_cost: Dictionary = {}
var prepared_scene: PackedScene
var prepared_layers: Array = []

func _ready() -> void:
	var started := Time.get_ticks_usec()
	if not prepared_layers.is_empty():
		flames = Node3D.new()
		flames.name = "PurchasedFireLayers"
		flames.hide()
		for definition in prepared_layers:
			var particle := GPUParticles3D.new()
			particle.name = definition.name
			for field in definition.properties:
				var value: Variant = definition.properties[field]
				# The only mutable per-occurrence visual operand is material_override.
				# Process settings, source curves, textures and meshes are immutable.
				particle.set(field, value.duplicate(false) if field == "material_override" and value is ShaderMaterial else value)
			flames.add_child(particle)
	else:
		flames = (prepared_scene if prepared_scene != null else VfxPackageIO_5261bc001c.resource("res://assets/vfx/sources/685f3368cf7e1f336f2e/fire_layers.tscn")).instantiate()
	ready_cost.instantiate_us = Time.get_ticks_usec() - started
	started = Time.get_ticks_usec()
	add_child(flames)
	ready_cost.registration_us = Time.get_ticks_usec() - started
	if prepared_scene != null or not prepared_layers.is_empty():
		axial_material = flames.get_node("Fire").material_override
		_retire_visible()
		return
	for particle in flames.get_children():
		# Only scalar process operands change. Shared curves/textures stay read-only.
		particle.process_material = particle.process_material.duplicate(false)
		if particle.name == "Fire":
			axial_material = ShaderMaterial.new()
			axial_material.shader = VfxPackageIO_5261bc001c.resource("res://assets/vfx/sources/f141bb3a90913c45439d/source_axial_flame.gdshader")
			axial_material.set_shader_parameter("source_flipbook", particle.material_override.albedo_texture)
			axial_material.set_shader_parameter("lateral_scale", .34 if variant_id == "fire.ember_sheath" else .48)
			axial_material.set_shader_parameter("axial_scale", 1.15 if variant_id == "fire.ember_sheath" else 1.45)
			particle.material_override = axial_material
			# The original flipbook/fire layer now advects along source +Y:
			# our explicitly named hilt→tip axis, never world up or a centroid.
			particle.position.y = .19
			particle.amount = {"lesser": 32, "medium": 56, "greater": 80}[artistic_strength]
			particle.lifetime = .52
			particle.process_material.emission_box_extents = Vector3(.012, .13, .008)
			particle.process_material.direction = Vector3.UP
			particle.process_material.spread = 9.
			particle.process_material.initial_velocity_min = .38
			particle.process_material.initial_velocity_max = .62
			particle.process_material.radial_velocity_min = .01
			particle.process_material.radial_velocity_max = .025
			particle.process_material.angle_min = -15.
			particle.process_material.angle_max = 15.
			particle.process_material.scale_min = .11
			particle.process_material.scale_max = .18
			if variant_id == "fire.ember_sheath":
				particle.amount = maxi(16, particle.amount / 2)
				particle.lifetime = .38
		if particle.name == "sparks":
			particle.amount = 4
			particle.process_material.scale_max = .12
	if not motion_wake_enabled:
		_retire_visible()
		return
	trail = GPUParticles3D.new()
	trail.layers = 1 << 19
	trail.amount = 8
	trail.lifetime = 8.
	trail.explosiveness = 1.
	trail.fixed_fps = 60
	trail.local_coords = false
	trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	trail.visibility_aabb = AABB(Vector3(-6, -3, -6), Vector3(12, 9, 12))
	process_material = VfxPackageIO_5261bc001c.resource("res://assets/vfx/sources/449b49f72c7d6b4066c7/trail_process.tres").duplicate(false)
	trail.process_material = process_material
	trail.draw_pass_1 = VfxPackageIO_5261bc001c.resource("res://assets/vfx/sources/df68cdb26cd15dac0a95/trail_mesh.tres").duplicate(false)
	trail.draw_pass_1.material = trail.draw_pass_1.material.duplicate(false)
	add_child(trail)
	_retire_visible()

func set_weapon_binding(value: Dictionary) -> void:
	binding = value

func set_sheet_pose(value: Dictionary) -> void:
	pose = value

func _retire_visible() -> void:
	pose_admitted = false
	flames.hide()
	if is_instance_valid(trail):
		trail.hide()
	for particle in flames.get_children():
		particle.emitting = false

func sample(seconds: float) -> void:
	var visible: bool = binding.get("present", false) and binding.get("observed", false) \
		and binding.get("equipped", false) and not binding.get("suppressed", true)
	if not visible or pose.get("item_uuid") != binding.get("item_uuid") \
		or pose.get("holder_uuid") != binding.get("holder_uuid") or not pose.get("visible_frame", false):
		_retire_visible()
		return
	var near: Vector3 = pose.near
	var far: Vector3 = pose.far
	var axis := far - near
	var length_cells := axis.length()
	if length_cells < .015:
		_retire_visible()
		return
	axis /= length_cells
	var side := axis.cross(pose.normal).normalized()
	if side.length_squared() < .5:
		_retire_visible()
		return
	var forward := side.cross(axis).normalized()
	flames.global_transform = Transform3D(Basis(side, axis, forward).scaled(Vector3.ONE * length_cells / .568127), near)
	axial_material.set_shader_parameter("blade_axis_world", axis)
	swing_active = pose.get("swing_active", false)
	if is_instance_valid(trail):
		var clip := str(pose.frame_key[1])
		var safe_trail: bool = motion_wake_enabled and swing_active and int(pose.raw_colour_pixels) >= 16
		if pose.frame_key != previous_pose_key:
			trail_from_near = trail_near
			trail_from_far = trail_far
			pose_changed_seconds = seconds
			previous_pose_key = pose.frame_key.duplicate()
		var source_row := int(pose.frame_key[2])
		if clip != previous_clip or source_row != previous_source_row or (safe_trail and not trail_was_active):
			trail_from_near = near
			trail_from_far = far
			trail.restart()
		previous_clip = clip
		previous_source_row = source_row
		trail_was_active = safe_trail
		# Smooth only the optical trail emitter between the existing sprite poses.
		# The equipped blade, material and attached fire retain their actual frame.
		var weight := smoothstep(0., .045, seconds - pose_changed_seconds)
		trail_near = trail_from_near.lerp(near, weight)
		var previous_axis := trail_from_far - trail_from_near
		var direction := axis
		if previous_axis.length_squared() > .0001:
			direction = previous_axis.normalized().slerp(axis, weight).normalized()
		trail_far = trail_near + direction * lerpf(previous_axis.length(), length_cells, weight)
		var trail_length := trail_near.distance_to(trail_far)
		var trail_side := direction.cross(pose.normal).normalized()
		var trail_forward := trail_side.cross(direction).normalized()
		trail.global_transform = Transform3D(Basis(trail_side * .02, direction * trail_length * .40, trail_forward * .02), trail_near.lerp(trail_far, .6))
		process_material.set_shader_parameter("weapon_swing", safe_trail)
	var running := seconds > previous_seconds
	if seconds < previous_seconds:
		for particle in flames.get_children():
			particle.restart()
		if is_instance_valid(trail):
			trail.restart()
	for particle in flames.get_children():
		particle.emitting = true
		particle.speed_scale = 1. if running else 0.
	if is_instance_valid(trail):
		trail.emitting = motion_wake_enabled
		trail.speed_scale = 1. if running and motion_wake_enabled else 0.
		trail.visible = motion_wake_enabled and swing_active and int(pose.raw_colour_pixels) >= 16
	previous_seconds = seconds
	flames.show()
	pose_admitted = true

func clear() -> void:
	binding = {}
	pose = {}
	_retire_visible()

func capture_observation() -> Dictionary:
	return {"item_uuid": binding.get("item_uuid", ""), "admitted": pose_admitted,
		"swing": swing_active, "pose": pose,
		"motion_wake_enabled": motion_wake_enabled, "flow": "explicit_hilt_to_tip",
		"variant_id": variant_id, "ready_cost": ready_cost, "offline_native_scene": prepared_scene != null,
		"fit": "explicit_frame_base_tip_pixels_with_endpoint_depth_references; hidden_blade_unknown",
		"production_input_qualified": false, "source_mesh_replacement": false}

const VfxPackageIO_5261bc001c = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
