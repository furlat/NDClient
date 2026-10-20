extends "res://assets/vfx/sources/fa9dad58889076b2bc78/curse_application.gd"
const PreparedRestore = preload("res://assets/vfx/extensions/continuation42-20261020/sources/35243558c7ef77ec849b/restore.gd")
var source_call_fit: RefCounted


static func preparation_resources(input: Dictionary) -> Array:
	return [input.prepared_recipient_bank]


static func make_component(input: Dictionary) -> Node3D:
	return PreparedRestore.make("res://assets/vfx/extensions/continuation42-20261020/sources/4abcde8e3ba2b6a1dc85/application.gd",input)


func _ready() -> void:
	PreparedRestore.start_native(self)


func source_bindings() -> Dictionary:
	return PreparedRestore.bindings(self)


func has_verified_stable_paths() -> bool:
	return PreparedRestore.stable_paths(self)


func sample_analytical_tick(desired_tick: int) -> bool:
	# Audited original lifecycle writes final state only; native particles and
	# AnimationPlayers remain owned by their actual outer native sampler.
	assert(settings.curseMode == "touch" and folds.is_empty() and seal == null,
		"Tilted application folds retain every original native scale/rotation setter")
	tick = desired_tick - 1
	advance_lifecycle(1.0 / float(parameters.simulation_hz))
	return tick == desired_tick


func update_geometry() -> void:
	if not settings.get("native_curse_finish",false):
		return
	if receiving_surface.is_empty():
		subject.hide()
		return
	# Exactly Node3D.to_local's transform, invariant throughout this loop.
	var inverse := global_transform.affine_inverse()
	var top := -INF
	if source_call_fit != null:
		top = source_call_fit.top(receiving_surface,inverse)
	else:
		for point in receiving_surface.points:
			top = maxf(top,(inverse * point.position).y)
	var reference_top := float(settings.receiving_reference_top_cells)
	assert(reference_top > 0.0,"Curse application requires its original proxy height")
	subject.scale = Vector3.ONE * top / reference_top
	subject.show()
