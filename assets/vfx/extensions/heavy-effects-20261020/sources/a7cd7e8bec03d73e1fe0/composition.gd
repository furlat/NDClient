extends "res://assets/vfx/extensions/heavy-effects-20261020/sources/0738ff2d24aa41b1b963/native_review_composition.gd"
## Original source controller sample order, animation and live endpoint rules.
var prepared_bank: Resource
var prepared_geometry: Array = []
var prepared_materials: Array = []
var prepared_players: Array = []
var prepared_lights: Array = []
var prepared_mask := 0


static func preparation_resources(input: Dictionary) -> Array:
	return [input.prepared_native_composition_bank]


static func make_component(input: Dictionary) -> Node3D:
	var bank: Resource = VfxPackageIO_a7cd7e8bec.resource(input.prepared_native_composition_bank)
	return bank.restore(input)


func _ready() -> void:
	prepared_bank.apply_consumer_callback_policy(self)


func source_bindings() -> Dictionary:
	return {"geometry": prepared_geometry, "materials": prepared_materials,
		"players": prepared_players, "lights": prepared_lights,
		"static_material_topology": true, "static_geometry_layers": true,
		"prepared_source_layer_mask": prepared_mask}


func prepare_source_layer_mask(mask: int) -> void:
	assert(not is_inside_tree() and mask > 0)
	for draw: GeometryInstance3D in prepared_geometry:
		if draw.layers != 0 and draw.layers != mask:
			draw.layers = mask
	prepared_mask = mask


func has_verified_stable_paths() -> bool:
	return prepared_bank.verified_stable_paths


func refresh_live_inputs(age: float) -> void:
	sample(age)

const VfxPackageIO_a7cd7e8bec = preload("res://assets/vfx/extensions/heavy-effects-20261020/scoped_resource_io.gd")
