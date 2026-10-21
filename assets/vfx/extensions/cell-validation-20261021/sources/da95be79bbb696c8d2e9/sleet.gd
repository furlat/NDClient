extends Node3D
## Original native rain/mist/ground source with current disclosed occupancy.
const ZoneInput = preload("res://assets/vfx/extensions/cell-validation-20261021/sources/bbfe0c8c2a4fd1b29e8d/input.gd")
const Leaf = preload("res://assets/vfx/extensions/cell-validation-20261021/sources/6332bac4f8afe417e20b/sleet_leaf.gd")
const CONTENT := "spatial_effect.spell.sleet_storm"
var owner_uuid := ""
var sources: Array[Node3D] = []
var geometry: Array[GeometryInstance3D] = []
var materials: Array[Material] = []
var state := {}
var current := {}
var state_error := ""
var anchor_world: Variant
var mask: ImageTexture


static func preparation_resources(input: Dictionary) -> Array:
	var result: Array = []
	for source: Dictionary in input.get("weather_sources", []):
		result.append(source.prepared_recipient_bank)
	result.append("res://assets/vfx/extensions/cell-validation-20261021/sources/466f2cf191ebaf6b135d/owner_release_sleet.gd")
	return result


static func make_component(input: Dictionary) -> Node3D:
	if str(input.get("owner_uuid", "")).is_empty() or input.get("weather_sources", []).size() != 2:
		return null
	var node: Node3D = VfxPackageIO_da95be79bb.resource("res://assets/vfx/extensions/cell-validation-20261021/sources/da95be79bbb696c8d2e9/sleet.gd").new()
	node.owner_uuid = input.owner_uuid
	node.mask = ImageTexture.create_from_image(Image.create_empty(1, 1, false, Image.FORMAT_R8))
	for index: int in 2:
		var source: Node3D = Leaf.make_component(input.weather_sources[index])
		source.name = "Rain" if index == 0 else "Ground"
		node.add_child(source)
		node.sources.append(source)
		var bindings: Dictionary = source.source_bindings()
		node.geometry.append_array(bindings.geometry)
		for material: ShaderMaterial in bindings.materials:
			material.set_shader_parameter("owner_cells", node.mask)
			if material not in node.materials:
				node.materials.append(material)
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
	var actual := ZoneInput.geometry(value, owner_uuid, CONTENT)
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
	# This is a private occupancy texture, not a second generated radius or
	# bounded cell-uniform array. The complete disclosed neighbor set is kept.
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
	var age := float(state.owner_age_seconds)
	for source: Node3D in sources:
		# Source units already describe the existing eight-cell weather field.
		# The actual anchor is supplied in current client world coordinates.
		source.global_transform = Transform3D(Basis.IDENTITY, anchor_world)
		source.sample(age)
		var inverse := source.global_transform.affine_inverse()
		for material: ShaderMaterial in source.get_meta("prepared_world_source_materials"):
			material.set_shader_parameter("factory_world_to_source", inverse)


func capture_observation() -> Dictionary:
	return {"owner_uuid": owner_uuid, "state_error": state_error, "source_age": state.get("owner_age_seconds"),
		"cells": current.get("cells", []), "native_rain_instances": 2400, "native_mist_cards": 9,
		"finite_review_expiry": false, "visible": visible, "mask_span_limit": 4096}

const VfxPackageIO_da95be79bb = preload("res://assets/vfx/extensions/cell-validation-20261021/scoped_resource_io.gd")
