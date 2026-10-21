extends "res://assets/vfx/extensions/material-runtime-20261021/sources/610b55b9ffee9e183b02/assembly.gd"
## Same source controller and fit, with exact native process-unit state per owner.
var unit_operators: Array[RefCounted] = []
var unit_operators_collected := false
var last_unit_scale := 1.0
const NativeProfile = preload("res://assets/vfx/sources/5e6062cb1efe781a65b7/construction_profile.gd")
const OrderedBodyFit = preload("res://assets/vfx/extensions/material-runtime-20261021/sources/4f12334800c91b085143/body_fit.gd")


func _init() -> void:
	source_call_fit = OrderedBodyFit.new()


static func preparation_resources(input: Dictionary) -> Array:
	var paths: Array = []
	for entry: Dictionary in input.entries:
		for specification: Dictionary in entry.composition.components:
			var path: String = specification.input.prepared_recipient_bank
			if path not in paths:
				paths.append(path)
	return paths


static func make_component(input: Dictionary) -> Node3D:
	var node: Node3D = VfxPackageIO_4a236db918.resource("res://assets/vfx/extensions/material-runtime-20261021/sources/4a236db91859c712a27e/assembly.gd").new()
	node.selections = input.entries.duplicate(true)
	node.opacity_control = input.get("opacity_control", false)
	return node


func _collect_units() -> void:
	if unit_operators_collected:
		return
	for entry: Dictionary in entries:
		for component: Node3D in entry.composition.components.values():
			var operators: Array = component.get_meta("prepared_curse_native_units")
			for operator: RefCounted in operators:
				unit_operators.append(operator)
	unit_operators_collected = true


func sample(seconds: float) -> void:
	if not prepared:
		_prepare()
	NativeProfile.begin("curse_native_unit_collection")
	_collect_units()
	NativeProfile.end("curse_native_unit_collection")
	var actual_scale: float = global_basis.get_scale().x
	assert(is_finite(actual_scale) and actual_scale > 0.0)
	NativeProfile.begin("curse_native_unit_advance")
	if actual_scale != 1.0 or last_unit_scale != 1.0:
		for operator: RefCounted in unit_operators:
			operator.advance(actual_scale)
	last_unit_scale = actual_scale
	NativeProfile.end("curse_native_unit_advance")
	NativeProfile.begin("curse_original_sample")
	super.sample(seconds)
	NativeProfile.end("curse_original_sample")


func refresh_live_inputs(seconds: float) -> void:
	# The original sampler's held-age refresh does not restore/apply native
	# unit fields. Fit the new measured body without advancing that history.
	super.sample(seconds)

const VfxPackageIO_4a236db918 = preload("res://assets/vfx/extensions/material-runtime-20261021/scoped_resource_io.gd")
