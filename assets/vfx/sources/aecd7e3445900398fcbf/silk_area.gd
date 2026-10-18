extends "res://assets/vfx/sources/e212c77ca5bf64639ea0/base.gd"
static func make_component(input: Dictionary)->Node3D:
 return construct("res://assets/vfx/sources/aecd7e3445900398fcbf/silk_area.gd", input)
func prepare_materials(_node: Node)->void:pass
var mats:Array=[]
var parts:Array=[]
var animations:Array=[]
var deploy_mats:Array=[]
var net_mats:Array=[]
var active=false
func shader_material(old: ShaderMaterial) -> ShaderMaterial:
 var m=ShaderMaterial.new();var sh=Shader.new();var code=old.shader.code.replace("TIME","source_clock")
 code=code.replace("shader_type spatial;","shader_type spatial;\nuniform float source_clock=0.0;uniform float global_fade=1.0;")
 code=code.insert(code.rfind("}"),"\nALPHA*=global_fade;\n")
 sh.code=code;m.shader=sh
 for p in old.shader.get_shader_uniform_list():m.set_shader_parameter(p.name,old.get_shader_parameter(p.name))
 m.set_shader_parameter("Enable_Proximity_Fade",false)
 if settings.spell=="sleep":m.set_shader_parameter("Color",Color(1.25,.82,1.9,1))
 mats.append(m);return m
func apply_scene_edits(root: Node) -> void:
 subject=root
 subject.rotation_degrees.y=settings.yaw
 if settings.spell=="web_projectile":subject.scale=Vector3(.6,.6,.6)
 if settings.spell=="sleep":
  subject.scale=Vector3(1.65,.32,1.65)
  subject.position.y=.45
  var p=subject as GPUParticles3D
  p.draw_pass_1=p.draw_pass_1.duplicate(true)
  p.draw_pass_1.size=Vector2(2.4,.7)
  p.process_material=p.process_material.duplicate(true)
  p.amount=16;p.lifetime=1.35;p.one_shot=true;p.explosiveness=.95;p.randomness=.12;p.preprocess=0
  p.process_material.angle_min=0.;p.process_material.angle_max=0.;p.process_material.angular_velocity_min=0.;p.process_material.angular_velocity_max=0.
  p.process_material.radial_velocity_min=7.0;p.process_material.radial_velocity_max=8.0
  p.process_material.gravity=Vector3(0,.4,0)
 if settings.spell=="web_ground":
  subject.scale=Vector3(4.,4.,4.);subject.position.y=.035;subject.rotation_degrees.y=0.
 if settings.spell=="web":
  subject=root
  var mesh=PlaneMesh.new();mesh.size=Vector2(10.6,10.6);mesh.subdivide_width=100;mesh.subdivide_depth=100
  var silk=MeshInstance3D.new();silk.mesh=mesh;subject.add_child(silk)
  var material=ShaderMaterial.new();var shader=Shader.new()
  shader.code=VfxPackageIO_aecd7e3445.text("res://assets/vfx/sources/4b246023a140700df356/ContinuousWeb.gdshader")
  material.shader=shader
  var texture=VfxPackageIO_aecd7e3445.image("res://assets/vfx/sources/0b13f8c9f190dd46fcfa/texture.res");texture.generate_mipmaps()
  material.set_shader_parameter("silk_texture",ImageTexture.create_from_image(texture))
  material.set_shader_parameter("forward_axis",Vector2(-sin(deg_to_rad(float(settings.yaw))),-cos(deg_to_rad(float(settings.yaw)))))
  silk.material_override=material;net_mats.append(material)
 if settings.spell in ["web_bound_back","web_bound_front"]:
  subject.scale=Vector3(1.15,1.15,1.15)
  subject.get_node("SmCharacterBase4").visible=false
  subject.get_node("am_web_character").position=Vector3.ZERO
  subject.get_node("am_web_character").scale=Vector3(1.35,1.,1.35)
  subject.get_node("am_web_trap").scale=Vector3(.7,.7,.7)
 if settings.spell=="web_tether":
  subject.scale=Vector3(.6,.6,1.0);subject.position.y=.18
  subject.get_node("Marker3D_Start").position=Vector3(0,0,4)
  subject.get_node("Marker3D_End").position=Vector3(0,0,-4)
  subject.get_node("Armature/Skeleton3D").open_amount=.4
  subject.get_node("Armature/Skeleton3D").wave_amount=.18
 for node in [subject]+subject.find_children("*","",true,false):
  if node is GPUParticles3D:
   node.emitting=false;node.use_fixed_seed=true;node.seed=47291+parts.size();node.visibility_aabb=AABB(Vector3(-50,-50,-50),Vector3(100,100,100));parts.append(node)
  if settings.spell!="web" and node is GeometryInstance3D and node.material_override is ShaderMaterial:node.material_override=shader_material(node.material_override)
  if node is MeshInstance3D and settings.spell in ["web_ground","web_tether","web_bound_back","web_bound_front"]:
   if settings.spell=="web_ground":
    var original=node.mesh;var mesh=ArrayMesh.new()
    for surface in original.get_surface_count():
     var arr=original.surface_get_arrays(surface);var verts=arr[Mesh.ARRAY_VERTEX]
     for i in verts.size():
      var v=verts[i];var radius=Vector2(v.x,v.z).length();var edge=max(abs(v.x),abs(v.z))
      if edge>.0001:v.x*=radius/edge;v.z*=radius/edge
      verts[i]=v
     arr[Mesh.ARRAY_VERTEX]=verts;arr[Mesh.ARRAY_BONES]=null;arr[Mesh.ARRAY_WEIGHTS]=null
     mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arr)
     mesh.surface_set_material(surface,original.surface_get_material(surface))
    node.mesh=mesh;node.skin=null;node.skeleton=NodePath("")
   var old=node.get_active_material(0)
   if old is StandardMaterial3D:
    var mat=ShaderMaterial.new();var sh=Shader.new()
    sh.code="shader_type spatial;render_mode unshaded,cull_disabled,depth_draw_never;uniform sampler2D web_tex:source_color,filter_linear_mipmap;uniform float silk_gain=3.;uniform float silk_opacity=1.;uniform float deploy=1.;uniform float source_clock=0.;uniform vec2 forward_axis=vec2(1.,0.);uniform float split_side=0.;varying vec3 world_pos;void vertex(){vec3 rest_position=VERTEX;float r=length(rest_position.xz);vec2 side=vec2(-forward_axis.y,forward_axis.x);vec3 gathered=vec3(0.);gathered.xz=side*rest_position.x*.34-forward_axis*r*.65;gathered.y=.30+rest_position.z*.34;float flutter=sin(source_clock*6.2831853*2.+r*8.)*.018*r;gathered.y+=flutter;float p=deploy;VERTEX=mix(gathered,rest_position,p);VERTEX.y+=sin(p*3.14159265)*.12*r*(1.-p);world_pos=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}void fragment(){if(split_side!=0.){float depth=dot(world_pos-vec3(0.,1.,0.),normalize(vec3(12.,9.797958971,12.)));if((split_side>0.&&depth<0.)||(split_side<0.&&depth>=0.))discard;}vec4 t=texture(web_tex,UV);ALBEDO=vec3(.48,.53,.50);ALPHA=clamp(t.a*silk_gain,0.,1.)*silk_opacity;}"

    mat.shader=sh
    var tex=VfxPackageIO_aecd7e3445.image(old.albedo_texture.resource_path);tex.generate_mipmaps()
    mat.set_shader_parameter("web_tex",ImageTexture.create_from_image(tex));node.material_override=mat
    if settings.spell=="web":
     mat.set_shader_parameter("deploy",0.)
     mat.set_shader_parameter("forward_axis",Vector2(-sin(deg_to_rad(float(settings.yaw))),-cos(deg_to_rad(float(settings.yaw)))))
     net_mats.append(mat)
     if settings.spell=="web":deploy_mats.append(mat)
    if settings.spell in ["web_bound_back","web_bound_front"]:
     mat.set_shader_parameter("silk_opacity",.42)
     mat.set_shader_parameter("split_side",-1. if settings.spell=="web_bound_back" else 1.)
     if node.name=="evolved_low":mat.set_shader_parameter("silk_gain",1.);mat.set_shader_parameter("silk_opacity",.35)

 for a in subject.find_children("*","AnimationPlayer",true,false):a.stop();animations.append(a)

 active=true
 for p in parts:p.restart();p.emitting=settings.spell in ["sleep","web_projectile"]
func advance_lifecycle(_dt):
 if not active:return
 tick+=1
 for mat in net_mats:mat.set_shader_parameter("source_clock",float(tick-144)/144.*.85 if settings.spell=="web_projectile" else float(tick-1)/144.)
 for mat in deploy_mats:
  var p=clamp(float(tick-1)/144./.8,0.,1.)
  mat.set_shader_parameter("deploy",smoothstep(0.,1.,p))
 for mat in mats:
  mat.set_shader_parameter("source_clock",min(float(tick)/144.,.48) if settings.spell=="web" else float(tick)/144.)
  mat.set_shader_parameter("global_fade",1. if settings.spell=="web" else 1.-smoothstep(1.5,1.95,float(tick)/144.))

const VfxPackageIO_aecd7e3445 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
