extends "res://assets/vfx/sources/a4fd0883f0b17d893a03/base.gd"


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/extensions/late-20261020/sources/28b0b8f827f5c7be91cd/summon_lifecycle.gd", input)


func prepare_materials(_node: Node) -> void:
	pass


func apply_scene_edits(_node: Node) -> void:
	build_native()


func advance_lifecycle(_d: float) -> void:
	tick += 1
	set_age(float(tick - 1) / float(parameters.simulation_hz))


# Shared authoring source. Logical unit=5-foot cell; ground X/Z, logical height Y.
# Native Y is corrected by .81649658 to match engine 128x64/64-height projection.
const Y_CORRECTION = 0.816496580927726
const FamilyPalette = preload("res://assets/vfx/extensions/late-20261020/sources/79ab2d88fca686bd9c46/neutral_family_palette.gd")
var ground: MeshInstance3D
var ribbons = []
var motes = []
var time = 0.0
var camera_ground = Vector2(.70710678, .70710678)


func build_native():
	subject.scale.y = Y_CORRECTION
	var q = float(settings.camera_quadrant) * PI / 2.
	camera_ground = Vector2(cos(q) + sin(q), cos(q) - sin(q)).normalized()
	if settings.kind in ["arrival", "departure", "bond"]:
		ground = MeshInstance3D.new()
		var plane = PlaneMesh.new()
		plane.size = Vector2(2.5, 2.5)
		ground.mesh = plane
		ground.position.y = .015
		subject.add_child(ground)
		ground.material_override = _material("ground")
	for j in range(12 if settings.kind != "cast" else 8):
		var node = MeshInstance3D.new()
		subject.add_child(node)
		var mat = _material("wisp")
		mat.set_shader_parameter("seed", float(j % 3) * .317)
		node.material_override = mat
		ribbons.append(node)
	for j in range(32 if settings.kind != "cast" else 16):
		var node = MeshInstance3D.new()
		var quad = QuadMesh.new()
		quad.size = Vector2(.10, .10)
		node.mesh = quad
		subject.add_child(node)
		node.material_override = _material("mote")
		motes.append(node)
	set_age(0.)


func _material(which: String) -> ShaderMaterial:
	var m = ShaderMaterial.new()
	m.shader = VfxPackageIO_28b0b8f827.resource(parameters.shaders[which])
	if which != "mote":
		m.set_shader_parameter(
			"noise_tex", VfxPackageIO_28b0b8f827.resource("res://assets/vfx/extensions/late-20261020/sources/ed6f200121742475d523/texture.res")
		)
	if which == "ground":
		m.set_shader_parameter(
			"vortex_tex", VfxPackageIO_28b0b8f827.resource("res://assets/vfx/extensions/late-20261020/sources/7267348c7f179ed6875c/texture.res")
		)
	if which != "ground":
		m.set_shader_parameter("side", 0.0 if side == "full" else (-1.0 if side == "back" else 1.0))
		m.set_shader_parameter("camera_ground", camera_ground)
	if parameters.has("neutral_family_palette"):
		FamilyPalette.apply(m,parameters.neutral_family_palette)
	materials.append(m)
	return m


func _envelope(t: float) -> float:
	if settings.kind == "arrival":
		return smoothstep(0., .30, t) * (1. - smoothstep(.90, 1.64, t))
	if settings.kind == "departure":
		return smoothstep(0., .22, t) * (1. - smoothstep(.92, 1.42, t))
	if settings.kind == "bond":
		return smoothstep(0., .10, t) * (1. - smoothstep(.30, .68, t))
	return smoothstep(0., .10, t) * (1. - smoothstep(.27, .70, t))


func ribbon_vertices(j: int,t: float) -> PackedVector3Array:
	var steps = 28
	var vertices = PackedVector3Array()
	var quarter = j / 3 if settings.kind != "cast" else j / 2
	var lane = j % 3 if settings.kind != "cast" else j % 2
	var base = float(quarter) * PI / 2. + float(lane) * .31
	var contract = (
		1. - smoothstep(.28, 1.24, t) * .77
		if settings.kind == "departure"
		else .58 + .42 * smoothstep(0., .46, t)
	)
	var radi = .58 + float(lane) * .135
	if settings.kind == "cast":
		radi = .15 + float(lane) * .04
		contract = 1.
	var rotation = t * (.95 if settings.kind != "departure" else -1.15)
	var length = 1.08 + float(lane) * .12
	if settings.kind == "bond":
		radi *= 1. + smoothstep(.12, .60, t) * .25
		length *= 1. - smoothstep(.17, .63, t) * .7
	for k in range(steps + 1):
		var u = float(k) / steps
		var theta = base + rotation + u * length
		var radius = radi * contract * (1. + .07 * sin(u * 5. + float(lane)))
		var h = .05 + (float(lane) * .18 + u * .55) * smoothstep(.05, .52, t)
		if settings.kind == "departure":
			h = .13 + (.30 + u * .76) * (1. - smoothstep(.62, 1.34, t))
		if settings.kind == "cast":
			h = (u - .5) * .27
		if settings.kind == "bond":
			h = .4 + u * .30
		var width = (.07 + float(lane) * .023) * pow(sin(u * PI), .55)
		if settings.kind == "cast":
			width *= .70
		for edge in [-1., 1.]:
			vertices.append(Vector3(cos(theta) * radius, h + edge * width, sin(theta) * radius))
	return vertices


func _ribbon_mesh(j: int,t: float) -> ArrayMesh:
	var steps:=28
	var vertices:=ribbon_vertices(j,t)
	var uv:=PackedVector2Array()
	var indices:=PackedInt32Array()
	for k in steps+1:
		var u:=float(k)/float(steps)
		for edge in [-1.,1.]:uv.append(Vector2(u,(edge+1.)*.5))
		if k<steps:
			var o:=k*2
			indices.append_array(PackedInt32Array([o,o+1,o+2,o+1,o+3,o+2]))
	var arr = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = vertices
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_INDEX] = indices
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh


func set_age(t: float):
	time = t
	var envelope = _envelope(t)
	if ground:
		ground.visible = side in ["ground", "full"]
		var pulse = .4 + .6 * smoothstep(0., .30, t)
		if settings.kind == "departure":
			pulse = 1. - smoothstep(.25, 1.30, t) * .78
		ground.scale = Vector3(pulse, 1., pulse)
		ground.material_override.set_shader_parameter("age", t)
		ground.material_override.set_shader_parameter("strength", envelope * .78)
	for j in range(ribbons.size()):
		var n = ribbons[j]
		n.visible = side != "ground"
		n.mesh = _ribbon_mesh(j, t)
		n.material_override.set_shader_parameter("age", t)
		n.material_override.set_shader_parameter(
			"strength", envelope * (.55 if settings.kind == "bond" else .83)
		)
	for j in range(motes.size()):
		var n = motes[j]
		n.visible = side != "ground"
		var sector = j / 8 if settings.kind != "cast" else j / 4
		var seed = j % 8 if settings.kind != "cast" else j % 4
		var delay = float(seed) * .037
		var life = clampf((t - delay) / 1.1, 0., 1.)
		var theta = float(sector) * PI / 2. + float(seed) * .18 + t * .9
		var radius = (.40 + float(seed) * .065) * (1. + life * .28)
		var height = .03 + life * (.72 + float(seed) * .08)
		if settings.kind == "departure":
			radius *= 1. - smoothstep(.24, 1.3, t) * .8
			height = .13 + (1. - life) * (.4 + float(seed) * .09)
		if settings.kind == "cast":
			radius = .10 + life * .20
			height = (float(seed) - 1.5) * .055 + sin(life * PI) * .15
		if settings.kind == "bond":
			radius *= 1. + life * .45
			height = .35 + life * .45
		n.position = Vector3(cos(theta) * radius, height, sin(theta) * radius)
		var q = float(settings.camera_quadrant) * PI / 2.
		n.rotation = Vector3(-PI / 6., PI / 4. - q, 0.)
		var s = .35 + float(seed % 3) * .18
		n.scale = Vector3(s, s, s)
		n.material_override.set_shader_parameter(
			"strength", envelope * (.55 + float(seed % 3) * .12)
		)

const VfxPackageIO_28b0b8f827 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
