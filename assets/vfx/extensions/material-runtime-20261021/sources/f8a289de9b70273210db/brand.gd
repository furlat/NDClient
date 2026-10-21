extends "res://assets/vfx/extensions/material-runtime-20261021/sources/093070ef89fd28fd8e6e/brand.gd"
## Original native geometry/lifecycle; mutable display fields belong to each draw.
const InstanceRestore = preload("res://assets/vfx/extensions/material-runtime-20261021/sources/4ded3a9ddf1737b5bf17/restore.gd")
const Display = preload("res://assets/vfx/extensions/material-runtime-20261021/sources/f0ffda9c0b87b3d8975f/display.gd")
var display := Display.new()


static func preparation_resources(input: Dictionary) -> Array:
	return [input.prepared_recipient_bank]


static func make_component(input: Dictionary) -> Node3D:
	return InstanceRestore.make("res://assets/vfx/extensions/material-runtime-20261021/sources/f8a289de9b70273210db/brand.gd", input)


func source_bindings() -> Dictionary:
	return InstanceRestore.bindings(self)


func advance_lifecycle(delta: float) -> void:
	super.advance_lifecycle(delta)
	var age := float(tick) / float(parameters.simulation_hz)
	display.lifecycle(age, Display.envelope_at(age, settings.curseMode))


func _place_mark(age: float) -> void:
	if seal:
		var phase = age * TAU / 2.
		var departure = .14 * smoothstep(.10, .85, age) if settings.curseMode == "release" else 0.
		seal.position = Vector3(
			.025 * sin(phase), head_mark_height + .015 * cos(phase) + departure, .025 * cos(phase)
		)
		for i in range(curse_wisps.size()):
			var life = fposmod(age + float(i), 2.) / 2.
			var puff = curse_wisps[i]
			var q = int(settings.cameraQuarter)
			var sx = [1., 1., -1., -1.][q]
			var sz = [1., -1., -1., 1.][q]
			var camera_right = Vector3(sz * .70710678, 0., -sx * .70710678)
			var camera_toward = Vector3(sx * .70710678, 0., sz * .70710678)
			if settings.get("native_curse_finish", false):
				var camera: Camera3D = get_viewport().get_camera_3d()
				if camera != null:
					camera_right = subject.global_basis.inverse() * camera.global_basis.x
					camera_toward = subject.global_basis.inverse() * Vector3(camera.global_basis.z.x, 0., camera.global_basis.z.z).normalized()
			puff.position = (
				camera_right * (-.40 if i == 0 else .40)
				- camera_toward * .12
				+ Vector3(0., head_mark_height - .04 + life * .22 + departure, 0.)
			)
			puff.scale = Vector3(
				lerpf(.045, .07, life), lerpf(.065, .11, life), lerpf(.04, .06, life)
			)
			puff.rotation = Vector3(.2 * float(i), .4 * float(i) + life * .2, 0.)
			puff.set_instance_shader_parameter("puff_life", life)

