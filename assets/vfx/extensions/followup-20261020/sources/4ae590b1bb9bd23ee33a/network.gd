extends "res://assets/vfx/extensions/followup-20261020/sources/c43d754ae69cc0329592/electric_network.gd"
## Original live endpoint/body/branch equations with offline native construction.
const Profile = preload("res://assets/vfx/sources/5e6062cb1efe781a65b7/construction_profile.gd")
var bank: Resource
var prepared_geometry: Array = []
var prepared_materials: Array = []
var prepared_layer_mask := 0

static func preparation_resources(input: Dictionary) -> Array:
	return [String(input.electric_bank)]

static func make_component(input: Dictionary) -> Node3D:
	Profile.begin("electric_instance_new")
	var instance: Node3D = VfxPackageIO_4ae590b1bb.resource("res://assets/vfx/extensions/followup-20261020/sources/4ae590b1bb9bd23ee33a/network.gd").new()
	Profile.end("electric_instance_new")
	instance.bank = VfxPackageIO_4ae590b1bb.resource(String(input.electric_bank))
	assert(instance.bank != null and instance.bank.program != null, "Exact prepared electric bank required")
	instance.settings = instance.bank.settings.duplicate(true)
	instance.banks = instance.bank.shapes.duplicate()
	var made: Dictionary = instance.bank.program.instantiate(instance, instance.bank.operands, Profile.current != null)
	instance.prepared_geometry = made.geometry
	instance.prepared_materials = made.all_materials
	instance.materials.assign(made.source_materials)
	instance.ribbons = made.ribbons
	for index in instance.ribbons.size():
		instance.ribbons[index].edge = instance.settings.edges[index]
	instance.contact_draws = made.contact_draws
	instance.contact_arcs = made.contact_arcs
	instance.hand_arcs = made.hand_arcs
	instance.body_draws = made.body_draws
	for index in made.body_draws.size(): instance.body_data.append({})
	return instance

func prepare_source_layer_mask(layer_mask: int) -> void:
	assert(not is_inside_tree() and layer_mask > 0)
	for draw: GeometryInstance3D in prepared_geometry:
		if draw.layers != 0 and draw.layers != layer_mask: draw.layers = layer_mask
	prepared_layer_mask = layer_mask

func has_verified_stable_paths() -> bool:
	return bank.stable_paths_verified

func source_bindings() -> Dictionary:
	return {"geometry": prepared_geometry, "materials": prepared_materials, "lights": [],
		"static_material_topology": true, "prepared_source_layer_mask": prepared_layer_mask}

func refresh_live_inputs(seconds: float) -> void:
	# Pure shader/placement source: refresh at a held age without advancing any
	# native simulation, contact schedule or clock beyond that same source age.
	sample(seconds)

func _prepare_body_data(index: int, surface: Dictionary, points: Array, key: Array) -> void:
	var origin: Vector3 = surface.get("origin", endpoints[index].point)
	var image := body_image(points, origin)
	var texture: ImageTexture = body_data[index].get("texture")
	if texture != null and Vector2i(texture.get_size()) == image.get_size(): texture.update(image)
	else: texture = ImageTexture.create_from_image(image)
	body_data[index] = {"texture": texture, "count": points.size(), "key": key.duplicate(true)}
	body_uploads += 1

static func body_image(points: Array, origin: Vector3) -> Image:
	assert(not points.is_empty())
	var width := mini(256, points.size())
	var rows := ceili(float(points.size()) / width)
	var values := PackedVector4Array()
	values.resize(width * rows * 2)
	for number in points.size():
		var point: Vector3 = points[number].position - origin
		var normal: Vector3 = points[number].normal
		var row := number / width
		var column := number % width
		values[row * width * 2 + column] = Vector4(point.x, point.y, point.z, 1)
		values[(row * 2 + 1) * width + column] = Vector4(normal.x, normal.y, normal.z, 1)
	return Image.create_from_data(width, rows * 2, false, Image.FORMAT_RGBAF, values.to_byte_array())

const VfxPackageIO_4ae590b1bb = preload("res://assets/vfx/extensions/followup-20261020/scoped_resource_io.gd")
