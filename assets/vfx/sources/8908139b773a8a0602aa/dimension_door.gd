extends "res://assets/vfx/sources/a4fd0883f0b17d893a03/base.gd"
## Beveled doorway geometry and retained LeLu orbital border process.
var gate: Node3D


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/8908139b773a8a0602aa/dimension_door.gd", input)


func prepare_materials(_node: Node) -> void:
	pass


func material(style: int) -> ShaderMaterial:
	var m = ShaderMaterial.new()
	var sh = Shader.new()
	sh.code = (
		VfxPackageIO_8908139b77.text("res://assets/vfx/sources/cba409459d69fcded0ee/dimension_door.gdshader")
		. replace("SIDE_COMPARE", ">" if side == "back" else "<=")
		. replace("FRONT_CAPTURE", "true" if side == "front" else "false")
	)
	m.shader = sh
	m.set_shader_parameter("style", style)
	(
		m
		. set_shader_parameter(
			"donor_noise",
			VfxPackageIO_8908139b77.resource(
				"res://assets/vfx/sources/ed6f200121742475d523/texture.res"
			)
		)
	)
	m.set_shader_parameter(
		"donor_stars",
		VfxPackageIO_8908139b77.resource("res://assets/vfx/sources/8ed072b3dfe154003091/texture.res")
	)
	materials.append(m)
	return m


func apply_scene_edits(node: Node) -> void:
	tick = 0
	gate = Node3D.new()
	node.add_child(gate)
	# Upright rounded doorway. The complete 3D bevel surrounds a recessed opening.
	var path: Array[Vector3] = [Vector3(-.96, .06, 0), Vector3(-.96, 2.20, 0)]
	for i in range(1, 25):
		var a = PI - PI * float(i) / 24.
		path.append(Vector3(cos(a) * .96, 2.20 + sin(a) * .92, 0))
	path.append(Vector3(.96, .06, 0))
	path.append(Vector3(-.96, .06, 0))
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(path.size() - 1):
		var p = path[i]
		var p2 = path[i + 1]
		var direction = (p2 - p).normalized()
		var normal = Vector3(-direction.y, direction.x, 0)
		var profiles = [
			Vector2(-.068, -.05),
			Vector2(-.045, -.092),
			Vector2(.045, -.092),
			Vector2(.068, -.05),
			Vector2(.068, .05),
			Vector2(.045, .092),
			Vector2(-.045, .092),
			Vector2(-.068, .05)
		]
		for j in range(8):
			var a = profiles[j]
			var b = profiles[(j + 1) % 8]
			var vertices = [
				p + normal * a.x + Vector3(0, 0, a.y),
				p2 + normal * a.x + Vector3(0, 0, a.y),
				p2 + normal * b.x + Vector3(0, 0, b.y),
				p + normal * b.x + Vector3(0, 0, b.y)
			]
			for k in [0, 1, 2, 0, 2, 3]:
				st.set_uv(
					Vector2(
						float(i + (1 if k in [1, 2] else 0)) / float(path.size() - 1), float(j) / 8.
					)
				)
				st.add_vertex(vertices[k])
	st.generate_normals()
	var rim = MeshInstance3D.new()
	rim.mesh = st.commit()
	rim.material_override = material(0)
	gate.add_child(rim)
	var recess = MeshInstance3D.new()
	var quad = QuadMesh.new()
	quad.size = Vector2(1.78, 3.02)
	recess.mesh = quad
	recess.position = Vector3(0, 1.57, -.105)
	recess.material_override = material(1)
	gate.add_child(recess)
	var sill = MeshInstance3D.new()
	var plane = PlaneMesh.new()
	plane.size = Vector2(2.02, .42)
	sill.mesh = plane
	sill.position = Vector3(0, .065, 0)
	sill.material_override = material(2)
	gate.add_child(sill)
	# Retain the LeLu native orbital trail process, keeping a sparse, fine border.
	var donor = (
		VfxPackageIO_8908139b77.resource(
			"res://assets/vfx/sources/33ffc4322e4d3d7fe893/VFX_Portal_TypeA.tscn"
		)
		. instantiate()
	)
	ResourceGraph.isolate_node(donor, {})
	var sparks = donor.get_node("small particles border").duplicate()
	gate.add_child(sparks)
	donor.free()
	sparks.position.y = 1.60
	sparks.scale = Vector3(.85, 1.34, .4)
	sparks.amount = 36
	sparks.fixed_fps = 144
	sparks.use_fixed_seed = true
	sparks.seed = 622019
	sparks.process_material = sparks.process_material.duplicate(true)
	sparks.process_material.color = Color(.45, .45, .45, 1)
	sparks.draw_pass_1 = sparks.draw_pass_1.duplicate(true)
	sparks.draw_pass_1.size = .035
	sparks.material_override = material(3)
	sparks.restart()


func advance_lifecycle(_delta: float) -> void:
	if gate == null:
		return
	tick += 1
	var age = float(tick) / 144.
	var open = smoothstep(0., .34, age) * (1. - smoothstep(2.05, 2.65, age))
	gate.scale = Vector3(max(.002, open), 1., 1.)
	for m in materials:
		m.set_shader_parameter("door_clock", age)
		m.set_shader_parameter("door_envelope", open)

const VfxPackageIO_8908139b77 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
