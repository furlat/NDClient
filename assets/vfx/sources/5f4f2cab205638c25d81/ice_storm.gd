extends "res://assets/vfx/sources/a4fd0883f0b17d893a03/base.gd"
## Preserved native authoring geometry and material lifecycle, with shared capture/clock ownership.
const SourceMaterials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/5f4f2cab205638c25d81/ice_storm.gd", input)


func prepare_materials(_node: Node) -> void:
	pass


const YC = .816496580927726
const GRAVITY = 6.4
var chunk: MeshInstance3D
var original: Mesh
var vertices = PackedVector3Array()
var pieces: Array = []
var bodies: Array[RigidBody3D] = []
var visuals: Array[MeshInstance3D] = []
var interior: ShaderMaterial
var ice: ShaderMaterial
var impacts: Array[MeshInstance3D] = []
var impact_mat: ShaderMaterial
var size: Vector3
var hit_time = 0.0
var contact_height = 0.0
var born_height = 7.5
var initial_speed = 2.6
var angular: Vector3
var shattered = false
var frozen = false
var rng = RandomNumberGenerator.new()


func material() -> ShaderMaterial:
	var m = ShaderMaterial.new()
	m.shader = VfxPackageIO_5f4f2cab20.resource("res://assets/vfx/sources/e0db67ddc0d6c2aa1614/ice.gdshader")
	m.set_shader_parameter(
		"AddTexture",
		SourceMaterials.raw_texture("res://assets/vfx/sources/cc3ee322db85204a95aa/texture.res")
	)
	m.set_shader_parameter(
		"AddTexture2",
		SourceMaterials.raw_texture("res://assets/vfx/sources/9dd4b1e9c98d16632575/texture.res")
	)
	var n = FastNoiseLite.new()
	n.seed = 628100
	n.frequency = .0166
	n.domain_warp_enabled = true
	n.domain_warp_frequency = -.06
	n.domain_warp_fractal_type = 0
	var noise = NoiseTexture2D.new()
	noise.noise = n
	noise.seamless = true
	var ramp = Gradient.new()
	ramp.colors = PackedColorArray([Color(.779292, .779291, .779291), Color.BLACK])
	ramp.offsets = PackedFloat32Array([.00561798, 1.])
	noise.color_ramp = ramp
	m.set_shader_parameter("DetailsTexture", noise)
	var g = Gradient.new()
	g.interpolation_color_space = 2
	g.offsets = PackedFloat32Array([0., .640669, .724234, .785515, 1.])
	g.colors = PackedColorArray(
		[
			Color(.0972, .17208, .27),
			Color(.31, .46, .60),
			Color(.86, .94, .96),
			Color(.22, .36, .49),
			Color(.57, .74, .84)
		]
	)
	var gradient = GradientTexture1D.new()
	gradient.gradient = g
	m.set_shader_parameter("Color1DGradient", gradient)
	m.set_shader_parameter("fresnelpower", 1.36)
	m.set_shader_parameter("ColorIntensity", 1.35)
	m.set_shader_parameter(
		"Texture_add2_offset",
		Vector2(2.875 + settings.variant * .137, 1.02 + settings.variant * .19)
	)
	m.set_shader_parameter("Details_scale", Vector2(1., 1.))
	m.set_shader_parameter("Details_speed", Vector2.ZERO)
	m.set_shader_parameter("front", side == "front")
	materials.append(m)
	return m


func normalized(source: Mesh) -> ArrayMesh:
	var out = ArrayMesh.new()
	var bb = source.get_aabb()
	for surface in range(source.get_surface_count()):
		var arr = source.surface_get_arrays(surface).duplicate(true)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		for i in range(v.size()):
			v[i] = (v[i] - bb.get_center()) / bb.size * size
			vertices.append(v[i])
		for i in range(norms.size()):
			norms[i] = (norms[i] * bb.size / size).normalized()
		arr[Mesh.ARRAY_VERTEX] = v
		arr[Mesh.ARRAY_NORMAL] = norms
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return out


func pose(age: float) -> Basis:
	return Basis.from_euler(
		(
			Vector3(
				.25 + settings.variant * .41, settings.variant * .71, .18 + settings.variant * .23
			)
			+ angular * age
		)
	)


func bottom(basis: Basis) -> float:
	var min_y = 100.
	for v in vertices:
		min_y = minf(min_y, (basis * v).y)
	return min_y


func centre(age: float) -> Vector3:
	return Vector3(
		(age - hit_time) * (.16 + .025 * settings.variant),
		born_height - initial_speed * age - .5 * GRAVITY * age * age,
		(age - hit_time) * (.055 - .018 * settings.variant)
	)


func visual_pose(basis: Basis, pos: Vector3) -> Transform3D:
	return Transform3D(basis, pos).scaled(Vector3(1., YC, 1.))


func apply_scene_edits(node: Node) -> void:
	settings.variant = int(settings.variant)
	contact_height = 1.32 if settings.contact else 0.0
	rng.seed = 628109 + settings.variant * 773 + int(settings.contact) * 31
	var donor = (
		VfxPackageIO_5f4f2cab20.resource(
			"res://assets/vfx/sources/1de4aba0c112cd12248b/sm_ice004uv2.res"
		)
		if settings.variant % 3 == 0
		else (
			VfxPackageIO_5f4f2cab20.resource(
				"res://assets/vfx/sources/2a13c248c0cdcfbd7b11/sm_rocks_stone4_001.res"
			)
			if settings.variant % 3 == 1
			else VfxPackageIO_5f4f2cab20.resource(
				"res://assets/vfx/sources/cc80b24acc80a3637ec8/sm_rocks_stone5_001.res"
			)
		)
	)
	var d = [.82, .64, .98, .72][settings.variant % 4]
	size = Vector3(d, d * (.82 + settings.variant * .035), d * (.80 + .04 * (settings.variant % 3)))
	original = normalized(donor)
	angular = Vector3(
		.35 + settings.variant * .13, .46 - settings.variant * .08, .56 - settings.variant * .10
	)
	born_height = 7.4 - .15 * (settings.variant % 3)
	initial_speed = 2.4 + .22 * (settings.variant % 3)
	var lo = 0.
	var hi = 2.
	for i in range(35):
		var mid = (lo + hi) * .5
		var low = born_height - initial_speed * mid - .5 * GRAVITY * mid * mid + bottom(pose(mid))
		if low > contact_height:
			lo = mid
		else:
			hi = mid
	hit_time = (lo + hi) * .5
	interior = ShaderMaterial.new()
	var interior_shader = Shader.new()
	interior_shader.code = VfxPackageIO_5f4f2cab20.text(
		"res://assets/vfx/sources/610a67cc504c03837caa/ice_storm_interior.gdshader"
	)
	interior.shader = interior_shader
	interior.set_shader_parameter(
		"frost",
		SourceMaterials.raw_texture("res://assets/vfx/sources/9dd4b1e9c98d16632575/texture.res")
	)
	interior.set_shader_parameter("front", side == "front")
	ice = material()
	chunk = MeshInstance3D.new()
	chunk.mesh = original
	chunk.material_override = ice
	node.add_child(chunk)
	build_pieces()
	var floor = StaticBody3D.new()
	floor.position.y = -.25
	node.add_child(floor)
	var shape = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(20., .5, 20.)
	shape.shape = box
	floor.add_child(shape)
	var impact = MeshInstance3D.new()
	var p = PlaneMesh.new()
	p.size = Vector2(1.9, 1.9)
	impact.mesh = p
	impact.position = Vector3(0., .025, 0.)
	node.add_child(impact)
	impact_mat = ShaderMaterial.new()
	var s = Shader.new()
	s.code = VfxPackageIO_5f4f2cab20.text("res://assets/vfx/sources/ff0e36f50afdd033d06c/ice_storm_powder.gdshader")
	impact_mat.shader = s
	impact_mat.set_shader_parameter(
		"noise_tex",
		SourceMaterials.raw_texture(
			"res://assets/vfx/sources/900721c102c94ad02849/texture.res"
		)
	)
	impact_mat.set_shader_parameter("front", side == "front")
	impact.material_override = impact_mat
	impacts.append(impact)


func clip(poly: Array, axis: int, sign0: int, cuts: Array) -> Array:
	var result = []
	for i in range(poly.size()):
		var a = poly[i]
		var b = poly[(i + 1) % poly.size()]
		var da = a.p[axis] * sign0
		var db = b.p[axis] * sign0
		var inside_a = da >= -.000001
		var inside_b = db >= -.000001
		if inside_a:
			result.append(a)
		if inside_a != inside_b:
			var t = da / (da - db)
			var c = {
				"p": a.p.lerp(b.p, t),
				"uv": a.uv.lerp(b.uv, t),
				"n": a.n.lerp(b.n, t).normalized(),
				"cap": a.get("cap", false)
			}
			result.append(c)
			cuts.append(c.p)
	return result


func build_pieces() -> void:
	# Clip the original source triangles into closed octants. Surface UVs survive; caps are new interior ice faces.
	for octant in range(8):
		var polys = []
		var signs = [1 if octant & 1 else -1, 1 if octant & 2 else -1, 1 if octant & 4 else -1]
		for surface in range(original.get_surface_count()):
			var arr = original.surface_get_arrays(surface)
			var v = arr[Mesh.ARRAY_VERTEX]
			var uv = arr[Mesh.ARRAY_TEX_UV]
			var norms = arr[Mesh.ARRAY_NORMAL]
			var indices = arr[Mesh.ARRAY_INDEX]
			if indices == null or indices.size() == 0:
				indices = PackedInt32Array(range(v.size()))
			for k in range(0, indices.size(), 3):
				var poly = []
				for j in range(3):
					var ix = indices[k + j]
					poly.append(
						{
							"p": v[ix],
							"uv":
							uv[ix] if uv != null and uv.size() > ix else Vector2(v[ix].x, v[ix].z),
							"n": norms[ix]
						}
					)
				polys.append(poly)
		for axis in range(3):
			var next = []
			var cuts = []
			for poly in polys:
				var p = clip(poly, axis, signs[axis], cuts)
				if p.size() >= 3:
					next.append(p)
			# Convex donor sections are closed by a sorted cap polygon, then clipped by subsequent planes.
			var unique = []
			for v in cuts:
				var found = false
				for q in unique:
					if q.distance_squared_to(v) < .00000001:
						found = true
						break
				if not found:
					unique.append(v)
			if unique.size() >= 3:
				var c = Vector3.ZERO
				for v in unique:
					c += v
				c /= unique.size()
				var u = (axis + 1) % 3
				var w = (axis + 2) % 3
				unique.sort_custom(
					func(a, b):
						return atan2(a[w] - c[w], a[u] - c[u]) < atan2(b[w] - c[w], b[u] - c[u])
				)
				if signs[axis] > 0:
					unique.reverse()
				var normal = Vector3.ZERO
				normal[axis] = -signs[axis]
				var cap = []
				for v in unique:
					cap.append(
						{"p": v, "uv": Vector2(v[u] + .5, v[w] + .5), "n": normal, "cap": true}
					)
				next.append(cap)
			polys = next
		var all = PackedVector3Array()
		for poly in polys:
			for v in poly:
				all.append(v.p)
		if all.size() < 4:
			continue
		var bb = AABB(all[0], Vector3.ZERO)
		for v in all:
			bb = bb.expand(v)
		var pivot = bb.get_center()
		var mesh = ArrayMesh.new()
		for is_cap in [false, true]:
			var st = SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			var count = 0
			for poly in polys:
				if poly[0].get("cap", false) != is_cap:
					continue
				for i in range(1, poly.size() - 1):
					for v in [poly[0], poly[i], poly[i + 1]]:
						st.set_uv(v.uv)
						st.set_normal(v.n)
						st.add_vertex(v.p - pivot)
						count += 1
			if count > 0:
				st.set_material(interior if is_cap else ice)
				st.commit(mesh)
		pieces.append({"mesh": mesh, "pivot": pivot})


func shatter(node: Node) -> void:
	shattered = true
	chunk.visible = false
	var basis = pose(hit_time)
	var pos = centre(hit_time)
	for i in range(pieces.size()):
		var part = pieces[i]
		var mesh = part.mesh
		var body = RigidBody3D.new()
		body.mass = .30
		body.gravity_scale = GRAVITY / 9.8
		body.linear_damp = 1.1
		body.angular_damp = 2.0
		body.continuous_cd = true
		var phys = PhysicsMaterial.new()
		phys.friction = .86
		phys.bounce = .12
		body.physics_material_override = phys
		node.add_child(body)
		body.transform = Transform3D(basis, pos + basis * part.pivot)
		var collision = CollisionShape3D.new()
		collision.shape = mesh.create_convex_shape()
		body.add_child(collision)
		var draw = MeshInstance3D.new()
		draw.mesh = mesh
		node.add_child(draw)
		var outward = basis * part.pivot
		outward.y = 0.
		outward = outward.normalized()
		body.linear_velocity = (
			outward * (.40 + rng.randf() * .65)
			+ Vector3(
				0., (.55 + rng.randf() * .9) if not settings.contact else -.9 - rng.randf(), 0.
			)
		)
		body.angular_velocity = Vector3(
			rng.randf_range(-2., 2.), rng.randf_range(-2., 2.), rng.randf_range(-2., 2.)
		)
		bodies.append(body)
		visuals.append(draw)


func advance_lifecycle(_delta: float) -> void:
	if chunk == null:
		return
	tick += 1
	var age = float(tick) / 144.
	if not shattered and age >= hit_time:
		shatter(chunk.get_parent())
	if not shattered:
		chunk.transform = visual_pose(pose(age), centre(age))
	for i in range(bodies.size()):
		visuals[i].transform = bodies[i].global_transform.scaled(Vector3(1., YC, 1.))
		if age >= 2.94 and not frozen:
			bodies[i].freeze = true
	if age >= 2.94:
		frozen = true
	impact_mat.set_shader_parameter("impact_age", maxf(0., age - hit_time))
	impact_mat.set_shader_parameter("visible_hit", age >= hit_time and age - hit_time < .45)

const VfxPackageIO_5f4f2cab20 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
