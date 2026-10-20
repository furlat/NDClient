extends "res://assets/vfx/sources/68c612e2b1c79af74401/curse_rings.gd"
const PreparedRestore = preload("res://assets/vfx/extensions/continuation42-20261020/sources/35243558c7ef77ec849b/restore.gd")
var source_call_fit: RefCounted
var current_call_fit_valid := false
var current_call_fit_surface: Dictionary = {}
var current_call_fit_inverse := Transform3D.IDENTITY
var current_call_body_scale := 1.0


static func preparation_resources(input: Dictionary) -> Array:
	return [input.prepared_recipient_bank]


static func make_component(input: Dictionary) -> Node3D:
	return PreparedRestore.make("res://assets/vfx/extensions/continuation42-20261020/sources/bef2dcdac4bad7c9cd39/rings.gd",input)


func _ready() -> void:
	PreparedRestore.start_native(self)


func source_bindings() -> Dictionary:
	return PreparedRestore.bindings(self)


func has_verified_stable_paths() -> bool:
	return PreparedRestore.stable_paths(self)


func sample(seconds: float) -> void:
	current_call_fit_valid = false
	super.sample(seconds)
	current_call_fit_valid = false
	current_call_fit_surface = {}


func sample_analytical_tick(desired_tick: int) -> bool:
	tick = desired_tick - 1
	advance_lifecycle(1.0 / float(parameters.simulation_hz))
	return tick == desired_tick


func _place_rings(age: float) -> void:
	var body_scale := 1.0
	if settings.get("native_curse_finish",false):
		if receiving_surface.is_empty():
			for fold in folds:
				fold.hide()
			return
		var inverse := subject.global_transform.affine_inverse()
		if not current_call_fit_valid or not is_same(current_call_fit_surface,receiving_surface) or current_call_fit_inverse != inverse:
			var top := -INF
			if source_call_fit != null:
				top = source_call_fit.top(receiving_surface,inverse)
			else:
				for point in receiving_surface.points:
					top = maxf(top,(inverse * point.position).y)
			current_call_body_scale = top / float(settings.headTop)
			current_call_fit_inverse = inverse
			current_call_fit_surface = receiving_surface
			current_call_fit_valid = true
		body_scale = current_call_body_scale
	var release: bool = settings.curseMode == "release"
	for index in folds.size():
		var phase: float = age * TAU / 2.0 + float(index) * TAU / 3.0
		var radius_scale: float = 1.0 + .016 * sin(phase)
		if release:
			radius_scale *= 1.0 - .22 * smoothstep(.08,1.0,age)
		elif age < 1.0:
			radius_scale *= lerpf(1.40,1.0,smoothstep(.05,.75,age))
		folds[index].show()
		folds[index].position.y = (.65 + float(index) * .23) * body_scale
		folds[index].scale = Vector3.ONE * radius_scale * body_scale
