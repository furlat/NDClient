extends "res://assets/vfx/sources/a4fd0883f0b17d893a03/base.gd"
## Native accepted source functions; capture and finishing belong to the shared exporter.
const SourceMaterials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/628326bc47127477d83b/hold.gd", input)


func prepare_materials(_node: Node) -> void:
	pass


var data: Dictionary
var links: Array[MeshInstance3D] = []
var mats: Array[ShaderMaterial] = []
var count = 0
var sparks: Array[MeshInstance3D] = []
var debris: Array[MeshInstance3D] = []
var convert = Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0))


func material(gold: bool = false, role: int = 0) -> ShaderMaterial:
	var m = ShaderMaterial.new()
	var sh = Shader.new()
	sh.code = (
		"""shader_type spatial;
render_mode unshaded,cull_disabled;
uniform int role=0;uniform float height=1.;uniform float opacity=1.;uniform float clock=0.;uniform bool gold=false;
varying vec3 world;varying vec3 normal_world;
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;normal_world=normalize(mat3(MODEL_MATRIX)*NORMAL);}
void fragment(){
	if(dot(world,vec3(0.70710678,0.0,0.70710678)) side_TEST 0.)discard;
	float reveal=clamp((clock-.65)/.95,0.,1.)*(height+.20);
	if(role==0 && world.y>reveal)discard;
	float release=clamp((clock-4.65)/.85,0.,1.);
	if(role==0 && world.y> (height+.20)*(1.-release))discard;
	float angle=mod(atan(world.z,world.x)+6.2831853,1.5707963)/1.5707963;
	if(role==1 && (angle>clamp((clock-1.35)/.35,0.,1.) || angle<clamp((clock-4.3)/.35,0.,1.)))discard;
	float light=max(0.,dot(normalize(normal_world),normalize(vec3(-.4,.9,.5))));
	vec3 steel=mix(vec3(.06,.075,.09),vec3(.65,.70,.73),pow(light,.6));
	float pulse=pow(max(0.,sin(world.y*19.+clock*4.5)),14.);
	ALBEDO=mix(steel,vec3(1.,.68,.18),pulse*.9);
	if(gold)ALBEDO=mix(vec3(.55,.28,.06),vec3(1.,.78,.32),.55+.45*sin(clock*3.-world.y*10.));
	if(role==0 && abs(world.y-reveal)<.045)ALBEDO=vec3(1.,.84,.43);
	ALPHA=opacity;
}
"""
		. replace("side_TEST", "<" if side == "front" else ">=")
	)
	sh.code = sh.code.replace("vec3(0.70710678,0.0,0.70710678)", settings.clip_vector)
	m.shader = sh
	m.set_shader_parameter("role", role)
	m.set_shader_parameter("height", settings.beltHeight)
	m.set_shader_parameter("gold", gold)
	mats.append(m)
	return m


func apply_scene_edits(node: Node) -> void:
	subject = node
	for p in node.find_children("*", "AnimationPlayer", true, false):
		p.stop()
		p.active = false
	for child in node.get_children():
		child.queue_free()
	data = JSON.parse_string(VfxPackageIO_628326bc47.text(settings.physics_path))
	count = data.frames[0].size()
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for face in data.faces:
		for idx in [face[0], face[1], face[2], face[0], face[2], face[3]]:
			var v = data.vertices[idx]
			st.add_vertex(convert * Vector3(v[0], v[1], v[2]))
	st.generate_normals()
	var mesh = st.commit()
	var mat = material()
	for k in range(4):
		for j in range(count):
			var link = MeshInstance3D.new()
			link.mesh = mesh
			link.material_override = mat
			subject.add_child(link)
			links.append(link)
	# Visible waist band joins the four upper eyelets into one restraint.
	var belt = MeshInstance3D.new()
	var ring = TorusMesh.new()
	ring.inner_radius = settings.beltRadius - .02
	ring.outer_radius = settings.beltRadius + .02
	ring.rings = 48
	ring.ring_segments = 8
	belt.mesh = ring
	belt.position = Vector3(0, settings.beltHeight, 0)
	belt.material_override = material(false, 1)
	subject.add_child(belt)
	var gold = material(true, 2)
	var base_mat = material(false, 2)
	var debris_mat = material(true, 3)
	var plate = CylinderMesh.new()
	plate.top_radius = .15
	plate.bottom_radius = .16
	plate.height = .035
	plate.radial_segments = 6
	var eye = TorusMesh.new()
	eye.inner_radius = .043
	eye.outer_radius = .067
	eye.rings = 20
	eye.ring_segments = 8
	var engraving = TorusMesh.new()
	engraving.inner_radius = .192
	engraving.outer_radius = .210
	engraving.rings = 32
	engraving.ring_segments = 6
	var spark_mesh = SphereMesh.new()
	spark_mesh.radius = .023
	spark_mesh.height = .046
	spark_mesh.radial_segments = 6
	spark_mesh.rings = 3
	for k in range(4):
		var spin = Basis(Vector3.UP, float(k) * TAU / 4. + PI / 4.)
		var root = spin * Vector3(settings.anchorRadius, 0, 0)
		var base = MeshInstance3D.new()
		base.mesh = plate
		base.material_override = base_mat
		base.position = root + Vector3(0, .0175, 0)
		subject.add_child(base)
		var socket = MeshInstance3D.new()
		socket.mesh = eye
		socket.material_override = gold
		socket.transform = Transform3D(
			spin * Basis(Vector3.FORWARD, PI * .5), root + Vector3(0, .085, 0)
		)
		subject.add_child(socket)
		var seal = MeshInstance3D.new()
		seal.mesh = engraving
		seal.material_override = gold
		seal.position = root + Vector3(0, .009, 0)
		subject.add_child(seal)
		var mark_mesh = BoxMesh.new()
		mark_mesh.size = Vector3(.065, .014, .025)
		for a in range(4):
			var angle = float(a) * PI * .5
			var mark = MeshInstance3D.new()
			mark.mesh = mark_mesh
			mark.material_override = gold
			mark.position = root + Vector3(cos(angle) * .235, .012, sin(angle) * .235)
			mark.rotation.y = -angle
			subject.add_child(mark)
		for n in range(3):
			var mote = MeshInstance3D.new()
			mote.mesh = spark_mesh
			mote.material_override = gold
			subject.add_child(mote)
			sparks.append(mote)

	for i in range(4 * count * 3):
		var bit = MeshInstance3D.new()
		var shape = BoxMesh.new()
		shape.size = Vector3(.024, .035, .020)
		bit.mesh = shape
		bit.material_override = debris_mat
		subject.add_child(bit)
		debris.append(bit)


func advance_lifecycle(_delta: float) -> void:
	if not is_instance_valid(subject):
		return
	tick += 1
	var t = float(tick) / float(parameters.simulation_hz)
	var frame = mini(data.frames.size() - 1, int(t * 32.))
	for k in range(4):
		var spin = Basis(Vector3.UP, float(k) * TAU / 4. + PI / 4.)
		for j in range(count):
			var pose = data.frames[frame][j]
			var p = pose.position
			var q = pose.quaternion
			var b = convert * Basis(Quaternion(q[1], q[2], q[3], q[0])) * convert.inverse()
			links[k * count + j].transform = Transform3D(
				spin * b, spin * (convert * Vector3(p[0], p[1], p[2]))
			)
	var env = smoothstep(.35, .65, t) * (1. - smoothstep(5.65, 6.05, t))
	for mat in mats:
		mat.set_shader_parameter("opacity", env)
		mat.set_shader_parameter("clock", t)
	for k in range(4):
		var spin = Basis(Vector3.UP, float(k) * TAU / 4. + PI / 4.)
		for n in range(3):
			var phase = fmod(t * .65 + float(n) / 3., 1.)
			var u = (1. - phase) * float(count - 1)
			var a = mini(count - 2, int(u))
			var poses = data.frames[frame]
			var p = poses[a].position
			var q = poses[a + 1].position
			var point = Vector3(p[0], p[1], p[2]).lerp(Vector3(q[0], q[1], q[2]), u - a)
			sparks[k * 3 + n].position = spin * (convert * point + Vector3(0, 0, .065))
			sparks[k * 3 + n].visible = t > 1.65 and t < 4.3
			sparks[k * 3 + n].scale = Vector3.ONE * maxf(.001, sin(phase * PI))

	for i in range(debris.size()):
		var source = links[int(i / 3)].position
		var birth = 4.65 + (1. - clampf(source.y / (settings.beltHeight + .20), 0., 1.)) * .85
		var age = t - birth
		debris[i].visible = age > 0. and age < .55
		var angle = float(i) * 2.39996
		debris[i].position = (
			source
			+ Vector3(
				cos(angle) * .09 * age,
				maxf(-source.y + .02, .10 * age - 2.8 * age * age),
				sin(angle) * .09 * age
			)
		)
		debris[i].rotation = Vector3(age * 4., angle, age * 3.)

const VfxPackageIO_628326bc47 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
