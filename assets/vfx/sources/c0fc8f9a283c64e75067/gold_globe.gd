extends "res://assets/vfx/sources/a4fd0883f0b17d893a03/base.gd"
## Pinned source authoring only; shared stage owns clock/camera/export.
const SourceMaterials=preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
static func make_component(input: Dictionary) -> Node3D:
 return construct("res://assets/vfx/sources/c0fc8f9a283c64e75067/gold_globe.gd", input)
func prepare_materials(_node: Node) -> void:pass
var mats:Array[ShaderMaterial]=[]
var ap:AnimationPlayer
var pixel_material:ShaderMaterial
func apply_scene_edits(node:Node)->void:
 pass
 subject=node
 if settings.kind=="sanctuary":
  node.scale=Vector3.ONE*0.24
  var original=node.get_node("YingYang_Kar")
  var mark=original.duplicate();mark.name="SanctuaryMark";node.add_child(mark)
  mark.position=Vector3(0,11.25,0);mark.scale=Vector3.ONE*0.70
  mark.quaternion=Quaternion(Vector3.UP,Vector3(12,9.797958971,12).normalized())
  node.get_node("YingYang_Base_Circle").lifetime=4.8
 elif settings.kind.begins_with("mage_armor"):node.scale=Vector3.ONE*(0.93 if settings.kind=="mage_armor" else 1.03)
 else:node.scale=Vector3.ONE*2.0
 for child in node.find_children("*","GeometryInstance3D",true,false):
  if str(child.name).contains("Distortion"):child.layers=0;continue
  if settings.kind=="sanctuary" and child.name not in ["YingYang_Base_Circle","YingYang_Kar","Small Sparks","Small Sparks2","torus2white","torus3black","SanctuaryMark"]:child.layers=0;continue
  if child is GPUParticles3D:child.fixed_fps=144;child.use_fixed_seed=true;child.seed=47291
  if child.material_override is StandardMaterial3D:child.material_override=convert_standard(child.material_override)
  if child is GPUParticles3D and child.draw_pass_1 and not child.material_override:
   var sm=child.draw_pass_1.surface_get_material(0)
   if sm is StandardMaterial3D:child.material_override=convert_standard(sm)
  if child.material_override is ShaderMaterial:
   child.material_override=child.material_override.duplicate(false)
   if settings.kind=="shield":
    child.material_override.set_shader_parameter("Overlay_Scale",Vector2(0.75,0.75))
    child.material_override.set_shader_parameter("Overlay_Velocity",Vector2(0,-0.08))
   adapt(child.material_override, settings.kind=="sanctuary" and child.name in ["YingYang_Base_Circle","YingYang_Kar","SanctuaryMark"], child.name in ["YingYang_Kar","SanctuaryMark"])
  elif child is MeshInstance3D and child.mesh:
   child.mesh=child.mesh.duplicate(true)
   for s in range(child.mesh.get_surface_count()):
    var m=child.mesh.surface_get_material(s)
    if m is ShaderMaterial:
     m=m.duplicate(true);adapt(m, settings.kind=="sanctuary" and child.name in ["YingYang_Base_Circle","YingYang_Kar"]);child.set_surface_override_material(s,m)
  # Ground motif belongs below the character, regardless of its horizontal extent.
  if settings.kind=="sanctuary" and child.name in ["YingYang_Base_Circle","YingYang_Kar"] and side=="front":child.layers=0
  if child.name=="SanctuaryMark" and side=="back":child.layers=0
 for light in node.find_children("*","Light3D",true,false):light.visible=false
func convert_standard(source:StandardMaterial3D)->ShaderMaterial:
 var mat=ShaderMaterial.new();var sh=Shader.new()
 sh.code="shader_type spatial; render_mode unshaded,cull_disabled; uniform sampler2D source_tex:source_color; uniform vec4 source_tint:source_color=vec4(1.0); uniform bool use_vertex=true; void fragment(){vec4 c=texture(source_tex,UV)*source_tint; if(use_vertex)c*=COLOR; ALBEDO=c.rgb; ALPHA=c.a;}"
 mat.shader=sh
 var texture=source.albedo_texture
 if texture==null:
  var im=Image.create(1,1,false,Image.FORMAT_RGBA8);im.fill(Color.WHITE);texture=ImageTexture.create_from_image(im)
 mat.set_shader_parameter("source_tex",texture);mat.set_shader_parameter("source_tint",source.albedo_color);mat.set_shader_parameter("use_vertex",source.vertex_color_use_as_albedo)
 return mat
func adapt(mat:ShaderMaterial, ground:bool=false, dual:bool=false)->void:
 var params={}
 for uniform in mat.shader.get_shader_uniform_list():
  params[uniform.name]=mat.get_shader_parameter(uniform.name)
 mat.set_shader_parameter("Overlay_Texture",VfxPackageIO_c0fc8f9a28.resource("res://assets/vfx/sources/929cd4ab89324bd78094/texture.res"))
 mat.set_shader_parameter("Overlay_Scale",Vector2(2.0,2.0))
 mat.set_shader_parameter("Overlay_Velocity",Vector2(1.0,0.0))
 params["Overlay_Texture"]=mat.get_shader_parameter("Overlay_Texture")
 params["Overlay_Scale"]=Vector2(2.0,2.0)
 params["Overlay_Velocity"]=Vector2(1.0,0.0)
 var original_shader=mat.shader
 var defaults={}
 for uniform in original_shader.get_shader_uniform_list():
  if uniform.type==TYPE_OBJECT:
   var tex=original_shader.get_default_texture_parameter(uniform.name)
   if tex!=null:defaults[uniform.name]=tex
 var sh=Shader.new();var code=mat.shader.code.replace("shadow_to_opacity, ", "")
 if settings.kind=="shield":
  # Widen the existing texture lines before sampling the final pixel grid.
  code=code.replace("n_out41p0 = texture(Overlay_Texture, n_out46p0);", "n_out41p0 = max(texture(Overlay_Texture,n_out46p0),max(max(texture(Overlay_Texture,n_out46p0+vec2(0.0015,0)),texture(Overlay_Texture,n_out46p0-vec2(0.0015,0))),max(texture(Overlay_Texture,n_out46p0+vec2(0,0.0015)),texture(Overlay_Texture,n_out46p0-vec2(0,0.0015)))));")
 code=code.replace("texture(Overlay_Texture, n_out46p0)","texture(Overlay_Texture, fract(n_out46p0))")
 code=code.replace("n_out48p0 + n_out32p0","n_out48p0 * 0.14 + n_out32p0")
 code=code.replace("n_out84p0 + n_out13p0","n_out13p0")
 code=code.replace("TIME","vfx_clock")
 code=code.replace("shader_type spatial;","shader_type spatial;\nuniform float vfx_clock=0.0;\nuniform float vfx_alpha=1.0;")
 var regex=RegEx.new();regex.compile("void\\s+fragment\\s*\\(\\s*\\)\\s*\\{");var found=regex.search(code)
 if found:
  var at=found.get_end();var op="<" if side=="front" else ">="
  var split="\nvec3 wp=(INV_VIEW_MATRIX*vec4(VERTEX,1.0)).xyz; if(dot(wp,vec3(0.612372436,0.5,0.612372436)) "+op+" 0.0) discard;\n"
  if settings.kind in ["shield","hit"] or settings.kind.begins_with("mage_armor"):
   split="\nvec3 wp=(INV_VIEW_MATRIX*vec4(VERTEX,1.0)).xyz; if(dot(wp-vec3(0.0,1.12,0.0),vec3(0.612372436,0.5,0.612372436)) "+op+" 0.0) discard;\n"
  if settings.kind.begins_with("mage_armor"):split=split.replace("1.12","0.93" if settings.kind=="mage_armor" else "1.03")
  # Sanctuary ground plane is one coherent symbol, not half a symbol.
  if ground:split=""
  split += "\nif(wp.y < 0.0) discard;\n"
  code=code.insert(at,split);var depth=1;var end=at+split.length()
  while end<code.length() and depth>0:
   if code[end]=="{":depth+=1
   elif code[end]=="}":depth-=1
   end+=1
  if settings.kind=="shield":
   var hex_lines="\nfloat readable_hex=smoothstep(0.30,0.65,n_out41p1)*n_out57p0; ALBEDO=max(ALBEDO,vec3(0.025,0.23,0.7)*readable_hex); ALPHA=max(ALPHA,0.42*readable_hex);\n"
   code=code.insert(end-1,hex_lines);end+=hex_lines.length()
  code=code.insert(end-1,("\nALBEDO=clamp(ALBEDO,vec3(0.035,0.025,0.045),vec3(1.0));\n" if dual else "")+"\nfloat rim=pow(1.0-abs(dot(NORMAL,VIEW)),1.9); float film=0.08+0.55*n_out48p0+0.24*rim; ALBEDO=mix(vec3(0.32,0.18,0.04),vec3(1.0,0.72,0.30),max(0.18+0.82*rim,n_out48p0)); ALPHA=film*n_out57p0*vfx_alpha;float rune_u=fract(atan(wp.z,wp.x)*1.273239545); vec2 gp=vec2((rune_u-0.5)*2.0,(wp.y-0.85)*2.8); float stem=1.0-smoothstep(0.055,0.09,abs(gp.x)); stem*=1.0-smoothstep(0.62,0.72,abs(gp.y)); float diamond=1.0-smoothstep(0.06,0.10,abs(abs(gp.x)*1.5+abs(gp.y)-0.49)); float fork=1.0-smoothstep(0.055,0.10,abs(abs(gp.x)-((gp.y+0.58)*0.65))); fork*=step(-0.58,gp.y)*step(-0.1,gp.y); float rune=max(stem,max(diamond,fork))*(1.0-smoothstep(0.72,0.82,abs(gp.y))); float longitude=atan(wp.z,wp.x); float band_y=wp.y+0.055*sin(longitude*3.0+vfx_clock*6.2831853); float band_dist=min(abs(band_y-0.43),abs(band_y-1.29)); float bands=(1.0-smoothstep(0.013,0.032,band_dist))*(0.65+0.35*sin(longitude*4.0+vfx_clock*6.2831853)); rune=max(rune,bands*0.7); float pulse=0.78+0.22*sin(vfx_clock*6.2831853+floor(atan(wp.z,wp.x)*1.273239545)*1.7); ALBEDO=mix(ALBEDO,vec3(1.0,0.78,0.37),rune*pulse); ALPHA=max(ALPHA,rune*0.68*n_out57p0*vfx_alpha);\n")
 sh.code=code;mat.shader=sh
 for key in params:
  if params[key]!=null:mat.set_shader_parameter(key,params[key])
 for key in defaults:
  if mat.get_shader_parameter(key)==null:mat.set_shader_parameter(key,defaults[key])
 mats.append(mat)
func advance_lifecycle(_delta:float)->void:
 if not is_instance_valid(subject):return
 tick+=1
 var age=float(tick)/144.0
 var alpha=1.0
 if settings.kind.begins_with("mage_armor"):
  var opacity=lerpf(1.0,0.22,smoothstep(2.0,2.8,age))*(1.0-smoothstep(6.5,7.3,age))
  if pixel_material:pixel_material.set_shader_parameter("output_opacity",opacity)
 elif settings.kind=="sanctuary":alpha=(1.0-smoothstep(4.8,5.6,age))*0.85
 if settings.kind=="shield" and tick==720:
  for p in subject.find_children("*","AnimationPlayer",true,false):
   if p.has_animation("end_animation"):p.play("end_animation")
 if settings.kind=="sanctuary":
  var mark=subject.get_node("SanctuaryMark")
  var original=subject.get_node("YingYang_Kar")
  mark.visible=true
  mark.material_override.set_shader_parameter("Alpha_Treshold",original.material_override.get_shader_parameter("Alpha_Treshold"))
  mark.material_override.set_shader_parameter("Color_Intensity",original.material_override.get_shader_parameter("Color_Intensity"))
  mark.quaternion=Quaternion(Vector3.UP,Vector3(12,9.797958971,12).normalized())*Quaternion(Vector3.UP,sin(age*1.2)*0.08)
  for geo in subject.find_children("*","GeometryInstance3D",true,false):
   geo.transparency=smoothstep(4.8,5.6,age)
 for m in mats:
  m.set_shader_parameter("vfx_clock",fmod(max(0.0,age-2.0/3.0),4.0) * 0.25)
  m.set_shader_parameter("vfx_alpha",alpha)
  m.set_shader_parameter("Proximity_light",0.0)
  m.set_shader_parameter("Gradient_Line",lerpf(-0.075,1.0,smoothstep(0.0,2.0/3.0,age)))

# Accepted LeLu Lab palette/alpha shader runs on the GPU before PNG readback.

const VfxPackageIO_c0fc8f9a28 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
