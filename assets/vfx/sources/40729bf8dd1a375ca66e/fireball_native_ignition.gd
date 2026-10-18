extends "res://assets/vfx/sources/f22d5e9070893c57c4a4/fireball_flow_repair.gd"
## Retained native ball with the actual original Fireball RGB gradient material.
## Native light/alpha/masks/process/lifetime remain; no replacement palette/mesh.
const FLOW_LINEAR_MEDIAN=0.20507873639031693
const PRIOR_RGB="""
float repair_ignition_flow=texture(Dissplacement_texture,UV+source_clock*Displacement_Speed).r;
float repair_ignition_temperature=clamp(repair_ignition_phase+(repair_ignition_flow-0.5)*0.70,0.0,1.0);
vec3 repair_ignition_native=texture(repair_ignition_gradient,vec2(repair_ignition_temperature)).rgb;
float repair_ignition_gain=0.72/(1.0+max(max(repair_ignition_native.r,repair_ignition_native.g),repair_ignition_native.b));
ALBEDO=repair_ignition_native*repair_ignition_gain;
EMISSION=vec3(0.0);
"""
const NATIVE_RGB="""
float repair_ignition_flow=texture(Dissplacement_texture,UV+source_clock*Displacement_Speed).r;
// Measured T_VFX_Noise_13 source_color linear median, not a guessed grey centre.
float repair_ignition_temperature=clamp(repair_ignition_phase+(repair_ignition_flow-0.20507873639031693)*0.70,0.0,1.0);
vec3 repair_ignition_dark=texture(Dark_Color_Gradient_1D,vec2(repair_ignition_temperature)).rgb;
vec3 repair_ignition_emission=texture(Emission_Gradient_1D,vec2(repair_ignition_temperature)).rgb;
vec3 repair_ignition_native=max(repair_ignition_dark+repair_ignition_emission,vec3(0.0));
float repair_ignition_gain=0.72/(1.0+max(max(repair_ignition_native.r,repair_ignition_native.g),repair_ignition_native.b));
ALBEDO=repair_ignition_dark*repair_ignition_gain;
EMISSION=repair_ignition_emission*repair_ignition_gain;
"""
var native_ignition_rgb: bool=false
static func make_component(input: Dictionary) -> Node3D:
 return construct("res://assets/vfx/sources/40729bf8dd1a375ca66e/fireball_native_ignition.gd",input)
func prepare_materials(node: Node) -> void:
 super.prepare_materials(node)
 var ball: GPUParticles3D=node.get_node("ball")
 if ball.layers==0:return
 var material: ShaderMaterial=ball.material_override
 var code: String=material.shader.code
 assert(code.count(PRIOR_RGB)==1)
 assert(code.contains("DIFFUSE_LIGHT = n_out8p0;") and not code.contains("DIFFUSE_LIGHT = n_out8p0 * ALBEDO;"))
 code=code.replace(PRIOR_RGB,NATIVE_RGB)
 var shader:=Shader.new();shader.code=code;Finish.replace_shader(material,shader)
 native_ignition_rgb=true
func capture_observation() -> Dictionary:
 var result: Dictionary=super.capture_observation()
 result["original_ignition_native_rgb"]={"active":native_ignition_rgb,"rgb":"actual original Fireball Dark_Color_Gradient_1D and Emission_Gradient_1D","flow_source":"actual original T_VFX_Noise_13.PNG","measured_flow_linear_median":FLOW_LINEAR_MEDIAN,"source_light_function_unchanged":true,"source_alpha_masks_process_mesh_lifetime_clock_retained":true,"old_white_ignition_ramp":"retained in original process data; no longer overrides cloned Fireball material RGB","new_palette":false,"new_geometry":false,"new_lights":0,"public_promoted":false}
 return result
