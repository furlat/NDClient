extends "res://assets/vfx/sources/252cd8e8f22d0dd016b3/curse_brand.gd"
const PreparedRestore = preload("res://assets/vfx/extensions/continuation42-20261020/sources/35243558c7ef77ec849b/restore.gd")
var source_call_fit: RefCounted


static func preparation_resources(input: Dictionary) -> Array:
	return [input.prepared_recipient_bank]


static func make_component(input: Dictionary) -> Node3D:
	return PreparedRestore.make("res://assets/vfx/extensions/continuation42-20261020/sources/093070ef89fd28fd8e6e/brand.gd",input)


func _ready() -> void:
	PreparedRestore.start_native(self)


func source_bindings() -> Dictionary:
	return PreparedRestore.bindings(self)


func has_verified_stable_paths() -> bool:
	return PreparedRestore.stable_paths(self)


func sample_analytical_tick(desired_tick: int) -> bool:
	tick = desired_tick - 1
	advance_lifecycle(1.0 / float(parameters.simulation_hz))
	return tick == desired_tick


func update_geometry() -> void:
	if not settings.get("native_curse_finish",false) or not is_instance_valid(seal):
		return
	if receiving_surface.is_empty():
		seal.hide()
		for puff in curse_wisps:
			puff.hide()
		return
	var inverse := subject.global_transform.affine_inverse()
	var top := -INF
	if source_call_fit != null:
		top = source_call_fit.top(receiving_surface,inverse)
	else:
		for point in receiving_surface.points:
			top = maxf(top,(inverse * point.position).y)
	head_mark_height = top + .20 + .33
	seal.show()
	for puff in curse_wisps:
		puff.show()
	_place_mark(float(tick) / float(parameters.simulation_hz))
