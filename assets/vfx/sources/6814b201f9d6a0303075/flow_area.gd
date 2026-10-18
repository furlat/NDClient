extends Node3D
## A soft spatial flow area. Selected textures/palette stay explicit recipe data.
var material: ShaderMaterial
var duration: float = 4.5

static func make_component(input: Dictionary) -> Node3D:
	var node := VfxPackageIO_6814b201f9.resource("res://assets/vfx/sources/6814b201f9d6a0303075/flow_area.gd").new() as Node3D
	node.duration = float(input.get("seconds", 4.5))
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform sampler2D flow_noise : repeat_enable, filter_linear;
uniform vec4 deep : source_color;
uniform vec4 energy : source_color;
uniform float clock = 0.;
uniform float envelope = 1.;
uniform float emission_strength = .14;
uniform float opacity_scale = 1.;
uniform bool ambient_shadow = false;
void fragment(){
 vec2 p=(UV-.5)*2.;
 float radius=length(p);
 float angle=atan(p.y,p.x);
 vec2 flow=vec2(angle/6.28318*3.-clock*.09,radius*1.4-clock*.025);
 if(ambient_shadow)flow=UV*2.2+vec2(clock*.018,-clock*.012);
 float n=texture(flow_noise,flow).r;
 float n2=texture(flow_noise,UV*2.2+vec2(clock*.03,-clock*.02)).r;
 float area=(1.-smoothstep(.82,.99,radius))*(.09+.20*n*n2);
 float current=smoothstep(.24,.72,n)*(.3+.7*smoothstep(.1,.9,radius));
 ALBEDO=mix(deep.rgb,energy.rgb,current);
 EMISSION=energy.rgb*current*emission_strength;
 ALPHA=area*envelope*opacity_scale;
}"""
	node.material = ShaderMaterial.new()
	node.material.shader = shader
	node.material.set_shader_parameter("flow_noise",VfxPackageIO_6814b201f9.resource(input.texture))
	node.material.set_shader_parameter("deep",Color(input.deep))
	node.material.set_shader_parameter("energy",Color(input.energy))
	node.material.set_shader_parameter("emission_strength",float(input.get("emission_strength",.14)))
	node.material.set_shader_parameter("opacity_scale",float(input.get("opacity_scale",1.)))
	node.material.set_shader_parameter("ambient_shadow",input.get("ambient_shadow",false))
	var plane := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2.ONE * float(input.get("diameter", 6.0))
	plane.mesh = mesh
	plane.material_override = node.material
	plane.position.y = .025
	plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(plane)
	return node

func sample(seconds: float) -> void:
	material.set_shader_parameter("clock",seconds)
	material.set_shader_parameter("envelope",smoothstep(0.,.3,seconds)*(1.-smoothstep(duration-.3,duration,seconds)))

const VfxPackageIO_6814b201f9 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
