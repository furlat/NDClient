extends "res://assets/vfx/sources/a4fd0883f0b17d893a03/base.gd"
## Native accepted source functions; capture and finishing belong to the shared exporter.
const SourceMaterials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/7a3ca4045a81c94c5ca9/fear_path.gd", input)


func prepare_materials(_node: Node) -> void:
	pass


func apply_scene_edits(node: Node) -> void:
	var noise = VfxPackageIO_7a3ca4045a.resource(settings.noise_resource).duplicate(true)
	for trail in [false, true]:
		var mesh = MeshInstance3D.new()
		mesh.mesh = make_surface(trail)
		node.add_child(mesh)
		var mat = ShaderMaterial.new()
		var sh = Shader.new()
		sh.code = PATH if trail else CREST
		mat.shader = sh
		mat.set_shader_parameter("source_noise", noise)
		adapt(mat)
		mesh.material_override = mat


func make_surface(trail: bool) -> ArrayMesh:
	var vertices = PackedVector3Array()
	var uvs = PackedVector2Array()
	var indices = PackedInt32Array()
	for j in range(49):
		var v = float(j) / 48.
		for i in range(65):
			var u = float(i) / 64.
			var angle = (u - .5) * .927295
			var radius = v * 11.3 if trail else 1.
			vertices.append(Vector3(sin(angle) * radius, .06, cos(angle) * radius))
			uvs.append(Vector2(u, v))
	for j in range(48):
		for i in range(64):
			var a = j * 65 + i
			indices.append_array(PackedInt32Array([a, a + 1, a + 65, a + 1, a + 66, a + 65]))
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


const CREST = """shader_type spatial;
render_mode unshaded,cull_disabled;
uniform sampler2D source_noise:repeat_enable,filter_linear;
void vertex(){
	float radius=clamp(TIME*7.,.06,11.3);
	float a=(UV.x-.5)*.927295;
	float roll=UV.y*3.14159265;
	float r=max(.02,radius+.52*cos(roll));
	VERTEX=vec3(sin(a)*r,.08+sin(roll)*(1.25+.15*sin(a*11.+TIME*3.)),cos(a)*r);
}
void fragment(){
	float n=texture(source_noise,UV*vec2(3.,1.8)+vec2(.06,-.5)*TIME).r;
	float fold=.5+.5*sin(UV.x*32.+UV.y*9.+n*6.-TIME*4.);
	float edge=smoothstep(0.,.08,UV.x)*(1.-smoothstep(.92,1.,UV.x))*sin(UV.y*3.14159265);
	float ridge=pow(fold,4.);
	ALBEDO=vec3(.08+.42*ridge+.10*n);
	ALPHA=edge*(.42+.38*n)*(1.-smoothstep(1.9,2.8,TIME));
}
"""
const PATH = """shader_type spatial;
render_mode unshaded,cull_disabled;
uniform sampler2D source_noise:repeat_enable,filter_linear;
void vertex(){
	float arrival=UV.y*11.3/7.;
	float age=max(0.,TIME-arrival);
	VERTEX.y=.07+(.12+.10*sin(UV.x*22.+TIME*2.))*sin(UV.y*3.14159265)*exp(-age*.7);
}
void fragment(){
	float arrival=UV.y*11.3/7.;
	float age=TIME-arrival;
	float n=texture(source_noise,UV*vec2(3.,5.)+vec2(.025,-.22)*TIME).r;
	float n2=texture(source_noise,UV*vec2(5.,3.)+vec2(-.035,-.10)*TIME).r;
	float side=smoothstep(0.,.075,UV.x)*(1.-smoothstep(.925,1.,UV.x));
	float ends=smoothstep(.015,.09,UV.y)*(1.-smoothstep(.89,1.,UV.y));
	float onset=smoothstep(-.12,.13,age);
	float fade=1.-smoothstep(2.0,3.1,age);
	float stream=.5+.5*sin(UV.x*40.+n*5.+UV.y*4.);
	float curl=.5+.5*sin(UV.y*24.-TIME*3.+n2*5.);
	float strands=pow(stream,5.)*(.35+.65*curl);
	float edge=side*ends*onset*fade;
	ALBEDO=vec3(.035+.34*strands+.055*n);
	ALPHA=edge*(.26+.42*n+.18*strands);
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
	var env = smoothstep(0., .12, age) * (1. - smoothstep(3.8, 4.45, age))
	for mat in materials:
		mat.set_shader_parameter("support_clock", age)
		mat.set_shader_parameter("envelope", env)

const VfxPackageIO_7a3ca4045a = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
