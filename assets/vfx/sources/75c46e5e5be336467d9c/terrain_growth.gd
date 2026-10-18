extends "res://assets/vfx/sources/a4fd0883f0b17d893a03/base.gd"
## Native source authoring; shared stage, process clock, palette and capture.
const SourceMaterials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/75c46e5e5be336467d9c/terrain_growth.gd", input)


func prepare_materials(_node: Node) -> void:
	pass


var variant_index = 0
var roots: Array[Node3D] = []
var base_scales: Array[Vector3] = []
var leaves: Array[MeshInstance3D] = []
var random = RandomNumberGenerator.new()


func apply_scene_edits(node: Node) -> void:
	subject = node
	variant_index = int(settings.variant)
	random.seed = 32921 + variant_index * 193
	if settings.kind == "grease":
		var mesh = MeshInstance3D.new()
		var plane = PlaneMesh.new()
		plane.size = Vector2(2.16, 2.16)
		mesh.mesh = plane
		var mat = ShaderMaterial.new()
		mat.shader = VfxPackageIO_75c46e5e5b.resource("res://assets/vfx/sources/b61b2e3cedb70fd45e7e/grease.gdshader")
		mat.set_shader_parameter(
			"marble", VfxPackageIO_75c46e5e5b.resource("res://assets/vfx/sources/d9693b7f9e0749d03a88/texture.res")
		)
		mat.set_shader_parameter(
			"normal_pattern",
			VfxPackageIO_75c46e5e5b.resource("res://assets/vfx/sources/8a43cfb503b7c212e7ac/texture.res")
		)
		mesh.material_override = mat
		materials.append(mat)
		subject.add_child(mesh)
	elif settings.kind == "thorn":
		build_thorns()
		build_leaves()
	else:
		build_contact()


func wood() -> ShaderMaterial:
	var m = ShaderMaterial.new()
	m.shader = VfxPackageIO_75c46e5e5b.resource("res://assets/vfx/sources/ab2c5b11018952557b19/wood.gdshader")
	m.set_shader_parameter(
		"bark", VfxPackageIO_75c46e5e5b.resource("res://assets/vfx/sources/c3db941ca0009cd4d57e/texture.res")
	)
	m.set_shader_parameter("seed", random.randf() * TAU)
	materials.append(m)
	return m


func add_root(n: Node3D) -> void:
	subject.add_child(n)
	roots.append(n)
	base_scales.append(n.scale)


func tube(points: Array[Vector3], radii: Array[float], mat: Material) -> MeshInstance3D:
	# Smooth each authored bend before building the tapered tube.
	var smooth_points: Array[Vector3] = []
	var smooth_radii: Array[float] = []
	for section in range(points.size() - 1):
		var p0 = points[maxi(0, section - 1)]
		var p1 = points[section]
		var p2 = points[section + 1]
		var p3 = points[mini(points.size() - 1, section + 2)]
		for step in range(5):
			var u = float(step) / 5.0
			smooth_points.append(
				(
					.5
					* (
						(2.0 * p1)
						+ (-p0 + p2) * u
						+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * u * u
						+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * u * u * u
					)
				)
			)
			smooth_radii.append(lerpf(radii[section], radii[section + 1], u))
	smooth_points.append(points[-1])
	smooth_radii.append(radii[-1])
	points = smooth_points
	radii = smooth_radii
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ring = 7
	for i in range(points.size() - 1):
		var tangent = (points[mini(i + 1, points.size() - 1)] - points[maxi(0, i - 1)]).normalized()
		var tangent2 = (points[mini(i + 2, points.size() - 1)] - points[i]).normalized()
		var axis = tangent.cross(Vector3(0.12, 0.99, 0.06)).normalized()
		var across = tangent.cross(axis).normalized()
		var axis2 = tangent2.cross(Vector3(0.12, 0.99, 0.06)).normalized()
		var across2 = tangent2.cross(axis2).normalized()
		for j in range(ring):
			var a = float(j) / ring * TAU
			var b = float(j + 1) / ring * TAU
			var verts = [
				points[i] + (axis * cos(a) + across * sin(a)) * radii[i],
				points[i] + (axis * cos(b) + across * sin(b)) * radii[i],
				points[i + 1] + (axis2 * cos(b) + across2 * sin(b)) * radii[i + 1],
				points[i + 1] + (axis2 * cos(a) + across2 * sin(a)) * radii[i + 1]
			]
			for k in [0, 1, 2, 0, 2, 3]:
				st.set_uv(Vector2(float(j) / ring, float(i) / points.size()))
				st.add_vertex(verts[k])
	st.generate_normals()
	var mesh = MeshInstance3D.new()
	mesh.mesh = st.commit()
	mesh.material_override = mat
	return mesh


func build_thorns() -> void:
	# Artist-authored bark-bearing horizontal vine mesh; held as low roots, never a tall cage.
	var vine = MeshInstance3D.new()
	vine.mesh = VfxPackageIO_75c46e5e5b.resource("res://assets/vfx/sources/a82484aecc978e1f8a85/sm_vines_horizontal_soil.res")
	vine.material_override = wood()
	vine.scale = Vector3(.18, .028, .057)
	vine.position = Vector3(-.04, .048, .43)
	var parent = Node3D.new()
	parent.rotation.y = random.randf() * TAU
	parent.add_child(vine)
	if variant_index % 3 == 0:
		add_root(parent)
	else:
		parent.free()
	for k in range(2):
		var angle = random.randf() * TAU
		var dir = Vector3(cos(angle), 0, sin(angle))
		var cross = Vector3(-sin(angle), 0, cos(angle))
		var points: Array[Vector3] = [
			-dir * .85,
			-dir * .37 + cross * .12 + Vector3(0, .045, 0),
			cross * -.05 + Vector3(0, .09, 0),
			dir * .39 + cross * .13 + Vector3(0, .035, 0),
			dir * .88
		]
		add_root(tube(points, [.012, .045, .052, .034, .003], wood()))
	# New hooked thorn geometry extends the original root language, with six seeded variants.
	for j in range(4 + variant_index % 2):
		var a = random.randf() * TAU
		var r = sqrt(random.randf()) * .59
		var start = Vector3(cos(a) * r, 0.01, sin(a) * r)
		var lean = Vector3(cos(a + .8), 0, sin(a + .8))
		var height = random.randf_range(.18, .32)
		var points: Array[Vector3] = [
			start,
			start + lean * .09 + Vector3(0, height * .35, 0),
			start + lean * .13 + Vector3(0, height * .8, 0),
			start + lean * .04 + Vector3(0, height, 0),
			start - lean * .055 + Vector3(0, height * .95, 0)
		]
		var mesh = tube(points, [.047, .041, .026, .012, .001], wood())
		add_root(mesh)
		if j % 3 == 0:
			var base = start + lean * .09 + Vector3(0, height * .35, 0)
			var branch = tube(
				[
					base,
					base + Vector3(.13, height * .22, .08),
					base + Vector3(.17, height * .48, .10)
				],
				[.022, .015, .001],
				wood()
			)
			add_root(branch)


func build_leaves() -> void:
	# Artist-authored leaf texture from LeLu Healing Flower; sparse loose leaves,
	# not a second carpet. They emerge during growth and flutter above the roots.
	if variant_index % 3 != 0:
		return
	for i in range(3):
		var mesh = MeshInstance3D.new()
		var quad = QuadMesh.new()
		quad.size = Vector2(.075, .15)
		mesh.mesh = quad
		var mat = StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.albedo_texture = VfxPackageIO_75c46e5e5b.resource("res://assets/vfx/sources/08fdfe261849c907a0c7/texture.res")
		mat.albedo_color = Color(.64, .72, .25, 1.0)
		mesh.material_override = mat
		subject.add_child(mesh)
		leaves.append(mesh)


func build_contact() -> void:
	for j in range(9):
		var mesh = MeshInstance3D.new()
		var sphere = SphereMesh.new()
		sphere.radius = .025 if settings.kind == "grease_contact" else .016
		sphere.height = sphere.radius * 2
		mesh.mesh = sphere
		var mat = StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color("9b8c73") if settings.kind == "grease_contact" else Color("823a2c")
		mesh.material_override = mat
		add_root(mesh)


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
			sin(progress * PI) * smoothstep(.05, .35, age) * (1.0 - smoothstep(3.0, 3.8, age))
		)
		leaves[i].position = Vector3(cos(a) * .38, .06 + progress * .4, sin(a) * .33)
		leaves[i].rotation = Vector3(sin(a) * .8, a * 2.0, cos(a) * .65)
		leaves[i].scale = Vector3.ONE * envelope
	var grow = smoothstep(.02, .92, age)
	var end = 1.0 - smoothstep(3.0, 3.8, age)
	for i in range(roots.size()):
		var delay = float(i % 7) * .04
		var g = (
			smoothstep(.02 + delay, .72 + delay, age)
			* (1.0 - smoothstep(3.0 + delay, 3.72 + delay, age))
		)
		roots[i].scale = base_scales[i] * Vector3(1.0, maxf(.001, g), 1.0)
	for m in materials:
		m.set_shader_parameter("clock", age - 1.0)
		m.set_shader_parameter("opacity", end)
		if settings.kind == "grease":
			m.set_shader_parameter("grow", grow)

const VfxPackageIO_75c46e5e5b = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
