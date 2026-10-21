extends "res://assets/vfx/sources/a4fd0883f0b17d893a03/base.gd"


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/extensions/owner-fields-v2-20261021/sources/e8471d2128c6091743c3/gust_front.gd", input)


func prepare_materials(_node: Node) -> void:
	pass


func apply_scene_edits(node: Node) -> void:
	direction = Vector3(settings.direction[0], 0, settings.direction[1]).normalized()
	hand = Vector3(settings.hand[0], settings.hand[1], settings.hand[2])
	across = Vector3(-direction.z, 0, direction.x)
	var donor = VfxPackageIO_e8471d2128.resource(parameters.donor_scene).instantiate()
	var cut = donor.get_node("cut")
	var base = cut.material_override
	head = MeshInstance3D.new()
	var arrays = cut.draw_pass_1.surface_get_arrays(0)
	var colors = PackedColorArray()
	for v in arrays[Mesh.ARRAY_VERTEX]:
		colors.append(Color(1, 1, 1, .025))
	arrays[Mesh.ARRAY_COLOR] = colors
	var head_mesh = ArrayMesh.new()
	head_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	head.mesh = head_mesh
	head.scale = Vector3(.55, 1.05, .65)
	head.rotation.y = atan2(-direction.x, -direction.z)
	head.material_override = material(base, 1.0, 0)
	node.add_child(head)
	for j in range(3):
		var strip = MeshInstance3D.new()
		strip.material_override = material(base, .85 - j * .12, j + 1)
		node.add_child(strip)
		strands.append(strip)
	donor.free()
	var dense = (
		VfxPackageIO_e8471d2128.resource("res://assets/vfx/extensions/owner-fields-v2-20261021/sources/04675585a5572375a329/VFX_WindBlow_1.tscn")
		. instantiate()
	)
	var wall = dense.get_node("tornado17")
	var ba = wall.draw_pass_1.surface_get_arrays(0)
	var bc = PackedColorArray()
	for v in ba[Mesh.ARRAY_VERTEX]:
		bc.append(Color(1, 1, 1, .025))
	ba[Mesh.ARRAY_COLOR] = bc
	var bm = ArrayMesh.new()
	bm.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, ba)
	body = MeshInstance3D.new()
	body.mesh = bm
	body.scale = Vector3(1.28, 1.10, 1.10)
	body.rotation.y = head.rotation.y
	body.material_override = material(wall.material_override, .78, -1)
	node.add_child(body)
	dense.free()


var head: MeshInstance3D
var body: MeshInstance3D
var strands: Array = []
var mats: Array = []
var direction: Vector3
var across: Vector3
var hand: Vector3
const W = 1536
const H = 1024


func material(base: ShaderMaterial, strength: float, phase: float) -> ShaderMaterial:
	var m = ShaderMaterial.new()
	var s = Shader.new()
	var code: String = base.shader.code.replace("TIME", "source_clock")
	code = code.replace(
		"shader_type spatial;",
		"shader_type spatial;\nuniform float source_clock=0.0;uniform float opacity=1.0;"
	)
	var end = code.rfind("}")
	code = (
		code
		. insert(
			end,
			"\nALBEDO=vec3(dot(ALBEDO,vec3(0.2126,0.7152,0.0722)))*vec3(0.96,0.98,0.96);ALPHA*=opacity;\n"
		)
	)
	s.code = code
	m.shader = s
	for p in base.shader.get_shader_uniform_list():
		m.set_shader_parameter(p.name, base.get_shader_parameter(p.name))
	var gradient = Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, .28, .85])
	gradient.colors = PackedColorArray(
		[Color(.9, .94, .92, 0), Color(.9, .94, .92, .75), Color(.62, .67, .65, 1)]
	)
	var texture = GradientTexture1D.new()
	texture.gradient = gradient
	m.set_shader_parameter("Color_1D_Gradient", texture)
	if phase > 0:
		var white = GradientTexture1D.new()
		var g = Gradient.new()
		g.offsets = PackedFloat32Array([0, .18, .70, 1])
		g.colors = PackedColorArray([Color.BLACK, Color.WHITE, Color.WHITE, Color.BLACK])
		white.gradient = g
		m.set_shader_parameter("Multiply_Texture", white)
	m.set_shader_parameter("Speed_XY", Vector2(0.08, -0.9 - phase * .13))
	m.set_shader_parameter(
		"Scale", Vector2(.65, 1.0) if phase == 0 else Vector2(2.7 + phase * .25, 2.0 + phase * .23)
	)
	if phase < 0:
		for name in ["Scale", "Speed_XY"]:
			m.set_shader_parameter(name, base.get_shader_parameter(name))
	mats.append({"mat": m, "gain": strength, "phase": phase})
	return m


func ribbon_mesh(which: int, reach: float, t: float) -> ArrayMesh:
	var vs = PackedVector3Array()
	var uv = PackedVector2Array()
	var cs = PackedColorArray()
	var ix = PackedInt32Array()
	var lengths = [13.0, 9.3, 6.2]
	var widths = [1.15, .83, .61]
	var offsets = [-.85, .75, .15]
	var start = lerpf(maxf(0.0, reach - lengths[which]), 0.0, smoothstep(1.3, 1.7, t))
	for i in range(65):
		var u = float(i) / 64.0
		var along = lerpf(start, reach, u)
		var off = (
			offsets[which]
			+ .38 * sin(u * 8.0 - t * 2.3 + which * 2.0)
			+ .15 * sin(u * 17.0 - t * 3.1)
		)
		var y = .8 + which * .30 + .38 * sin(u * 8.0 - t * 2.5 + which)
		var width = (
			widths[which] * pow(sin(PI * u), .7) * (.72 + .28 * sin(u * 19.0 - t * 4.0 + which))
		)
		var roll = .8 + .45 * sin(u * 9.0 - t * 1.3 + which)
		var axis = across * cos(roll) + Vector3.UP * sin(roll)
		for side in [-1.0, 1.0]:
			var blend = 1.0 - smoothstep(0.0, 4.0, along)
			vs.append(
				(
					direction * along
					+ (Vector3(hand.x, 0, hand.z) + Vector3.UP * (hand.y - y)) * blend
					+ across * off * (1.0 - blend)
					+ Vector3.UP * y
					+ axis * width * side
				)
			)
			uv.append(Vector2((side + 1.0) * .5, u))
			cs.append(Color(1, 1, 1, .025))
	for i in range(64):
		var j = i * 2
		ix.append_array(PackedInt32Array([j, j + 1, j + 2, j + 1, j + 3, j + 2]))
	var normals = PackedVector3Array()
	var tangents = PackedFloat32Array()
	for v in vs:
		normals.append(Vector3.UP)
		tangents.append_array(PackedFloat32Array([direction.x, 0, direction.z, 1]))
	var a = []
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_NORMAL] = normals
	a[Mesh.ARRAY_TANGENT] = tangents
	a[Mesh.ARRAY_VERTEX] = vs
	a[Mesh.ARRAY_TEX_UV] = uv
	a[Mesh.ARRAY_COLOR] = cs
	a[Mesh.ARRAY_INDEX] = ix
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
	return mesh


func advance_lifecycle(_dt):
	tick += 1
	var t = float(tick) / 144.0
	var travel = clampf((t - .08) * 16.0, 0, 24)
	var onset = smoothstep(0.0, .16, t)
	var end = 1.0 - smoothstep(2.6, 3.0, t)
	head.position = (
		direction * (travel - 2.4)
		+ Vector3.UP * .90
		+ (hand - Vector3.UP * .9) * (1.0 - smoothstep(0., 4., travel))
	)
	head.visible = t < 1.7
	body.position = (
		direction * (travel - 1.66)
		+ Vector3.UP * .18
		+ (hand - Vector3.UP * .9) * (1.0 - smoothstep(0., 4., travel))
	)
	body.visible = head.visible
	for i in range(mats.size()):
		var item = mats[i]
		item.mat.set_shader_parameter("source_clock", t + item.phase * .19)
		var gain = item.gain * onset * end
		if item.phase <= 0:
			gain *= 1.0 - smoothstep(1.45, 1.65, t)
		else:
			gain *= lerpf(1.0, .80, smoothstep(1.4, 1.85, t))
		item.mat.set_shader_parameter("opacity", gain)
	for j in range(strands.size()):
		var reach = travel
		if t > 1.5:
			reach = 24.0
		strands[j].mesh = ribbon_mesh(j, reach, t)

const VfxPackageIO_e8471d2128 = preload("res://assets/vfx/extensions/owner-fields-v2-20261021/scoped_resource_io.gd")
