extends "res://assets/vfx/sources/843204815cdceaac8544/clocked_source.gd"
## Private original-Fireball correction. Keep actual donor emitters/masks/curves.
## Current staging schedules the full scene once. Split its five native smoke/lobe
## layers into the existing smoke phase once, preserving every source layer.
const Finish=preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
const SMOKE_LAYERS=["smoke","smokeball3","smokeball4","smokeball5","smokeball6"]
var corrected_layers: Array=[]
var finished_materials: Dictionary={}
static func make_component(input: Dictionary) -> Node3D:
 return construct("res://assets/vfx/sources/100a1e8a7dbdb57b9d07/fireball_repair.gd",input)
func apply_scene_edits(node: Node) -> void:
 for draw in node.find_children("*","GeometryInstance3D",true,false):
  var smoke: bool=str(draw.name) in SMOKE_LAYERS
  if (settings.layer=="fire" and smoke) or (settings.layer=="smoke" and not smoke):draw.layers=0
 if settings.layer=="fire":
  # Actual accepted20ftGround variant registration, not a newly invented mesh.
  node.get_node("shockwave_1").scale.y=.1;node.get_node("shockwave_1").position.y=.05
  var ball: GPUParticles3D=node.get_node("ball")
  ball.process_material=ball.process_material.duplicate(true)
  var ramp: GradientTexture1D=ball.process_material.color_ramp.duplicate(true)
  var gradient: Gradient=ramp.gradient.duplicate(true)
  var colors: PackedColorArray=gradient.colors
  for i in colors.size():
   var peak: float=maxf(colors[i].r,maxf(colors[i].g,colors[i].b));var gain: float=.90/(1.0+peak)
   colors[i]=Color(colors[i].r*gain,colors[i].g*gain,colors[i].b*gain,colors[i].a)
  gradient.colors=colors;ramp.gradient=gradient;ball.process_material.color_ramp=ramp
func prepare_materials(node: Node) -> void:
 super.prepare_materials(node)
 for draw in node.find_children("*","GeometryInstance3D",true,false):
  if draw.layers==0 or not draw.material_override is ShaderMaterial:continue
  if str(draw.name) not in SMOKE_LAYERS+["streaks2","shockwave_1","shockwave_2"]:continue
  var material: ShaderMaterial=draw.material_override
  if finished_materials.has(material.get_instance_id()):
   corrected_layers.append(str(draw.name));continue
  finished_materials[material.get_instance_id()]=true
  var code: String=Finish.finish_fragment(material.shader.code,"\n// Original HDR layer soft knee before unchanged accepted palette; original ALPHA is untouched.\nvec3 repair_energy=max(ALBEDO+EMISSION,vec3(0.0));\nfloat repair_gain=0.72/(1.0+max(max(repair_energy.r,repair_energy.g),repair_energy.b));\nALBEDO*=repair_gain; EMISSION*=repair_gain;\n")
  var shader:=Shader.new();shader.code=code;Finish.replace_shader(material,shader)
  corrected_layers.append(str(draw.name))
func capture_observation() -> Dictionary:
 var result: Dictionary=super.capture_observation()
 result["original_fire_repair"]={"layer":settings.layer,"hdr_soft_knee_layers":corrected_layers,"smoke_layer_ownership":"exact five native smoke/lobe layers occur only in smoke phase","native_geometry_rebuilt":false,"native_alpha_equation_changed":false,"palette_changed":false,"new_lights":0,"public_promoted":false}
 return result
