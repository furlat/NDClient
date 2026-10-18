extends "res://assets/vfx/sources/a4fd0883f0b17d893a03/base.gd"
## Native accepted source functions; capture and finishing belong to the shared exporter.
const SourceMaterials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/c20c9bb74249d40950f7/eyebite_directed.gd", input)


func prepare_materials(_node: Node) -> void:
	pass


var eye: MeshInstance3D
var eye_mat: ShaderMaterial
var viewdir: Vector3
var target: Vector3


func apply_scene_edits(node: Node) -> void:
	target = Vector3(settings.target[0], 1.02, settings.target[1])
	var sx = [1., 1., -1., -1.][int(settings.cameraQuarter)]
	var sz = [1., -1., -1., 1.][int(settings.cameraQuarter)]
	viewdir = Vector3(12 * sx, 9.797958971, 12 * sz).normalized()
	var noise = VfxPackageIO_c20c9bb742.resource(settings.noise_resource).duplicate(true)
	eye = MeshInstance3D.new()
	var quad = QuadMesh.new()
	quad.size = Vector2(.76, .66)
	eye.mesh = quad
	node.add_child(eye)
	eye.position = Vector3(0, 1.92, 0)
	eye_mat = ShaderMaterial.new()
	var sh = Shader.new()
	var code = VfxPackageIO_c20c9bb742.text("res://assets/vfx/sources/521592138b9078f1fd6f/dread_eye.gdshader")
	code = code.replace("uniform int kind=0;", "uniform int kind=0; uniform float aim=0.;")
	code = code.replace("float r=length(p);", "float r=length(p-vec2(aim,0.));")
	code = code.replace("abs(p.x)))*(1.0-smoothstep(.23", "abs(p.x-aim)))*(1.0-smoothstep(.23")
	sh.code = code
	eye_mat.shader = sh
	eye_mat.set_shader_parameter("kind", 1)
	eye_mat.set_shader_parameter("source_noise", noise)
	eye.material_override = eye_mat
	if side == "back":
		eye.layers = 0
	var vertices = PackedVector3Array()
	var uv = PackedVector2Array()
	var indices = PackedInt32Array()
	var start = Vector3(0, 1.92, 0)
	var tangent = (target - start).normalized()
	var width = tangent.cross(viewdir).normalized()
	for j in range(129):
		var u = float(j) / 128.
		var center = start.lerp(target, u) + Vector3(0, sin(u * PI) * .45, 0)
		for side in [-1., 1.]:
			vertices.append(center + width * side * .19)
			uv.append(Vector2(u, (side + 1.) / 2.))
	for j in range(128):
		var a = j * 2
		indices.append_array(PackedInt32Array([a, a + 1, a + 2, a + 1, a + 3, a + 2]))
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var link = MeshInstance3D.new()
	link.mesh = mesh
	node.add_child(link)
	var mat = ShaderMaterial.new()
	sh = Shader.new()
	sh.code = LINK
	mat.shader = sh
	mat.set_shader_parameter("source_noise", noise)
	adapt(mat)
	link.material_override = mat


const LINK = """shader_type spatial;
render_mode unshaded,cull_disabled;
uniform sampler2D source_noise:repeat_enable,filter_linear;
void fragment(){
	float progress=clamp((TIME-.30)/1.13,0.,1.);
	float n=texture(source_noise,UV*vec2(8.,2.)+vec2(-TIME*.7,0.)).r;
	float along=progress-UV.x;
	float head=exp(-pow(along/.065,2.));
	float tail=smoothstep(-.015,.025,along)*(1.-smoothstep(.12,.42,along));
	float bend=.12*sin(UV.x*34.-TIME*12.+n*3.);
	float crosswise=abs(UV.y-.5-bend);
	float core=1.-smoothstep(.08,.25,crosswise);
	float split=1.-smoothstep(.025,.08,abs(crosswise-.28));
	float onset=smoothstep(.25,.36,TIME)*(1.-smoothstep(1.40,1.50,TIME));
	ALBEDO=vec3(.13+.56*head+.26*core*n);
	ALPHA=max(core*(head+tail*.70),split*tail*.40)*onset;
}
"""


func adapt(mat: ShaderMaterial) -> void:
	var code = mat.shader.code.replace("TIME", "support_clock").replace(
		"void fragment(){", "void fragment() {"
	)
	code = code.replace(
		"shader_type spatial;",
		"shader_type spatial;\nuniform float support_clock=0.;\nuniform float envelope=1.;"
	)
	var at = code.find("void fragment() {") + "void fragment() {".length()
	code = (
		code
		. insert(
			at,
			(
				"\nvec3 wp=(INV_VIEW_MATRIX*vec4(VERTEX,1.)).xyz; if(dot(wp,vec3(0.70710678,0.0,0.70710678)) "
				+ ("<" if side == "front" else ">=")
				+ " 0.)discard;\n"
			)
		)
	)
	var last = code.rfind("}")
	code = code.insert(last, "\nALPHA *= envelope;\n")
	code = code.replace("vec3(0.70710678,0.0,0.70710678)", settings.clip_vector)
	var sh = Shader.new()
	sh.code = code
	mat.shader = sh
	materials.append(mat)


func advance_lifecycle(_delta: float) -> void:
	tick += 1
	var age = float(tick) / float(parameters.simulation_hz)
	var turn = smoothstep(.0, .32, age) * (1. - smoothstep(1.12, 1.5, age))
	if eye:
		var towards = (target - eye.position).normalized()
		var normal = viewdir.lerp(towards, .34 * turn).normalized()
		eye.look_at(eye.global_position + normal, Vector3.UP, true)
		var right = Vector3(viewdir.z, 0, -viewdir.x).normalized()
		eye_mat.set_shader_parameter("aim", towards.dot(right) * .20 * turn)
		eye_mat.set_shader_parameter("support_clock", age + .7)
		eye_mat.set_shader_parameter("support_envelope", 1.)
	for mat in materials:
		mat.set_shader_parameter("support_clock", age)
		mat.set_shader_parameter("envelope", 1.)

const VfxPackageIO_c20c9bb742 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
