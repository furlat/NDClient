extends "res://assets/vfx/sources/a4fd0883f0b17d893a03/base.gd"
## Pinned source authoring only; shared stage owns clock/camera/export.
const SourceMaterials=preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
static func make_component(input: Dictionary) -> Node3D:
 return construct("res://assets/vfx/sources/d092a75e3b0074bcf468/control_status.gd", input)
func prepare_materials(_node: Node) -> void:pass
func apply_scene_edits(node:Node)->void:
 pass
 subject=node
 node.set_script(null)
 for player in node.find_children("*","AnimationPlayer",true,false):
  player.stop()
  player.active=false
 if settings.kind in ["charmed","sleep"]:
  for particle in node.find_children("*","GPUParticles3D",true,false):
   if particle.name=="Aura":
    particle.layers=0
    particle.emitting=false
    continue
   var glyph_mesh=particle.draw_pass_1.duplicate(true)
   glyph_mesh.size=Vector2(1.0,1.0)
   particle.draw_pass_1=glyph_mesh
   particle.amount=7 if settings.kind=="charmed" else 6
   particle.lifetime=1.65 if settings.kind=="charmed" else 1.35
   particle.fixed_fps=144
   particle.position.y=1.7
   if settings.kind=="charmed":
    particle.position.y=1.25
    particle.randomness=0.65
    particle.explosiveness=0.0
   particle.process_material=particle.process_material.duplicate(true)
   particle.process_material.emission_shape_scale=Vector3(0.62,0.30,0.52) if settings.kind=="charmed" else Vector3(0.65,0.2,0.45)
   particle.process_material.scale_min=0.16
   particle.process_material.scale_max=0.32
   particle.process_material.gravity=Vector3(0,0.6,0)
   particle.process_material.orbit_velocity_min=0.02
   particle.process_material.orbit_velocity_max=0.08
   var mat=particle.material_override.duplicate(true)
   particle.material_override=mat
   if settings.kind=="charmed":
    var code=mat.shader.code
    var start=code.find("float diagonal =")
    var end=code.find("ALPHA = shape;",start)
    code=code.substr(0,start)+"vec2 p=vec2(centered_uv.x,-centered_uv.y)*1.15; p.y+=0.15; float a=p.x*p.x+p.y*p.y-0.55; float heart=a*a*a-p.x*p.x*p.y*p.y*p.y; float shape=(1.0-smoothstep(-0.015,0.015,heart))*COLOR.a;\n"+code.substr(end)
    var shader=Shader.new();shader.code=code;mat.shader=shader
   mat.set_shader_parameter("primary_color",Color.WHITE)
   mat.set_shader_parameter("secondary_color",Color(0.6,0.6,0.6))
   mat.set_shader_parameter("hue_variation",0.0)
   mat.set_shader_parameter("emission",0.9)
   mat.set_shader_parameter("edge_position",0.0)
   mat.set_shader_parameter("proximity_fade",false)
   adapt_shader(mat)
   particle.emitting=true
   particle.restart()

 else:
  for child in node.find_children("*","GeometryInstance3D",true,false):child.layers=0
  var donor_name="purple" if settings.kind=="blinded" else ("glow" if settings.kind=="deafened" else "gem")
  var donor=VfxPackageIO_d092a75e3b.resource(parameters.donor_scene).instantiate()
  var layer=donor.get_node("Particles" if settings.kind=="command" else "Aura").duplicate()
  if settings.kind=="command":
   var accent=donor.get_node("MeshInstance3D").duplicate()
   node.add_child(accent)
   accent.position=Vector3(0,1.72,0)
   accent.scale=Vector3.ONE*0.38
   accent.material_override=accent.material_override.duplicate(true)
   accent.material_override.set_shader_parameter("proximity_fade",false)
   accent.material_override.set_shader_parameter("streaks_thickness",0.025)
   accent.material_override.set_meta("command_accent",true)
   adapt_shader(accent.material_override)
  donor.free()
  node.add_child(layer)
  layer.position=Vector3(0,1.95,0)
  layer.amount=10 if settings.kind!="command" else 6
  if settings.kind=="command":
   layer.draw_pass_1=layer.draw_pass_1.duplicate(true)
   layer.draw_pass_1.size*=2.0
  layer.lifetime=0.85
  layer.fixed_fps=144
  layer.use_fixed_seed=true
  layer.seed=7331
  layer.randomness=0.6
  layer.process_material=layer.process_material.duplicate(true)
  layer.process_material.emission_shape_scale=Vector3(0.65,0.12,0.65) if settings.kind=="deafened" else Vector3(0.32,0.22,0.32)
  layer.process_material.scale_min=0.25
  layer.process_material.scale_max=0.50
  layer.process_material.radial_velocity_min=-0.30 if settings.kind=="blinded" else 0.15
  layer.process_material.radial_velocity_max=-0.10 if settings.kind=="blinded" else 0.35
  layer.process_material.gravity=Vector3(0,-0.5,0) if settings.kind=="command" else Vector3(0,0.10,0)
  layer.material_override=layer.material_override.duplicate(true)
  layer.material_override.set_shader_parameter("emission",1.2)
  layer.material_override.set_shader_parameter("shape_curve",1.3)
  layer.material_override.set_shader_parameter("edge_position",0.0)
  layer.material_override.set_shader_parameter("edge_hardness",0.0)
  layer.material_override.set_shader_parameter("proximity_fade",false)
  adapt_shader(layer.material_override)
  layer.emitting=true;layer.restart()
  var mesh=QuadMesh.new();mesh.size=Vector2(0.55,0.48) if settings.kind=="blinded" else Vector2(0.65,0.48)
  var mark=MeshInstance3D.new();mark.mesh=mesh;node.add_child(mark)
  mark.position=Vector3(0,2.52,0)
  # Source orientation also works before insertion into a live scene tree.
  mark.basis=Basis.looking_at(Vector3(12,9.797958971,12).normalized(),Vector3.UP,true)
  var mat=ShaderMaterial.new();var shader=Shader.new()
  shader.code=VfxPackageIO_d092a75e3b.text("res://assets/vfx/sources/e4d6cf6e1f2b0da7d181/control_glyph.gdshader")
  mat.shader=shader;mat.set_shader_parameter("kind",0 if settings.kind=="blinded" else (1 if settings.kind=="deafened" else 2))
  mesh.material=mat
  # Symbolic glyph is a camera-readable overhead cue, deliberately front layer.
  if side=="back":mark.layers=0
  materials.append(mat)
func advance_lifecycle(_delta:float)->void:
 if not is_instance_valid(subject):return
 tick+=1
 var phase=tick%576
 for particle in subject.find_children("*","GPUParticles3D",true,false):
  if particle.layers==0:continue
  var particle_phase=(tick+int(particle.get_meta("cycle_offset",0)))%576
  if particle_phase==0:
   particle.emitting=true
   particle.restart()
  if particle_phase==324:particle.emitting=false
 for mat in materials:
  var symbol=mat.shader.code.contains("uniform int kind")
  mat.set_shader_parameter("support_clock",0.9 if symbol else 1.0+sin(float(phase)*TAU/576.0)*0.4)
  mat.set_shader_parameter("support_envelope",0.0 if mat.has_meta("command_accent") else 1.0)

func expand_includes(code:String,base:String)->String:
 var result=""
 for line in code.split("\n"):
  if line.strip_edges().begins_with("#include"):
   var path=line.get_slice('"',1)
   if not path.begins_with("res://"):path=base.path_join(path)
   result+=expand_includes(VfxPackageIO_d092a75e3b.text(path),path.get_base_dir())+"\n"
  else:result+=line+"\n"
 return result
func adapt_shader(mat:ShaderMaterial)->void:
 var shader=Shader.new()
 var code:String=expand_includes(mat.shader.code,mat.shader.resource_path.get_base_dir())
 # Source-relative includes must resolve from the copied shader resource.
 code=code.replace("TIME","support_clock")
 code=code.replace("shader_type spatial;","shader_type spatial;\nuniform float support_clock=0.0;\nuniform float support_envelope=1.0;")
 var split="<" if side=="front" else ">="
 var prefix="\nvec3 support_world=(INV_VIEW_MATRIX*vec4(VERTEX,1.0)).xyz;\nif(dot(support_world,vec3(0.70710678,0.0,0.70710678)) "+split+" 0.0) discard;\n"
 var regex=RegEx.new();regex.compile("void\\s+fragment\\s*\\(\\s*\\)\\s*\\{")
 var match0=regex.search(code)
 if match0:
  var pos=match0.get_end();code=code.insert(pos,prefix)
  var depth=1;var end=pos+prefix.length()
  while end<code.length() and depth>0:
   if code[end]=="{":depth+=1
   elif code[end]=="}":depth-=1
   end+=1
  code=code.insert(end-1,"\nALPHA *= support_envelope;\n")
 shader.code=code;mat.shader=shader;materials.append(mat)

# Godot screen_texture may expose opaque alpha under Forward+. Quantize the
# native RGBA image here instead: RGB uses a 2px grid, alpha is byte-for-byte kept.

const VfxPackageIO_d092a75e3b = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
