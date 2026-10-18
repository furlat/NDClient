extends "res://assets/vfx/sources/a4fd0883f0b17d893a03/base.gd"


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/ef597adb81184ef7186b/spectral_guardian.gd", input)


func prepare_materials(_node: Node) -> void:
	pass


func apply_scene_edits(node: Node) -> void:
	subject = node
	subject.scale.y = .81649658
	build()


func advance_lifecycle(_d: float) -> void:
	tick += 1
	var frame = maxi(0, int(floor(float(tick - 1) * 32. / float(parameters.simulation_hz))))
	var strike = frame >= 64
	var t = (
		float(frame - 64) / 32.
		if strike
		else float(frame) / 64. * player.get_animation("Idle").length
	)
	sample_pose(strike, t)
	for m in materials:
		m.set_shader_parameter("clock", float(frame % 64) / 64.)


var model: Node3D
var player: AnimationPlayer
var skeleton: Skeleton3D
var sword: MeshInstance3D
var motions = []


func material(spectral: bool = false, light: bool = false) -> ShaderMaterial:
	var sh = Shader.new()
	sh.code = """shader_type spatial;
render_mode unshaded,cull_disabled;
uniform float clock=0.;uniform float ghost=0.;uniform float lightness=0.;varying vec3 local;
void vertex(){local=VERTEX;}
void fragment(){
	float rim=pow(1.-abs(dot(normalize(NORMAL),normalize(VIEW))),2.0);
	float lit=clamp(dot(normalize(NORMAL),normalize(vec3(-.4,.8,.6)))*.43+.48,0.,1.);
	float flow=pow(.5+.5*sin(local.y*17.+local.x*7.-clock*6.283185),14.);
	vec3 c=mix(vec3(.09,.09,.10),vec3(.71,.62,.42),lit);
	c=mix(c,vec3(1.,.92,.66),clamp(rim*.68+flow*.18+lightness*.4,0.,.85));
	ALBEDO=c;EMISSION=c*(.10+ghost*.16+lightness*.2);
	ALPHA=mix(1.,(.18+rim*.5+flow*.15)*smoothstep(-1.2,.2,local.y),ghost);
}"""
	var m = ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("ghost", 1. if spectral else 0.)
	m.set_shader_parameter("lightness", 1. if light else 0.)
	materials.append(m)
	return m


func mesh_at(
	parent: Node3D, mesh: Mesh, pos: Vector3, scale_v: Vector3, mat: Material
) -> MeshInstance3D:
	var o = MeshInstance3D.new()
	o.mesh = mesh
	o.material_override = mat
	parent.add_child(o)
	o.position = pos
	o.scale = scale_v
	return o


func ell(parent: Node3D, p: Vector3, s: Vector3, m: Material):
	var mesh = SphereMesh.new()
	mesh.radius = .5
	mesh.height = 1.
	mesh.radial_segments = 12
	mesh.rings = 6
	return mesh_at(parent, mesh, p, s, m)


func rod(parent: Node3D, a: Vector3, b: Vector3, r: float, m: Material):
	var mesh = CylinderMesh.new()
	mesh.top_radius = r * .82
	mesh.bottom_radius = r
	mesh.height = a.distance_to(b)
	mesh.radial_segments = 8
	var o = mesh_at(parent, mesh, (a + b) * .5, Vector3.ONE, m)
	o.quaternion = Quaternion(Vector3.UP, (b - a).normalized())
	return o


func plate(parent: Node3D, points: Array, pos: Vector3, thick: float, m: Material):
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Faceted raised centre, bevel perimeter, and full back face.
	var centre = Vector3.ZERO
	for p in points:
		centre += p
	centre /= points.size()
	centre.z -= thick
	for i in range(points.size()):
		var a = points[i]
		var b = points[(i + 1) % points.size()]
		for v in [
			centre,
			b,
			a,
			a,
			b,
			b + Vector3(0, 0, thick),
			a,
			b + Vector3(0, 0, thick),
			a + Vector3(0, 0, thick),
			centre + Vector3(0, 0, 2 * thick),
			a + Vector3(0, 0, thick),
			b + Vector3(0, 0, thick)
		]:
			st.add_vertex(v)
	st.generate_normals()
	return mesh_at(parent, st.commit(), pos, Vector3.ONE, m)


func descend(node: Node, metal: Material, glow: Material, ghost: Material):
	if node is AnimationPlayer:
		player = node
	if node is Skeleton3D:
		skeleton = node
	if node is MeshInstance3D:
		node.material_override = (
			ghost if "Cape" in node.name else (glow if "Sword" in node.name else metal)
		)
		if "Dark_Visor" in node.name:
			var dark = StandardMaterial3D.new()
			dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			dark.albedo_color = Color(.035, .045, .055)
			node.material_override = dark
		if node.name == "1H_Sword":
			sword = node
	for child in node.get_children():
		descend(child, metal, glow, ghost)


func build():
	var metal = material()
	var glow = material(false, true)
	var ghost = material(true)
	var doc = VfxPackageDocument_ef597adb81.new()
	var state = GLTFState.new()
	var err = doc.append_from_file(parameters.model, state)
	if err != OK:
		push_error("GLB load failed")
		return
	model = doc.generate_scene(state)
	subject.add_child(model)
	model.rotation.y = PI
	model.scale = Vector3(1.12, 1.51, 1.12)
	model.position.y = .88
	descend(model, metal, glow, ghost)
	print("ANIMATIONS ", player.get_animation_list())
	# The existing spectral lower silhouette is retained. No legs or boots.
	for i in range(9):
		var angle = TAU * float(i) / 9.
		var p = Vector3(cos(angle) * .23, 1.44, sin(angle) * .18)
		plate(subject, [Vector3(-.14, .14, 0), Vector3(.14, .14, 0), Vector3(.07, -.35, 0), Vector3(0, -1.10 - float(i % 3) * .06, 0), Vector3(-.08, -.35, 0)], p, .01, ghost).rotation.y = -angle


func sample_pose(strike: bool, t: float):
	var anim = "1H_Melee_Attack_Slice_Diagonal" if strike else "Idle"
	player.play(anim)
	player.seek(t, true)
	player.pause()
	# Keep the visor facing the recipient while the chest winds up and follows through.
	var head = skeleton.find_bone("head")
	var parent = skeleton.get_bone_parent(head)
	var desired = Basis(Vector3.RIGHT, .12) * skeleton.get_bone_global_rest(head).basis
	var local_basis = (
		skeleton.get_bone_rest(head).basis.inverse()
		* skeleton.get_bone_global_pose(parent).basis.inverse()
		* desired
	)
	skeleton.set_bone_pose_rotation(head, local_basis.orthonormalized().get_rotation_quaternion())
	skeleton.force_update_all_bone_transforms()

const VfxPackageDocument_ef597adb81 = preload("res://assets/vfx/sources/55f3fdb093ba9d7c2784/scene_document.gd")
