extends "res://assets/vfx/sources/a4fd0883f0b17d893a03/base.gd"
## Native accepted source functions; capture and finishing belong to the shared exporter.
const SourceMaterials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/295f0e2f696ad8615b61/hypnotic_ground.gd", input)


func prepare_materials(_node: Node) -> void:
	pass


var ground_mat: ShaderMaterial
var spark_mat: ShaderMaterial
var sparks: Array[MeshInstance3D] = []


func apply_scene_edits(node: Node) -> void:
	subject = node
	for child in node.get_children():
		child.queue_free()
	ground_mat = ShaderMaterial.new()
	var sh = Shader.new()
	sh.code = (
		"""shader_type spatial;
render_mode unshaded,cull_disabled;
uniform float clock=0.;uniform bool rosette=false;
varying vec3 wp;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void vertex(){wp=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
void fragment(){
	FRONT_DISCARD
	vec2 p=wp.xz;float r=length(p);float angle=atan(p.y,p.x);float sq=max(abs(p.x),abs(p.y));
	float boundary=1.-smoothstep(4.7,5.3,r);
	float n=noise(p*2.7+vec2(clock*.45,-clock*.30));
	float phase=angle*2.+r*3.1-clock*2.3;
	float dist=abs(sin(phase*.5));
	float main=1.-smoothstep(.16,.38,dist+.018*(n-.5));
	float hair=1.-smoothstep(.02,.07,abs(sin(phase*.5+.26)));
	float inner=1.-smoothstep(.05,.19,r);
	float advancing=1.-smoothstep(clock*7.,clock*7.+.7,r);
	float pulse=exp(-pow((r-clock*7.)/.30,2.));
	float texture=.78+.22*noise(vec2(r*3.-clock*.5,angle*3.));
	float env=smoothstep(0.,.15,clock)*(1.-smoothstep(1.85,2.65,clock));
	float interference=0.;
	float power=max(inner,main*texture)*advancing;
	if(rosette){
		float blend=.5+.5*sin(clock*1.6);
		float a=pow(max(0.,cos(angle*10.+r*1.7)),3.);
		float b=pow(max(0.,cos(angle*10.+r*1.7+.9)),3.);
		float annulus=smoothstep(.8,1.9,r)*(1.-smoothstep(4.6,5.3,r));
		power=mix(a,b,blend)*annulus*.64;
		env=smoothstep(0.,.3,clock)*(1.-smoothstep(1.5,2.2,clock));
	}
	float coverage=boundary*env*power;
	if(coverage<.14)discard;
	float hot=smoothstep(.4,.90,power);
	vec3 col=mix(vec3(.61,.16,.25),vec3(.96,.40,.51),hot);
	col=mix(col,vec3(1.,.75,.43),.35*pow(.5+.5*sin(r*1.2-clock*.7),3.));
	col=mix(col,vec3(1.,.89,.77),smoothstep(.65,.98,power*boundary));
	if(rosette)col=mix(vec3(.47,.32,.37),vec3(.71,.47,.51),power);
	ALBEDO=pow(col,vec3(2.2));ALPHA=rosette?.45:(coverage>.38?1.:.75);
}
"""
		. replace("FRONT_DISCARD", "discard;" if side == "front" else "")
	)
	ground_mat.shader = sh
	ground_mat.set_shader_parameter("rosette", settings.get("rosette", false))
	var plane = MeshInstance3D.new()
	var mesh = PlaneMesh.new()
	mesh.size = Vector2(11.3137, 11.3137)
	plane.mesh = mesh
	plane.position.y = .025
	plane.material_override = ground_mat
	subject.add_child(plane)
	spark_mat = ShaderMaterial.new()
	var ss = Shader.new()
	ss.code = (
		"""shader_type spatial;
render_mode unshaded,cull_disabled;
uniform float opacity=0.;varying vec3 wp;
void vertex(){wp=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
void fragment(){if(dot(wp,vec3(0.70710678,0.0,0.70710678)) side_TEST 0.)discard;ALBEDO=vec3(.55,.80,.90);ALPHA=opacity;}
"""
		. replace("side_TEST", "<" if side == "front" else ">=")
	)
	spark_mat.shader = ss
	var diamond = PrismMesh.new()
	diamond.size = Vector3(.032, .16, .022)
	for i in range(0):
		var spark = MeshInstance3D.new()
		spark.mesh = diamond
		spark.material_override = spark_mat
		subject.add_child(spark)
		sparks.append(spark)


func advance_lifecycle(_delta: float) -> void:
	if not is_instance_valid(subject):
		return
	tick += 1
	var t = float(tick) / float(parameters.simulation_hz)
	ground_mat.set_shader_parameter("clock", t)
	spark_mat.set_shader_parameter(
		"opacity", smoothstep(.25, .55, t) * (1. - smoothstep(1.1, 1.9, t))
	)
	for i in range(sparks.size()):
		var seed = float(i)
		var a = seed * 2.39996
		var radius = 1. + fmod(seed * 1.618, 4.2)
		var age = maxf(0., t - .30)
		var x = cos(a) * radius
		var z = sin(a) * radius
		sparks[i].position = Vector3(x, .1 + age * (.6 + fmod(seed * .31, .7)), z)
		sparks[i].rotation = Vector3(sin(a) * .65, 0, cos(a) * .65)
