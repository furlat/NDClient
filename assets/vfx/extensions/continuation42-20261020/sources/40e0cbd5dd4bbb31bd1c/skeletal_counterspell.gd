extends "res://assets/vfx/sources/a4fd0883f0b17d893a03/base.gd"
## Pinned source authoring only; shared stage owns clock/camera/export.
const SourceMaterials=preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
static func make_component(input: Dictionary) -> Node3D:
 return construct("res://assets/vfx/extensions/continuation42-20261020/sources/40e0cbd5dd4bbb31bd1c/skeletal_counterspell.gd", input)
func prepare_materials(_node: Node) -> void:pass
var hand:Node3D
var portal:MeshInstance3D
var flare:MeshInstance3D
var rim:MeshInstance3D
var magic_particles:Array[GPUParticles3D]=[]
var particle_started=false
var resource_seen={}
var anim:AnimationPlayer
var mats:Array[ShaderMaterial]=[]
func apply_scene_edits(node:Node)->void:
 pass
 hand=VfxPackageIO_40e0cbd5dd.resource("res://assets/vfx/extensions/continuation42-20261020/sources/611b850b2cfbd1da51cd/SkeletalCounterspellV5.scn").instantiate();node.add_child(hand)
 hand.position=Vector3(0,-2.5,.50);hand.rotation.y=PI;hand.scale=Vector3.ONE*1.65
 var noise=VfxPackageIO_40e0cbd5dd.resource("res://assets/vfx/extensions/continuation42-20261020/sources/5aecbaf1cbc2519c6be0/texture.res")
 for c in hand.find_children("*","",true,false):
  if c is AnimationPlayer:
   anim=c
   for name in anim.get_animation_list():
    if name!="RESET":anim.play(name);anim.pause();break
  if c is MeshInstance3D:
   var m=ShaderMaterial.new();var sh=Shader.new();var code=BONE
   code=code.replace("void fragment(){","void fragment(){vec3 wp=(INV_VIEW_MATRIX*vec4(VERTEX,1.)).xyz;if(dot(wp,vec3(0.70710678,0.0,0.70710678)) "+("<" if side=="front" else ">=")+"0.)discard;if(wp.y<.045)discard;")
   sh.code=code;m.shader=sh;m.set_shader_parameter("noise_tex",noise);c.material_override=m;mats.append(m)
 portal=VfxPackageIO_40e0cbd5dd.resource("res://assets/vfx/extensions/continuation42-20261020/sources/9e6791babea122a701a9/HandBirthPortal.tscn").instantiate();node.add_child(portal);portal.position=Vector3(0,.025,-.065);portal.scale=Vector3.ONE*.14
 var m=portal.material_override.duplicate(true);var gradient=m.get_shader_parameter("Color_1D_Gradient").duplicate(true);gradient.gradient=gradient.gradient.duplicate(true)
 var cols=gradient.gradient.colors
 for i in range(cols.size()):cols[i]=Color(cols[i].v,cols[i].v,cols[i].v,cols[i].a)
 gradient.gradient.colors=cols;m.set_shader_parameter("Color_1D_Gradient",gradient);m.set_shader_parameter("Transparency",1.0);m.set_shader_parameter("Proximity_Fade",0.01)
 var code=m.shader.code.replace("TIME","age").replace("shader_type spatial;","shader_type spatial; uniform float age=0.;uniform float env=1.;")
 var regex=RegEx.new();regex.compile("void\\s+fragment\\s*\\(\\s*\\)\\s*\\{");var match0=regex.search(code)
 if match0:
  code=code.insert(match0.get_end(),"vec3 wp=(INV_VIEW_MATRIX*vec4(VERTEX,1.)).xyz;if(dot(wp,vec3(0.70710678,0.0,0.70710678)) "+("<" if side=="front" else ">=")+"0.)discard;")
 var at=code.rfind("}");code=code.insert(at,"ALPHA*=env;");var sh=Shader.new();sh.code=code;m.shader=sh;portal.material_override=m;mats.append(m)
 flare=MeshInstance3D.new();var sphere=SphereMesh.new();sphere.radius=.10;sphere.height=.20;flare.mesh=sphere;node.add_child(flare);flare.position=Vector3(0.2105243369936943,2.062067713588476,2.4470988512039185)
 var fm=ShaderMaterial.new();var fs=Shader.new();fs.code=GLOW;fm.shader=fs;flare.material_override=fm
 rim=MeshInstance3D.new();var torus=TorusMesh.new();torus.inner_radius=.625;torus.outer_radius=.680;torus.rings=64;torus.ring_segments=12;rim.mesh=torus;node.add_child(rim);rim.position=Vector3(0,.05,-.065)
 var rm=ShaderMaterial.new();var rs=Shader.new();rs.code=GLOW;rm.shader=rs;rim.material_override=rm
 for mesh in [flare,rim]:
  var glow_shader=Shader.new();glow_shader.code=GLOW.replace("void fragment(){","void fragment(){vec3 wp=(INV_VIEW_MATRIX*vec4(VERTEX,1.)).xyz;if(dot(wp,vec3(0.70710678,0.0,0.70710678)) "+("<" if side=="front" else ">=")+"0.)discard;");mesh.material_override.shader=glow_shader
 var donor=VfxPackageIO_40e0cbd5dd.resource("res://assets/vfx/extensions/continuation42-20261020/sources/9bef9948402f793fd5e3/DeathPunchSource.tscn").instantiate()
 for source_name in ["sparkling_details2","muzzle2start"]:
  var particles=donor.get_node(source_name).duplicate();node.add_child(particles);particles.emitting=false;particles.one_shot=source_name!="sparkling_details2";particles.fixed_fps=144;particles.use_fixed_seed=true;particles.seed=18271+magic_particles.size();particles.local_coords=true
  particles.amount=42 if source_name=="sparkling_details2" else 1
  particles.lifetime=.85 if source_name=="sparkling_details2" else .35
  particles.scale=Vector3.ONE*.14;particles.position=Vector3(0,1.85,.70)
  particles.process_material=particles.process_material.duplicate(true)
  var pm=particles.process_material
  if source_name=="muzzle2start":pm.scale_min=2.5;pm.scale_max=3.2
  particles.layers=1
  pm.gravity=pm.gravity*.05;pm.initial_velocity_min*=.15;pm.initial_velocity_max*=.15;pm.emission_sphere_radius=.40
  particles.material_override=ShaderMaterial.new();var ps=Shader.new();ps.code=MOTE.replace("SPLIT","<" if side=="front" else ">=");particles.material_override.shader=ps
  var sprite=VfxPackageIO_40e0cbd5dd.resource("res://assets/vfx/extensions/continuation42-20261020/sources/51f2c10bd051539a8704/texture.res");particles.material_override.set_shader_parameter("sprite",sprite)
  magic_particles.append(particles)
 donor.free()
 var light=DirectionalLight3D.new();node.add_child(light);light.rotation_degrees=Vector3(-48,-30,0);light.light_energy=1.8
func advance_lifecycle(_dt:float)->void:
 tick+=1
 var age=float(tick)/144.
 if anim:anim.seek(age,true)
 if age>.12 and not particle_started:
  for p in magic_particles:p.emitting=true;p.restart()
  particle_started=true
 for p in magic_particles:
  p.position.y=max(.12,hand.position.y-.10)
  p.material_override.set_shader_parameter("env",smoothstep(.1,.4,age)*(1.-smoothstep(2.6,3.1,age)))
 if hand:hand.position.y=lerpf(-2.5,2.45,smoothstep(.06,.85,age))-4.95*smoothstep(2.25,3.12,age)
 var env=smoothstep(0.,.05,age)*(1.-smoothstep(3.02,3.24,age))
 if flare:flare.material_override.set_shader_parameter("env",0.0)
 if rim:rim.material_override.set_shader_parameter("env",smoothstep(.0,.16,age)*(1.-smoothstep(3.08,3.24,age)))
 for m in mats:
  m.set_shader_parameter("age",age)
  m.set_shader_parameter("env",smoothstep(0.,.16,age)*(1.-smoothstep(3.08,3.24,age)) if portal and m==portal.material_override else env)
const MOTE="""shader_type spatial;render_mode unshaded,cull_disabled;
uniform sampler2D sprite;uniform float env=1.;
void fragment(){vec3 wp=(INV_VIEW_MATRIX*vec4(VERTEX,1.)).xyz;if(dot(wp,vec3(0.70710678,0.0,0.70710678)) SPLIT 0.)discard;vec4 t=texture(sprite,UV);ALBEDO=vec3(.66+.26*t.r);ALPHA=t.a*env;}
"""
const GLOW="""shader_type spatial;render_mode unshaded,cull_disabled;
uniform float env=1.;
void fragment(){float edge=pow(1.-abs(dot(normalize(NORMAL),normalize(VIEW))),2.);ALBEDO=vec3(.50+.40*edge);EMISSION=vec3(.30);ALPHA=env;}
"""
const BONE="""shader_type spatial;
render_mode cull_disabled;
uniform sampler2D noise_tex:repeat_enable;
uniform float age=0.;uniform float env=1.;
varying vec3 bone_position;
void vertex(){bone_position=VERTEX;}
void fragment(){
 float n=texture(noise_tex,bone_position.xy*5.+bone_position.z*.71).r;
 float flow=1.-smoothstep(.03,.16,abs(sin(dot(bone_position,vec3(9.,11.,7.))-age*1.8+n*4.)));
 ALBEDO=vec3(.42+.08*n);ROUGHNESS=.70;METALLIC=0.;
 EMISSION=vec3(.10)*flow*smoothstep(.3,.8,age);
 float seam=pow(1.-abs(dot(normalize(NORMAL),normalize(VIEW))),5.);
 EMISSION+=vec3(.20)*seam;
 ALPHA=env*smoothstep(-.1,.12,n+env-.8);
}
"""

const VfxPackageIO_40e0cbd5dd = preload("res://assets/vfx/extensions/continuation42-20261020/scoped_resource_io.gd")
