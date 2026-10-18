extends "res://assets/vfx/sources/a4fd0883f0b17d893a03/base.gd"


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/c46349e9940eb950454c/spirit_piece.gd", input)


func prepare_materials(_node: Node) -> void:
	pass


func apply_scene_edits(node: Node) -> void:
	subject = node
	subject.scale.y = .81649658
	var m = material(settings.kind == "necrotic")
	if settings.kind == "radiant":
		bird(m)
	else:
		imp(m)


func advance_lifecycle(_d: float) -> void:
	tick += 1
	var frame = maxi(0, int(floor(float(tick - 1) * 32. / float(parameters.simulation_hz))))
	var phase = float(frame % 16) / 16.
	for j in range(2):
		var wing_side = -1 if j == 0 else 1
		if settings.kind == "radiant":
			wings[j].rotation.z = wing_side * (.15 + .6 * sin(phase * TAU))
		else:
			wings[j].rotation.y = wing_side * (.12 + .47 * sin(phase * TAU))
	for m in mats:
		m.set_shader_parameter("clock", phase)


var wings: Array[Node3D] = []
var mats: Array[ShaderMaterial] = []
const CELL = 160
const COUNT = 16


func material(necro: bool, strength: float = 1.0) -> ShaderMaterial:
	var sh = Shader.new()
	sh.code = """shader_type spatial;
render_mode unshaded,cull_disabled;
uniform vec3 dark_tone; uniform vec3 mid_tone; uniform vec3 light_tone;
uniform float clock=0.; uniform float strength=1.;
varying vec3 local;
void vertex(){local=VERTEX;}
void fragment(){
	float rim=pow(1.-abs(dot(normalize(NORMAL),normalize(VIEW))),1.7);
	float lit=clamp(dot(normalize(NORMAL),normalize(vec3(-.35,.8,.5)))*.38+.45,0.,1.);
	float vein=pow(.5+.5*sin(local.x*24.+local.z*17.+clock*6.28318),16.);
	float energy=clamp(lit*.6+rim*.55+vein*.13,0.,1.);
	vec3 c=mix(dark_tone,mid_tone,smoothstep(.05,.55,energy));
	c=mix(c,light_tone,smoothstep(.56,.92,energy));
	ALBEDO=c; EMISSION=c*.14*strength;
	float lace=.5+.22*sin(local.x*31.+local.y*19.+clock*6.28318)+.22*sin(local.z*33.-local.y*21.-clock*12.56636);
	ALPHA=(.26+rim*.70)*smoothstep(.12,.58,lace);
}"""
	var m = ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("dark_tone", Vector3(.08, .34, .30) if necro else Vector3(.48, .32, .10))
	m.set_shader_parameter("mid_tone", Vector3(.22, .79, .65) if necro else Vector3(.99, .79, .41))
	m.set_shader_parameter("light_tone", Vector3(.64, 1., .83) if necro else Vector3(1., .94, .73))
	m.set_shader_parameter("strength", strength)
	mats.append(m)
	return m


func mesh_obj(
	parent: Node3D, mesh: Mesh, pos: Vector3, scale_v: Vector3, m: Material
) -> MeshInstance3D:
	var o = MeshInstance3D.new()
	o.mesh = mesh
	o.material_override = m
	o.position = pos
	o.scale = scale_v
	parent.add_child(o)
	return o


func ell(parent: Node3D, pos: Vector3, scale_v: Vector3, m: Material) -> MeshInstance3D:
	var b = SphereMesh.new()
	b.radius = .5
	b.height = 1.
	b.radial_segments = 16
	b.rings = 8
	return mesh_obj(parent, b, pos, scale_v, m)


func bone(parent: Node3D, a: Vector3, b: Vector3, r: float, m: Material) -> void:
	var cylinder = CylinderMesh.new()
	cylinder.top_radius = r * .7
	cylinder.bottom_radius = r
	cylinder.height = a.distance_to(b)
	cylinder.radial_segments = 8
	var o = mesh_obj(parent, cylinder, (a + b) * .5, Vector3.ONE, m)
	var axis = (b - a).normalized()
	o.quaternion = Quaternion(Vector3.UP, axis)


func tip(parent: Node3D, a: Vector3, b: Vector3, r: float, m: Material) -> void:
	var cone = CylinderMesh.new()
	cone.top_radius = 0
	cone.bottom_radius = r
	cone.height = a.distance_to(b)
	cone.radial_segments = 8
	var o = mesh_obj(parent, cone, (a + b) * .5, Vector3.ONE, m)
	o.quaternion = Quaternion(Vector3.UP, (b - a).normalized())


func bird(m: Material) -> void:
	ell(subject, Vector3(0, 0, 0), Vector3(.16, .17, .61), m)
	ell(subject, Vector3(0, .12, -.28), Vector3(.15, .17, .22), m)
	tip(subject, Vector3(0, .10, -.36), Vector3(0, .03, -.57), .034, m)
	var src = JSON.parse_string(
		VfxPackageIO_c46349e994.text("res://assets/vfx/sources/847ae293b3e1ff06da9e/wing-mesh.json")
	)
	for side in [-1, 1]:
		var pivot = Node3D.new()
		subject.add_child(pivot)
		pivot.position = Vector3(side * .065, .035, -.025)
		wings.append(pivot)
		var st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for v in src.vertices:
			# Feather donor spans x/y; lay it horizontally, with feather tips behind shoulders.
			st.add_vertex(
				Vector3(
					side * float(v[0]) * .69,
					float(v[2]) * .69,
					float(v[1]) * .62 + float(v[0]) * .27 - .17
				)
			)
		st.generate_normals()
		mesh_obj(pivot, st.commit(), Vector3.ZERO, Vector3.ONE, m)
	for side in [-1, 0, 1]:
		tip(subject, Vector3(side * .025, -.015, .20), Vector3(side * .085, -.035, .78), .032, m)


func imp(m: Material) -> void:
	ell(subject, Vector3(0, 0, 0), Vector3(.28, .4, .19), m)
	ell(subject, Vector3(0, .29, -.015), Vector3(.21, .23, .18), m)
	ell(subject, Vector3(0, .23, -.12), Vector3(.15, .09, .11), m)
	for side in [-1, 1]:
		tip(subject, Vector3(side * .06, .36, 0), Vector3(side * .125, .55, .055), .043, m)
		tip(subject, Vector3(side * .08, .30, 0), Vector3(side * .23, .35, 0), .052, m)
		bone(subject, Vector3(side * .09, -.12, 0), Vector3(side * .15, -.3, -.09), .048, m)
		bone(subject, Vector3(side * .15, -.3, -.09), Vector3(side * .15, -.45, .045), .031, m)
		tip(subject, Vector3(side * .15, -.45, .045), Vector3(side * .15, -.47, -.08), .033, m)
		bone(subject, Vector3(side * .1, .1, 0), Vector3(side * .25, -.035, -.015), .032, m)
		bone(subject, Vector3(side * .25, -.035, -.015), Vector3(side * .29, -.14, -.13), .022, m)
		for j in range(3):
			tip(
				subject,
				Vector3(side * (.28 + j * .016), -.13, -.13),
				Vector3(side * (.29 + j * .024), -.22, -.15),
				.009,
				m
			)
		var pivot = Node3D.new()
		subject.add_child(pivot)
		pivot.position = Vector3(side * .10, .13, .04)
		wings.append(pivot)
		var pts = [
			Vector3(0, 0, 0),
			Vector3(side * .31, .30, .06),
			Vector3(side * .67, .12, .15),
			Vector3(side * .47, -.015, .12),
			Vector3(side * .45, -.26, .17),
			Vector3(side * .23, -.12, .11),
			Vector3(side * .10, -.30, .04)
		]
		var st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in range(1, pts.size() - 1):
			for v in [pts[0], pts[i], pts[i + 1]]:
				st.add_vertex(v)
		st.generate_normals()
		mesh_obj(pivot, st.commit(), Vector3.ZERO, Vector3.ONE, m)
		for i in [1, 2, 4, 6]:
			bone(pivot, pts[0], pts[i], .014, m)
	var a = Vector3(0, -.15, .07)
	for i in range(1, 13):
		var t = float(i) / 12.
		var b = Vector3(.16 * sin(t * PI), -.15 - .37 * t, .07 + .35 * t)
		bone(subject, a, b, .018 * (1. - t * .6), m)
		a = b
	tip(subject, a, a + Vector3(-.045, -.05, .09), .035, m)

const VfxPackageIO_c46349e994 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
