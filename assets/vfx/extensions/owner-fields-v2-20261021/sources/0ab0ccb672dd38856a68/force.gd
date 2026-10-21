extends Node3D
## Actual passive blue wall; live ripple/contact response is a separate source.
const WallInput = preload("res://assets/vfx/extensions/owner-fields-v2-20261021/sources/7a3794083f3e06b956ad/input.gd")
const ZoneInput = preload("res://assets/vfx/extensions/owner-fields-v2-20261021/sources/bbfe0c8c2a4fd1b29e8d/input.gd")
const Readiness = preload("res://assets/vfx/extensions/production-review-20261020/sources/7dd1897cdd5ee8a903b9/source_readiness.gd")
const HEIGHT_UNIT := sqrt(2.0 / 3.0)
var bank: Resource
var construction := {}
var current := {}
var state := {}
var state_error := ""
var anchor_world: Variant
var mask: ImageTexture
var geometry: Array[GeometryInstance3D] = []
var materials: Array[ShaderMaterial] = []


static func preparation_resources(input: Dictionary) -> Array:
	return [input.force_owner_bank, "res://assets/vfx/extensions/owner-fields-v2-20261021/sources/ff1fd545d18e174740a0/owner_release_force_panels.gd", "res://assets/vfx/extensions/owner-fields-v2-20261021/sources/90f4808175f158a9753d/owner_release_force_dome.gd"]


static func make_component(input: Dictionary) -> Node3D:
	var prepared: Resource = Readiness.resources.get(str(input.get("force_owner_bank", "")))
	if prepared == null or not prepared.interface_ready:
		return null
	var actual := WallInput.construction(input, prepared.dome)
	if not actual.error.is_empty():
		return null
	var node: Node3D = VfxPackageIO_0ab0ccb672.resource("res://assets/vfx/extensions/owner-fields-v2-20261021/sources/0ab0ccb672dd38856a68/force.gd").new()
	node.bank = prepared
	node.construction = actual
	node.mask = ImageTexture.create_from_image(Image.create_empty(1, 1, false, Image.FORMAT_R8))
	for index: int in actual.modules.size():
		var draw := MeshInstance3D.new()
		draw.name = "ActualSection%02d" % index
		draw.mesh = prepared.mesh
		var material: ShaderMaterial = prepared.private_material()
		material.set_shader_parameter("owner_cells", node.mask)
		draw.material_override = material
		node.add_child(draw)
		node.geometry.append(draw)
		node.materials.append(material)
		draw.hide()
	node.hide()
	return node


func prepare_source_layer_mask(value: int) -> void:
	for draw: GeometryInstance3D in geometry:
		draw.layers = value


func source_bindings() -> Dictionary:
	return {"geometry": geometry, "materials": materials, "players": [], "lights": [],
		"static_material_topology": true, "static_geometry_layers": true}


func set_zone_geometry(value: Dictionary) -> bool:
	var actual := WallInput.observation(value, construction, bank.dome)
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
		state_error = "Actual current-cell texture span exceeds4096 texels"
		current = {}
		hide()
		return false
	var image := Image.create_empty(size.x, size.y, false, Image.FORMAT_R8)
	for cell: Vector2i in actual.cells:
		var pixel := cell - minimum
		image.set_pixel(pixel.x, pixel.y, Color.WHITE)
	mask.set_image(image)
	for index: int in geometry.size():
		var material := materials[index]
		material.set_shader_parameter("owner_mask_origin", minimum)
		var cuts := PackedVector4Array()
		if actual.sections.has(index):
			for cut: Dictionary in actual.sections[index].get("removed_sections", []):
				cuts.append(Vector4(float(cut.minimum_position[0]) - construction.anchor.x - .5,
					(float(cut.base_height_steps) - float(construction.area.base_height_steps)) * HEIGHT_UNIT,
					float(cut.minimum_position[1]) - construction.anchor.y - .5, 0.0))
		material.set_shader_parameter("owner_cut_count", cuts.size())
		cuts.resize(WallInput.MAX_CUTS)
		material.set_shader_parameter("owner_cuts", cuts)
	current = actual
	return true


func set_owner_state(value: Dictionary) -> bool:
	state_error = ZoneInput.owner_state(value, construction.owner)
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
	var tick := roundi(float(state.owner_age_seconds) * 144.0)
	var age := float(tick) / 144.0
	for index: int in geometry.size():
		var draw: MeshInstance3D = geometry[index]
		draw.visible = current.sections.has(index)
		if not draw.visible:
			continue
		var module: Dictionary = construction.modules[index]
		var basis := Basis.IDENTITY
		var center: Vector3 = anchor_world + Vector3(module.center.x, 0.0, module.center.y)
		if bank.dome:
			var radius := float(module.radius_feet) / 5.0
			basis = Basis.IDENTITY.scaled(Vector3(radius / bank.source_dimensions.x,
				radius * HEIGHT_UNIT / bank.source_dimensions.y, radius / bank.source_dimensions.x))
		else:
			var along: Vector2 = (module.end - module.start).normalized()
			var length: float = module.start.distance_to(module.end)
			basis = Basis(Vector3(along.x, 0.0, along.y) * (length / bank.source_dimensions.x),
				Vector3.UP * (float(construction.area.height_feet) * HEIGHT_UNIT / (5.0 * bank.source_dimensions.y)),
				Vector3(-along.y, 0.0, along.x))
			# The exact original panel plane is offset in native source Z.
			center -= basis.z * bank.source_dimensions.z
		draw.global_transform = Transform3D(basis, center)
		var material := materials[index]
		material.set_shader_parameter("factory_world_to_source", draw.global_transform.affine_inverse())
		material.set_shader_parameter("owner_world_anchor", anchor_world)
		material.set_shader_parameter("age", age)
		material.set_shader_parameter("vfx_clock", 0.0)
		material.set_shader_parameter("opacity", .94 + .06 * cos(TAU * float(tick % 576) / 576.0))
		material.set_shader_parameter("destroy_age", -1.0)


func capture_observation() -> Dictionary:
	return {"owner_uuid": construction.get("owner"), "source_age": state.get("owner_age_seconds"),
		"current_sections": current.get("sections", {}).size(), "visible": visible, "state_error": state_error,
		"review_contact_or_disintegration": false, "live_contact_response_qualified": false,
		"actual_native_blue_meshes": geometry.size(), "width_is_optical_plane": true}

const VfxPackageIO_0ab0ccb672 = preload("res://assets/vfx/extensions/owner-fields-v2-20261021/scoped_resource_io.gd")
