extends "res://assets/vfx/sources/0738ff2d24aa41b1b963/native_review_composition.gd"
## Same original hand/cast/cancellation controllers, with explicit native bindings.
var source_bank: Resource
var prepared_geometry: Array=[]
var prepared_materials: Array=[]
var prepared_players: Array=[]
var prepared_lights: Array=[]
var prepared_mask:=0

static func preparation_resources(input: Dictionary) -> Array:
	return [String(input.skeletal_sequence_bank)]

static func make_component(input: Dictionary) -> Node3D:
	var bank: Resource=VfxPackageIO_d4e1dbdbf1.resource(input.skeletal_sequence_bank)
	return bank.restore(input)

func source_bindings() -> Dictionary:
	return {"geometry":prepared_geometry,"materials":prepared_materials,"players":prepared_players,"lights":prepared_lights,
		"static_material_topology":true,"static_geometry_layers":true,"prepared_source_layer_mask":prepared_mask}

func prepare_source_layer_mask(mask: int) -> void:
	assert(not is_inside_tree() and mask>0)
	for draw in prepared_geometry:
		if draw.layers!=0 and draw.layers!=mask:draw.layers=mask
	prepared_mask=mask

func has_verified_stable_paths() -> bool:
	return source_bank.verified_stable_paths

func refresh_live_inputs(age: float) -> void:
	# Every actual hand tick stays144Hz; reapplying this held age moves/aims from
	# live input without advancing animation, restarting particles or GPU delta.
	sample(age)

const VfxPackageIO_d4e1dbdbf1 = preload("res://assets/vfx/extensions/continuation42-20261020/scoped_resource_io.gd")
