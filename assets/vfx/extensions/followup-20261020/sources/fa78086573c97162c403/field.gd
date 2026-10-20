extends "res://assets/vfx/sources/08327bdb7a95631435c4/moonbeam.gd"
## Inherited source clocks, envelopes and arbitrary current field placement.
var bank: Resource
var prepared_geometry: Array=[]
var prepared_materials: Array=[]
var prepared_layer_mask:=0

static func preparation_resources(input: Dictionary) -> Array:
	return [String(input.moonbeam_bank)]

static func make_component(input: Dictionary) -> Node3D:
	var effect: Node3D=VfxPackageIO_fa78086573.resource("res://assets/vfx/extensions/followup-20261020/sources/fa78086573c97162c403/field.gd").new()
	effect.bank=VfxPackageIO_fa78086573.resource(input.moonbeam_bank)
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

const VfxPackageIO_fa78086573 = preload("res://assets/vfx/extensions/followup-20261020/scoped_resource_io.gd")
