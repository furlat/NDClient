extends Node3D
## Current disclosed line, original native wind artwork and private owner clock.
const ZoneInput = preload("res://assets/vfx/extensions/owner-fields-v2-20261021/sources/bbfe0c8c2a4fd1b29e8d/input.gd")
const WindInput = preload("res://assets/vfx/extensions/owner-fields-v2-20261021/sources/f1c5e22154ba7e49f2cf/input.gd")
const Leaf = preload("res://assets/vfx/extensions/owner-fields-v2-20261021/sources/9fb1dbf8703cc15a6b8c/leaf.gd")
var owner_uuid := ""
var source_scale := 0.0
var source: Node3D
var geometry: Array[GeometryInstance3D] = []
var materials: Array[Material] = []
var state := {}
var current := {}
var state_error := ""
var anchor_world: Variant
var mask: ImageTexture


static func preparation_resources(input: Dictionary) -> Array:
	return [input.source_input.prepared_recipient_bank, "res://assets/vfx/extensions/owner-fields-v2-20261021/sources/8bc056cc059b0e916424/owner_release_wind.gd"]


static func make_component(input: Dictionary) -> Node3D:
	if not input.get("owner_uuid") is String or input.owner_uuid.is_empty():
		return null
	var scale_value := float(input.get("source_world_scale", 0.0))
	if not is_finite(scale_value) or scale_value <= 0.0:
		return null
	var node: Node3D = VfxPackageIO_7ab71b46ac.resource("res://assets/vfx/extensions/owner-fields-v2-20261021/sources/7ab71b46ac25c3d72d74/wind.gd").new()
	node.owner_uuid = input.owner_uuid
	node.source_scale = scale_value
	node.source = Leaf.make_component(input.source_input)
	if node.source == null:
		node.free()
		return null
	node.add_child(node.source)
	node.mask = ImageTexture.create_from_image(Image.create_empty(1, 1, false, Image.FORMAT_R8))
	var bindings: Dictionary = node.source.source_bindings()
	node.geometry.assign(bindings.geometry)
	node.materials.assign(bindings.materials)
	for material: ShaderMaterial in node.materials:
		material.set_shader_parameter("owner_cells", node.mask)
	node.hide()
	return node


func prepare_source_layer_mask(mask_value: int) -> void:
	for draw: GeometryInstance3D in geometry:
		if draw.layers != 0:
			draw.layers = mask_value


func source_bindings() -> Dictionary:
	return {"geometry": geometry, "materials": materials, "players": [], "lights": [],
		"static_material_topology": true, "static_geometry_layers": true}


func set_zone_geometry(value: Dictionary) -> bool:
	var actual := WindInput.geometry(value, owner_uuid)
	state_error = actual.error
	if not state_error.is_empty():
		current = {}
		hide()
		return false
	var minimum := Vector2i.ZERO
	var maximum := Vector2i.ZERO
	if not actual.cells.is_empty():
		minimum = actual.cells[0]
		maximum = minimum
		for cell: Vector2i in actual.cells:
			minimum = minimum.min(cell)
			maximum = maximum.max(cell)
	var size := maximum - minimum + Vector2i.ONE
	if size.x > 4096 or size.y > 4096:
		state_error = "Actual occupancy texture span exceeds4096 texels"
		current = {}
		hide()
		return false
	var image := Image.create_empty(size.x, size.y, false, Image.FORMAT_R8)
	for cell: Vector2i in actual.cells:
		var pixel := cell - minimum
		image.set_pixel(pixel.x, pixel.y, Color.WHITE)
	mask.set_image(image)
	for material: ShaderMaterial in materials:
		material.set_shader_parameter("owner_mask_origin", minimum)
	current = actual
	return true


func set_owner_state(value: Dictionary) -> bool:
	state_error = ZoneInput.owner_state(value, owner_uuid)
	state = value.duplicate(true) if state_error.is_empty() else {}
	if not ZoneInput.admitted(state):
		hide()
	return state_error.is_empty()


func set_targets(value: Array) -> void:
	anchor_world = ZoneInput.point(value)
	if anchor_world == null:
		hide()


func set_live_endpoints(value: Array) -> void:
	set_targets(value)


func refresh_live_inputs(seconds: float) -> void:
	sample(seconds)


func sample(seconds: float) -> void:
	visible = is_finite(seconds) and seconds >= 0.0 and anchor_world != null and not current.is_empty() and not current.cells.is_empty() and ZoneInput.admitted(state)
	if not visible:
		return
	source.global_transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * source_scale), anchor_world)
	source.direction = Vector3(current.direction.x, 0.0, current.direction.y).normalized()
	source.across = Vector3(-source.direction.z, 0.0, source.direction.x)
	# A retained spatial line starts at its disclosed owner anchor. This is a
	# source origin, never a proxy for an unobserved historical casting hand.
	source.hand = Vector3.ZERO
	source.owner_reach = float(current.length_cells) / source_scale
	source.head.rotation.y = atan2(-source.direction.x, -source.direction.z)
	source.body.rotation.y = source.head.rotation.y
	var end: Vector3 = source.direction * source.owner_reach
	var lower := Vector3.ZERO.min(end) - Vector3.ONE * 8.0
	var size := end.abs() + Vector3.ONE * 16.0
	for strip: MeshInstance3D in source.strands:
		strip.custom_aabb = AABB(lower, size)
	source.sample(float(state.owner_age_seconds))
	var inverse := source.global_transform.affine_inverse()
	for material: ShaderMaterial in materials:
		material.set_shader_parameter("factory_world_to_source", inverse)
		material.set_shader_parameter("owner_world_anchor", anchor_world)


func capture_observation() -> Dictionary:
	return {"owner_uuid": owner_uuid, "state_error": state_error,
		"owner_age": state.get("owner_age_seconds"), "actual_cells": current.get("cells", []),
		"actual_direction": current.get("direction"), "actual_length_cells": current.get("length_cells"),
		"source_scale": source_scale, "source_hand_input_required": false,
		"finite_review_expiry": false, "visible": visible}

const VfxPackageIO_7ab71b46ac = preload("res://assets/vfx/extensions/owner-fields-v2-20261021/scoped_resource_io.gd")
