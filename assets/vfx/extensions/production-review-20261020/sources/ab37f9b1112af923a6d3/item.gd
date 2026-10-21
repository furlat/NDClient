extends "res://assets/vfx/extensions/production-review-20261020/sources/63efbe77094fc90312ab/item_flame.gd"
## Actual item ownership/facts, native source age and source finish stay inherited.
var prepared_bank: Resource
var prepared_geometry: Array = []
var prepared_materials: Array = []
var prepared_players: Array = []
var prepared_lights: Array = []
var prepared_mask := 0
var birth_commands_applied := false


static func preparation_resources(input: Dictionary) -> Array:
	return [input.prepared_native_composition_bank]


static func make_component(input: Dictionary) -> Node3D:
	var bank: Resource = VfxPackageIO_ab37f9b111.resource(input.prepared_native_composition_bank)
	return bank.restore(input)


func sample(age: float) -> void:
	if not birth_commands_applied:
		assert(is_inside_tree(), "Original item source seed command boundary is after native tree admission")
		prepared_bank.replay_native_birth(self)
		birth_commands_applied = true
	super.sample(age)


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

const VfxPackageIO_ab37f9b111 = preload("res://assets/vfx/extensions/production-review-20261020/scoped_resource_io.gd")
