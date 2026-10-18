extends "res://assets/vfx/sources/a4fd0883f0b17d893a03/base.gd"
## Native accepted source functions; capture and finishing belong to the shared exporter.
const SourceMaterials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/6c106d89a2f0064b1111/dread_veil.gd", input)


func prepare_materials(_node: Node) -> void:
	pass


var particles: Array[GPUParticles3D] = []
var symbol: ShaderMaterial
var veil: MeshInstance3D


func apply_scene_edits(node: Node) -> void:
	var donor = VfxPackageIO_6c106d89a2.resource(settings.particle_scene).instantiate()
	var p = donor.get_node("Aura").duplicate()
	node.add_child(p)
	donor.free()
	p.position = Vector3(0, .7, 0)
	p.fixed_fps = 144
	p.use_fixed_seed = true
	p.seed = 7331
	ResourceGraph.isolate_node(p, {})
	p.process_material = p.process_material.duplicate(true)
	p.material_override = p.material_override.duplicate(true)
	p.amount = 12
	p.lifetime = 1.15
	p.randomness = .45
	p.explosiveness = .0
	p.process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	p.process_material.emission_box_extents = Vector3(.36, .42, .22)
	p.process_material.scale_min = .28
	p.process_material.scale_max = .58
	p.process_material.gravity = Vector3(0, .18, 0)
	p.process_material.initial_velocity_min = .05
	p.process_material.initial_velocity_max = .18
	if settings.kind == "fear_wave":
		p.position = Vector3(0, .75, 0)
		p.amount = 80
		p.lifetime = 1.4
		p.explosiveness = .35
		p.process_material.direction = Vector3(0, 0, 1)
		p.process_material.spread = 28.
		p.process_material.initial_velocity_min = 3.0
		p.process_material.initial_velocity_max = 4.8
		p.process_material.scale_min = .65
		p.process_material.scale_max = 1.15
		p.process_material.gravity = Vector3(0, .06, 0)
	elif settings.kind == "frightened":
		p.position.y = 1.05
		p.amount = 9
		p.process_material.scale_min = .22
		p.process_material.scale_max = .40
	elif settings.kind == "eyebite":
		p.position.y = 1.8
		p.amount = 8
		p.process_material.emission_box_extents = Vector3(.24, .18, .12)
	elif settings.kind == "gaze_hit":
		p.position.y = .95
		p.amount = 24
		p.explosiveness = .75
		p.one_shot = true
		p.lifetime = .8
		p.process_material.scale_min = .4
		p.process_material.scale_max = .7
		p.process_material.radial_velocity_min = -.4
		p.process_material.radial_velocity_max = -.15
	p.material_override.set_shader_parameter("primary_color", Color.WHITE)
	p.material_override.set_shader_parameter("secondary_color", Color(.6, .6, .6))
	p.material_override.set_shader_parameter("tertiary_color", Color(.15, .15, .15))
	p.material_override.set_shader_parameter("hue_variation", 0.)
	p.material_override.set_shader_parameter("emission", 1.6)
	p.material_override.set_shader_parameter("shape_curve", .8)
	p.material_override.set_shader_parameter("proximity_fade", false)
	adapt(p.material_override)
	p.emitting = true
	p.restart()
	particles.append(p)
	if settings.kind == "eyebite":
		var mark = MeshInstance3D.new()
		var mesh = QuadMesh.new()
		mesh.size = Vector2(.76, .66)
		mark.mesh = mesh
		node.add_child(mark)
		mark.position = Vector3(0, 1.92, 0)
		var sx = [1., 1., -1., -1.][int(settings.cameraQuarter)]
		var sz = [1., -1., -1., 1.][int(settings.cameraQuarter)]
		mark.look_at(
			mark.global_position + Vector3(12 * sx, 9.797958971, 12 * sz), Vector3.UP, true
		)
		symbol = ShaderMaterial.new()
		var shader = Shader.new()
		if settings.kind == "eyebite":
			shader.code = VfxPackageIO_6c106d89a2.text("res://assets/vfx/sources/521592138b9078f1fd6f/dread_eye.gdshader")
		else:
			shader.code = GLYPH
		symbol.shader = shader
		symbol.set_shader_parameter(
			"kind", 1 if settings.kind == "eyebite" else 0 if settings.kind == "frightened" else 1
		)
		symbol.set_shader_parameter(
			"source_noise", p.material_override.get_shader_parameter("noise_texture")
		)
		mark.material_override = symbol
		if side == "back":
			mark.layers = 0
	if settings.kind in ["fear_wave", "frightened", "sickened"]:
		veil = MeshInstance3D.new()
		veil.mesh = make_veil()
		node.add_child(veil)
		var mat = ShaderMaterial.new()
		var sh = Shader.new()
		sh.code = VEIL
		mat.shader = sh
		mat.set_shader_parameter(
			"source_noise", p.material_override.get_shader_parameter("noise_texture")
		)
		mat.set_shader_parameter("wave", settings.kind == "fear_wave")
		adapt(mat)
		veil.material_override = mat
		if settings.kind == "fear_wave":
			p.amount = 36
		else:
			p.amount = 6


func make_veil() -> ArrayMesh:
	var vertices = PackedVector3Array()
	var uvs = PackedVector2Array()
	var indices = PackedInt32Array()
	var wave = settings.kind == "fear_wave"
	for j in range(13):
		var v = float(j) / 12.
		for i in range(65):
			var u = float(i) / 64.
			var angle = (u - .5) * .927295 if wave else u * TAU
			var y = v * (1.25 if wave else .78) + (.12 if wave else .45)
			y += .10 * sin(angle * 3. + .8) + .06 * cos(angle * 5.)
			if not wave:
				y += .13 * cos(angle * 2.) * v
			vertices.append(
				Vector3(sin(angle) * (1. if wave else .57), y, cos(angle) * (1. if wave else .40))
			)
			uvs.append(Vector2(u, v))
	for j in range(12):
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


const VEIL = """shader_type spatial;
render_mode unshaded,cull_disabled;
uniform sampler2D source_noise:repeat_enable,filter_linear;
uniform bool wave=false;
void vertex(){VERTEX.y+=sin(VERTEX.x*4.+TIME*3.)*.035;}
void fragment(){
	float n=texture(source_noise,UV*vec2(2.,1.7)+vec2(.10,-.16)*TIME).r;
	float n2=texture(source_noise,UV*vec2(4.,2.)+vec2(-.08,.08)*TIME).r;
	float lower=.10+.12*sin(UV.x*19.+n*2.);
	float upper=.66+.15*sin(UV.x*12.+n2*2.);
	float edge=smoothstep(lower,lower+.24,UV.y)*(1.-smoothstep(upper-.20,upper+.12,UV.y));
	if(wave)edge*=smoothstep(0.,.09,UV.x)*(1.-smoothstep(.91,1.,UV.x));
	float fold=.5+.5*sin(UV.x*24.+n*4.+TIME*1.5);
	float vein=.5+.5*sin(UV.x*13.+UV.y*8.+n*5.-TIME*2.);
	float value=.035+.30*pow(vein,4.)+.10*pow(fold,8.);
	float rim=exp(-pow((UV.y-(.70+.16*n))/.045,2.));
	ALBEDO=vec3(value+rim*.12);
	ALPHA=edge*(.12+.36*vein+rim*.10);
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
	if is_instance_valid(veil):
		if settings.kind == "fear_wave":
			var radius = clampf(age * 7., .1, 11.3)
			veil.scale = Vector3(radius, 1., radius)
		else:
			var pulse = 1. + .05 * sin(age * 2.5)
			veil.scale = Vector3(pulse, 1., pulse)
	var env = smoothstep(0., .2, age) * (1. - smoothstep(3.0, 3.75, age))
	if settings.kind == "fear_wave":
		for p in particles:
			p.emitting = age < .5
		env = 1. - smoothstep(1.7, 2.2, age)
	elif settings.kind == "gaze_hit":
		env = 1. - smoothstep(.5, 1.2, age)
	for mat in materials:
		mat.set_shader_parameter("support_clock", age)
		mat.set_shader_parameter("envelope", env)
	if symbol:
		symbol.set_shader_parameter("support_clock", age)
		symbol.set_shader_parameter("support_envelope", env)


const GLYPH = """shader_type spatial;
render_mode unshaded,cull_disabled;
uniform float support_clock=0.;uniform float support_envelope=1.;uniform int kind=0;
void fragment(){
	vec2 p=UV*2.-1.;p.x+=.017*sin(support_clock*15.);
	float head=1.-smoothstep(.55,.61,length(p*vec2(1.,.9)));
	float jaw=(1.-smoothstep(.30,.35,abs(p.x)))*(1.-smoothstep(.58,.65,p.y))*smoothstep(.16,.22,p.y);
	float eye1=1.-smoothstep(.13,.17,length(p-vec2(-.23,-.06)));
	float eye2=1.-smoothstep(.13,.17,length(p-vec2(.23,-.06)));
	float nose=(1.-smoothstep(.05,.075,abs(p.x)))*(1.-smoothstep(.11,.16,abs(p.y-.16)));
	float teeth=smoothstep(.31,.34,p.y)*(1.-smoothstep(.57,.61,p.y))*(1.-smoothstep(.025,.045,abs(sin(p.x*24.))));
	float shape=max(head,jaw)*(1.-max(max(eye1,eye2),max(nose,teeth)));
	if(kind==1){vec2 v=p-vec2(0.,.10);float drop=length(v*vec2(1.3,1.))-.40;shape=1.-smoothstep(.02,.06,abs(drop));shape=max(shape,(1.-smoothstep(.035,.06,abs(p.x+.14*sin(p.y*5.+support_clock*2.))))*(1.-smoothstep(.62,.70,abs(p.y))));}
	ALBEDO=vec3(.63+.2*sin(support_clock*2.+p.y*3.));ALPHA=shape*support_envelope;
}
"""

const VfxPackageIO_6c106d89a2 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
