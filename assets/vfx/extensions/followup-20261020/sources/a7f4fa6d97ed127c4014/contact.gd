extends "res://assets/vfx/sources/c9c6017fcf31a5168ab1/moonbeam_contact.gd"
## Same actual ordered point reductions/fit and original exposure envelope.
## No recipient geometry or owner clock is retained in the immutable bank.
var bank: Resource
var prepared_geometry: Array=[]
var prepared_materials: Array=[]
var prepared_layer_mask:=0

static func preparation_resources(input: Dictionary) -> Array:
	return [String(input.moonbeam_bank)]

static func make_component(input: Dictionary) -> Node3D:
	var effect: Node3D=VfxPackageIO_a7f4fa6d97.resource("res://assets/vfx/extensions/followup-20261020/sources/a7f4fa6d97ed127c4014/contact.gd").new()
	effect.bank=VfxPackageIO_a7f4fa6d97.resource(input.moonbeam_bank)
	effect.specification=effect.bank.specification.duplicate(true)
	return effect

func prepare() -> void:
	var restored: Dictionary=bank.restore(self)
	field=restored.field
	layers.assign(restored.layers)
	prepared_geometry=restored.geometry
	prepared_materials=restored.materials

func prepare_source_layer_mask(value: int) -> void:
	assert(not is_inside_tree() and value>0)
	if field==null:prepare()
	for draw in prepared_geometry:
		if draw.layers!=value:draw.layers=value
	prepared_layer_mask=value

func source_bindings() -> Dictionary:
	return {"geometry":prepared_geometry,"materials":prepared_materials,"lights":[],
		"static_material_topology":true,"prepared_source_layer_mask":prepared_layer_mask}

func has_verified_stable_paths() -> bool:
	return bank.stable_paths_verified

func refresh_live_inputs(age: float) -> void:
	sample(age)

const VfxPackageIO_a7f4fa6d97 = preload("res://assets/vfx/extensions/followup-20261020/scoped_resource_io.gd")
