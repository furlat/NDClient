extends "res://assets/vfx/sources/100a1e8a7dbdb57b9d07/fireball_repair.gd"
## Private v135 follow-up: original native local mask/gradients, no new lobes.
var varied_layers: Array=[]
var varied_materials: Dictionary={}
var ignition_gradient: GradientTexture1D
var ignition_original_alpha: CurveTexture
static func make_component(input: Dictionary) -> Node3D:
 return construct("res://assets/vfx/sources/f22d5e9070893c57c4a4/fireball_flow_repair.gd",input)
func apply_scene_edits(node: Node) -> void:
 var ball: GPUParticles3D=node.get_node("ball")
 # Retain the actual original ignition colour/alpha data before the prior
 # energy-only draft clones/softens it; map it into a real donor material.
 ignition_gradient=ball.process_material.color_ramp
 ignition_original_alpha=ball.process_material.alpha_curve
 super.apply_scene_edits(node)
 # Original geometry, lifetime, source membership and particle curves remain.
 # The source lobe material supplies its actual bound noise/gradient samplers.
 ball.material_override=node.get_node("smokeball3").material_override.duplicate(true)
func prepare_materials(node: Node) -> void:
 super.prepare_materials(node)
 var ball: GPUParticles3D=node.get_node("ball")
 if ball.layers!=0:
  var material: ShaderMaterial=ball.material_override
  var code: String=material.shader.code
  code=code.replace("shader_type spatial;","shader_type spatial;\nvarying float repair_ignition_phase;\nuniform sampler2D repair_ignition_gradient : source_color;\n")
  # Particle INSTANCE_CUSTOM.y is actual normalized lifetime. The original
  # ignition alpha curve is opacity; this donor shader expects dissolve age.
  assert(code.contains("void vertex() {"))
  code=code.replace("void vertex() {","void vertex() {\nrepair_ignition_phase=clamp(INSTANCE_CUSTOM.y,0.0,0.999);\nCOLOR=vec4(repair_ignition_phase,0.0,0.0,clamp(1.0-COLOR.a,0.0,0.9999));\n")
  code=Finish.finish_fragment(code,"""
float repair_ignition_flow=texture(Dissplacement_texture,UV+source_clock*Displacement_Speed).r;
float repair_ignition_temperature=clamp(repair_ignition_phase+(repair_ignition_flow-0.5)*0.70,0.0,1.0);
vec3 repair_ignition_native=texture(repair_ignition_gradient,vec2(repair_ignition_temperature)).rgb;
float repair_ignition_gain=0.72/(1.0+max(max(repair_ignition_native.r,repair_ignition_native.g),repair_ignition_native.b));
ALBEDO=repair_ignition_native*repair_ignition_gain;
EMISSION=vec3(0.0);
""")
  var shader:=Shader.new();shader.code=code;Finish.replace_shader(material,shader)
  material.set_shader_parameter("repair_ignition_gradient",ignition_gradient)
  varied_layers.append("ball")
 for name in SMOKE_LAYERS:
  var draw: GeometryInstance3D=node.get_node(name)
  if draw.layers==0 or not draw.material_override is ShaderMaterial:continue
  var material: ShaderMaterial=draw.material_override
  if varied_materials.has(material.get_instance_id()):continue
  varied_materials[material.get_instance_id()]=true
  var code: String=material.shader.code
  if name=="smoke":
   code=Finish.finish_fragment(code,"\n// Actual source smoke opacity only, no replacement ring.\nALPHA*=0.38;\n")
  else:
   # Donor colour used only per-particle age; its native UV noise already
   # drives displacement/dissolve. Let that same mask vary temperature too.
   assert(code.contains("vec3 repair_energy=max(ALBEDO+EMISSION"))
   var local_variation="""
float repair_native_flow=texture(Dissplacement_texture,UV+source_clock*Displacement_Speed).r;
float repair_native_temperature=clamp(COLOR.r+(repair_native_flow-0.5)*0.70,0.0,1.0);
ALBEDO=texture(Dark_Color_Gradient_1D,vec2(repair_native_temperature)).rgb;
EMISSION=texture(Emission_Gradient_1D,vec2(repair_native_temperature)).rgb;
"""
   code=code.replace("vec3 repair_energy=max(ALBEDO+EMISSION",local_variation+"vec3 repair_energy=max(ALBEDO+EMISSION")
  var shader:=Shader.new();shader.code=code;Finish.replace_shader(material,shader)
  varied_layers.append(str(name))
func capture_observation() -> Dictionary:
 var result: Dictionary=super.capture_observation()
 result["original_fire_flow_followup"]={"varied_layers":varied_layers,"source_mask":"actual bound Dissplacement_texture T_VFX_Noise_13.PNG","source_gradients":"unchanged Dark_Color_Gradient_1D and Emission_Gradient_1D","lobe_alpha_changed":false,"source_smoke_alpha_gain":0.38,"ignition_ball_preserved":true,"ignition_material":"actual native smokeball3 shader/noise/gradient material on original ball mesh","ignition_color_ramp":"actual original ball ParticleProcessMaterial color_ramp","ignition_alpha":"actual original ball alpha_curve opacity mapped to source material dissolve","new_meshes":0,"new_lights":0,"public_promoted":false}
 return result
