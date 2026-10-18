extends RefCounted
## Absolute-time version of the already authored Bane sustain trajectories.
## The three brands, six original smoke meshes and six tears remain unchanged.


static func sample(subject: Node3D, seconds: float, height: float, source_scale: float) -> void:
	var elapsed := fposmod(seconds, 6.0)
	for index in 3:
		var angle: float = TAU * elapsed / 6.0 + [0.2, 2.35, 4.6][index]
		var radius: float = [1.03, 1.27, 1.12][index]
		var base_height: float = [-0.4, 0.08, 0.55][index]
		var glyph: MeshInstance3D = subject.get_node("OrbitBrand" + str(index))
		glyph.position = Vector3(cos(angle) * radius, base_height + .07 * sin(angle * 2.0), sin(angle) * radius)
		for puff_index in 2:
			var puff: MeshInstance3D = subject.get_node("CurseWisp" + str(index) + str(puff_index))
			var life := fposmod(elapsed + float(index) * .43 + float(puff_index), 2.0) / 2.0
			var birth_angle := angle - TAU * life * .65 / 6.0
			puff.position = Vector3(cos(birth_angle) * (radius + .23), base_height - .25 + life * .65, sin(birth_angle) * (radius + .23))
			puff.rotation = Vector3(float(index) * .7 + life * .45, float(puff_index) * 1.8 + life * .65, float(index) * .4)
			puff.scale = Vector3(lerpf(.075, .13, life), lerpf(.11, .25, life), lerpf(.07, .12, life))
			puff.material_override.set_shader_parameter("puff_life", life)
		for tear_index in 2:
			var tear: MeshInstance3D = subject.get_node("BloodTear" + str(index) + str(tear_index))
			var cycle := fposmod(elapsed + float(index) * .39 + float(tear_index) * .75, 1.5)
			var falling := minf(cycle, .46)
			var birth_angle := angle - TAU * falling / 6.0
			tear.position = Vector3(cos(birth_angle) * radius, base_height + .07 * sin(birth_angle * 2.0) - .34 - (1.1 + float(index) * .55) * falling - 4.9 * falling * falling, sin(birth_angle) * radius)
			var spawn_height := height / source_scale + base_height + .07 * sin(birth_angle * 2.0) - .34
			var initial_speed := 1.1 + float(index) * .55
			var ground_time := (-initial_speed + sqrt(initial_speed * initial_speed + 19.6 * maxf(spawn_height, 0.0))) / 9.8
			tear.position.y = maxf(tear.position.y, -height / source_scale + .015)
			tear.material_override.set_shader_parameter("tear_alpha", smoothstep(0.0, .045, cycle) * (1.0 - smoothstep(maxf(.1, ground_time - .055), ground_time, cycle)))
