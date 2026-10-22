extends "res://assets/vfx/extensions/spike-readiness-20261022/sources/21d9b70cf2bfd288b0ba/spike_growth_bark_mass.gd"
## Original source geometry and motion; explicit actual-owner continuation.
const Restore = preload("res://assets/vfx/extensions/spike-readiness-20261022/sources/6d7cfd14f2efee6263e2/restore.gd")


static func preparation_resources(input: Dictionary) -> Array:
	return [input.prepared_recipient_bank]


static func make_component(input: Dictionary) -> Node3D:
	var node: Node3D = Restore.make("res://assets/vfx/extensions/spike-readiness-20261022/sources/3f7c4d0944341cd9d43c/spike_leaf.gd", input)
	node.parameters.lifecycle_sampling = "analytical"
	return node


func _ready() -> void:
	Restore.start(self)


func source_bindings() -> Dictionary:
	return Restore.bindings(self)


func sample_analytical_tick(desired_tick: int) -> bool:
	tick = desired_tick - 1
	advance_lifecycle(1.0 / float(parameters.simulation_hz))
	return tick == desired_tick


func advance_lifecycle(_delta: float) -> void:
	if not is_instance_valid(subject):
		return
	tick += 1
	var age = float(tick) / float(parameters.simulation_hz)
	if settings.kind.ends_with("contact"):
		for i in range(roots.size()):
			var a = float(i) * 2.39996
			var speed = .3 + float(i % 3) * .13
			roots[i].position = Vector3(
				cos(a) * speed * age,
				maxf(0.0, .035 + age * 1.3 - age * age * 3.5),
				sin(a) * speed * age
			)
			roots[i].scale = Vector3.ONE * (1.0 - smoothstep(.25, .5, age))
		return
	for i in range(leaves.size()):
		var phase = float(i) * .57 + float(variant_index) * .13
		var a = (age - 1.0) * PI + phase
		var progress = fposmod((age - 1.0) * .5 + phase, 1.0)
		var envelope = (
			sin(progress * PI) * smoothstep(.05, .35, age)
		)
		leaves[i].position = Vector3(cos(a) * .38, .06 + progress * .4, sin(a) * .33)
		leaves[i].rotation = Vector3(sin(a) * .8, a * 2.0, cos(a) * .65)
		leaves[i].scale = Vector3.ONE * envelope
	var grow = smoothstep(.02, .92, age)
	var end = 1.0
	for i in range(roots.size()):
		var delay = float(i % 7) * .04
		var g = (
			smoothstep(.02 + delay, .72 + delay, age)
		)
		roots[i].scale = base_scales[i] * Vector3(1.0, maxf(.001, g), 1.0)
	for m in materials:
		m.set_shader_parameter("clock", age - 1.0)
		m.set_shader_parameter("opacity", end)
		if settings.kind == "grease":
			m.set_shader_parameter("grow", grow)
