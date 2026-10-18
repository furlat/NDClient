extends "res://assets/vfx/sources/02e8eda447821da38634/necrotic.gd"


## Preserved v9 field geometry and fissure-rooted smoke. Uses the shared recorder and finishing.
static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/7a0decad7bdb99be9d7b/death_circle.gd", input)


func apply_scene_edits(node: Node) -> void:
	assembly = Node3D.new()
	assembly.scale.y = sqrt(2. / 3.)
	node.add_child(assembly)
	make_death_field()
	make_fissure_smoke()


func make_death_field() -> void:
	for layer in [0, 1]:
		var st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var nx = 192
		var ny = 40
		for j in range(ny):
			for i in range(nx):
				for c in [
					Vector2i(i, j),
					Vector2i(i + 1, j),
					Vector2i(i + 1, j + 1),
					Vector2i(i, j),
					Vector2i(i + 1, j + 1),
					Vector2i(i, j + 1)
				]:
					var u = float(c.x) / nx
					var v = float(c.y) / ny
					var a = u * TAU
					var rad = v * 12.
					var h = (
						.025
						if layer == 0
						else (
							.09
							+ 3.0 * sqrt(maxf(0., 1. - v * v)) * (.95 + .05 * sin(a * 3. + v * 4.))
						)
					)
					st.set_uv(Vector2(.5 + cos(a) * v * .5, .5 + sin(a) * v * .5))
					st.add_vertex(Vector3(cos(a) * rad, h, sin(a) * rad))
		st.generate_normals()
		var f = MeshInstance3D.new()
		f.mesh = st.commit()
		var m = ShaderMaterial.new()
		var sh = Shader.new()
		sh.code = VfxPackageIO_7a0decad7b.text("res://assets/vfx/sources/017f10de32c4699de1b2/death_field.gdshader")
		m.shader = sh
		m.set_shader_parameter("layer", layer)
		m.set_shader_parameter(
			"noise_tex",
			VfxPackageIO_7a0decad7b.resource("res://assets/vfx/sources/a02e62c059c89f4070a7/texture.res")
		)
		(
			m
			. set_shader_parameter(
				"flow_tex",
				VfxPackageIO_7a0decad7b.resource(
					"res://assets/vfx/sources/62aa5f7eb4811482b403/texture.res"
				)
			)
		)
		(
			m
			. set_shader_parameter(
				"cracks_tex",
				VfxPackageIO_7a0decad7b.resource(
					"res://assets/vfx/sources/eaa79bc6c118416e146b/texture.res"
				)
			)
		)
		adapt_shader(m)
		f.material_override = m
		assembly.add_child(f)


func make_fissure_smoke() -> void:
	# Irregular rooted plumes use cloud noise, not the vertical trail texture.
	for i in range(16):
		var radial = .89 if i % 2 == 0 else .57
		var a = float(i) * TAU / 16. + PI / 48. + .08 * sin(float(i) * 2.7)
		var st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var height = 3.2 + 1.1 * (.5 + .5 * sin(float(i) * 2.3))
		var width = 1.4 + 1.2 * (.5 + .5 * cos(float(i) * 1.7))
		for j in range(32):
			for k in range(8):
				for c in [
					Vector2i(k, j),
					Vector2i(k + 1, j),
					Vector2i(k + 1, j + 1),
					Vector2i(k, j),
					Vector2i(k + 1, j + 1),
					Vector2i(k, j + 1)
				]:
					var u = float(c.x) / 8.
					var v = float(c.y) / 32.
					var tangent = (
						(u - .5) * width * (.22 + .78 * sin(v * PI * .85))
						+ .24 * sin(v * PI * 1.4 + float(i)) * v
					)
					var rad = radial * 12. - .18 * sin(v * PI) + .42 * sin(u * PI) * sin(v * PI)
					var aa = a + v * .045
					st.set_uv(Vector2(u, v))
					st.add_vertex(
						Vector3(
							cos(aa) * rad - sin(aa) * tangent,
							.06 + v * height,
							sin(aa) * rad + cos(aa) * tangent
						)
					)
		st.generate_normals()
		var f = MeshInstance3D.new()
		f.mesh = st.commit()
		var m = ShaderMaterial.new()
		var sh = Shader.new()
		sh.code = VfxPackageIO_7a0decad7b.text("res://assets/vfx/sources/d10d19273813b6b68a5f/fissure_smoke.gdshader")
		m.shader = sh
		m.render_priority = 2
		m.set_shader_parameter("radial", radial)
		m.set_shader_parameter("seed", float(i) * .31)
		m.set_shader_parameter(
			"noise_tex",
			VfxPackageIO_7a0decad7b.resource(
				"res://assets/vfx/sources/cec990abb6644bc8a611/texture.res"
			)
		)
		m.set_shader_parameter(
			"detail_tex",
			VfxPackageIO_7a0decad7b.resource("res://assets/vfx/sources/a5f322c9a0afd0417634/texture.res")
		)
		adapt_shader(m)
		f.material_override = m
		assembly.add_child(f)

const VfxPackageIO_7a0decad7b = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
