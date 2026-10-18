extends "res://assets/vfx/sources/a4fd0883f0b17d893a03/base.gd"
## Native source authoring; shared stage, process clock, palette and capture.
const SourceMaterials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/f1203319eed2018b617b/pressure_front.gd", input)


func prepare_materials(_node: Node) -> void:
	pass


var shell: Node3D
var accent_mat: ShaderMaterial
var mat: ShaderMaterial


func apply_scene_edits(node: Node) -> void:
	subject = node
	for child in node.get_children():
		if child is VisualInstance3D:
			child.visible = false
		if child is AnimationPlayer:
			child.stop()
			child.active = false
	shell = Node3D.new()
	node.add_child(shell)
	# Both caps meet at local Z=0; source bounds +/-1 XY, 0..1 Z.
	var mesh = VfxPackageIO_f1203319ee.resource(
		"res://assets/vfx/sources/385a72edb2f4baa68f2f/sm_half_sphere.res"
	)
	mat = ShaderMaterial.new()
	var shader = Shader.new()
	shader.code = """shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, shadows_disabled;
uniform float opacity=0.0;
uniform bool front=true;
uniform float ground_y=0.0;
uniform float clock=0.0;
varying vec3 local_pos;
void vertex(){local_pos=VERTEX; VERTEX*=0.97+0.03*sin(VERTEX.x*17.0+VERTEX.y*13.0+VERTEX.z*11.0);}
void fragment(){
	vec3 world=(INV_VIEW_MATRIX*vec4(VERTEX,1.0)).xyz;
	if(world.y<ground_y)discard;
	float depth=dot(world,vec3(0.70710678,0.0,0.70710678));
	if(front && depth<0.0)discard;
	if(!front && depth>=0.0)discard;
	float edge=pow(1.0-abs(dot(normalize(NORMAL),normalize(VIEW))),2.2);
	vec3 p=normalize(world);
	float mask=sin(p.x*8.5+p.z*2.1+0.6)+0.55*sin(p.y*6.1-p.z*4.3+1.8);
	float arcs=smoothstep(-0.55,0.25,mask);
	float band=smoothstep(0.035,0.48,edge)*(0.35+0.65*arcs);
	float energy_path=abs(sin(p.x*10.0+p.y*7.0+p.z*8.0+sin(p.z*13.0)*1.3));
	float streak=1.0-smoothstep(0.045,0.16,energy_path);
	float irregular=0.6+0.4*sin(p.y*21.0+p.x*15.0+p.z*12.0+clock*19.0);
	float tear_progress=smoothstep(0.19,0.43,clock);
	float tear_field=sin(p.x*4.8+p.z*2.3+0.7)+0.62*sin(p.y*5.9-p.z*3.7+1.8);
	float tear=1.0-smoothstep(1.8-tear_progress*3.8,2.05-tear_progress*3.8,tear_field);
	float veil=0.15*arcs;
	float energy=max(band,streak*irregular*0.16);
	ALBEDO=vec3(0.48,0.30,0.76)+vec3(0.34,0.38,0.24)*energy;
	ALPHA=min(0.85,band*0.82+streak*irregular*0.08+veil)*opacity*tear;
}
"""
	mat.shader = shader
	mat.set_shader_parameter("front", side == "front")
	for i in range(2):
		var cap = MeshInstance3D.new()
		cap.mesh = mesh
		cap.material_override = mat
		if i == 1:
			cap.rotation.y = PI
		shell.add_child(cap)
	# Small solid-space compression glow with irregular broken opacity, not another ring.
	var accent = MeshInstance3D.new()
	var bulb = SphereMesh.new()
	bulb.radius = 1.10
	bulb.height = 2.0
	accent.mesh = bulb
	accent.position = Vector3(-0.08, 0.80, 0.05)
	accent_mat = ShaderMaterial.new()
	var glow = Shader.new()
	glow.code = """shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, shadows_disabled;
uniform float opacity=0.0;
uniform bool front=true;
varying vec3 local_pos;
void vertex(){local_pos=VERTEX;}
void fragment(){
	vec3 world=(INV_VIEW_MATRIX*vec4(VERTEX,1.0)).xyz;
	if(world.y<0.0)discard;
	float depth=dot(world,vec3(0.70710678,0.0,0.70710678));
	if(front && depth<0.0)discard;
	if(!front && depth>=0.0)discard;
	float irregular=0.45+0.4*sin(local_pos.x*4.7+0.2)*sin(local_pos.y*6.1-0.8)+0.35*sin(local_pos.z*7.1+1.1);
	float soft=pow(abs(dot(normalize(NORMAL),normalize(VIEW))),0.75);
	ALBEDO=vec3(0.46,0.26,0.75)+vec3(0.4,0.44,0.25)*max(0.0,irregular);
	ALPHA=soft*smoothstep(-0.3,0.65,irregular)*opacity;
}
"""
	accent_mat.shader = glow
	accent_mat.set_shader_parameter("front", side == "front")
	accent.material_override = accent_mat
	node.add_child(accent)


func advance_lifecycle(_delta: float) -> void:
	if not is_instance_valid(shell):
		return
	tick += 1
	var t = float(tick) / float(parameters.simulation_hz)
	# One pressure front: compact compression, rapid radial release, clean decay.
	accent_mat.set_shader_parameter(
		"opacity", 0.8 * smoothstep(0.0, 0.018, t) * (1.0 - smoothstep(0.065, 0.16, t))
	)
	var progress = clampf((t - 0.04) / 0.20, 0.0, 1.0)
	var radius = lerpf(0.85, 4.2426407, 1.0 - pow(1.0 - progress, 1.7))
	shell.scale = Vector3.ONE * radius
	var opacity = smoothstep(0.0, 0.008, t) * (1.0 - smoothstep(0.24, 0.48, t)) * 0.95
	mat.set_shader_parameter("opacity", opacity)
	mat.set_shader_parameter("clock", t)

const VfxPackageIO_f1203319ee = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
