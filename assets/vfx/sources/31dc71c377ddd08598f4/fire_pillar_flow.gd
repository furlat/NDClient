extends "res://assets/vfx/sources/88154a50eb33feba9cb2/fire_pillar.gd"
## Inspected v138 original Flame Strike material/flow derivative; P2 style open.
const Finish=preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
var source_breakup: Texture2D
var source_scale_uv: Vector2
var source_speed_uv: Vector2
var repaired_layers: Array=[]
static func make_component(input: Dictionary) -> Node3D:
 return construct("res://assets/vfx/sources/31dc71c377ddd08598f4/fire_pillar_flow.gd",input)
func apply_scene_edits(node: Node) -> void:
 var rays: ShaderMaterial=node.get_node("outter_rays").material_override
 rays.set_shader_parameter("Scale_XY",Vector2(3.0,0.45))
 rays.set_shader_parameter("Speed_XY",Vector2(0.0,1.17))
 source_breakup=rays.get_shader_parameter("Base_Texture")
 source_scale_uv=rays.get_shader_parameter("Scale_XY");source_speed_uv=rays.get_shader_parameter("Speed_XY")
 assert(source_breakup!=null and VfxPackageIO_31dc71c377.has_source_suffix(source_breakup.resource_path, "T_VFX_Noise_7.PNG"))
 for name in ["inner_ray","outter_rays","outter_fresnel"]:
  node.get_node(name).material_override.set_meta("original_strike_repair_layer",name)
 # Original50x output clips its own moving mask and gradient into solid yellow.
 rays.set_shader_parameter("Color_Intensity",2.2)
 super.apply_scene_edits(node)
func adapt_shader(material: ShaderMaterial) -> void:
 super.adapt_shader(material)
 var layer: String=str(material.get_meta("original_strike_repair_layer",""))
 if layer.is_empty():return
 var code: String=material.shader.code
 code=code.replace("shader_type spatial;","shader_type spatial;\nvarying float repair_mesh_height;\nuniform sampler2D repair_native_noise : source_color;\nuniform vec2 repair_native_scale=vec2(3.0);\nuniform vec2 repair_native_speed=vec2(0.0,3.0);\n")
 # Inspected original cylinder/plane AABBs are y0..1 before native particle scale.
 if code.contains("void vertex()"):
  code=Finish.finish_function(code,"vertex","\nrepair_mesh_height=VERTEX.y;\n")
 else:code+="\nvoid vertex(){repair_mesh_height=VERTEX.y;}\n"
 var addition="\nfloat repair_noise=texture(repair_native_noise,UV*repair_native_scale+repair_native_speed*support_clock).r;\nfloat repair_tip=1.0-smoothstep(0.74+0.22*repair_noise,0.995,repair_mesh_height);\n"
 if layer=="outter_rays":addition+="ALPHA*=smoothstep(0.10,0.50,repair_noise)*repair_tip;\n"
 elif layer=="outter_fresnel":addition+="ALPHA*=0.12*smoothstep(0.12,0.50,repair_noise)*repair_tip;\n"
 else:addition+="ALPHA*=0.35*repair_tip;\n"
 code=Finish.finish_fragment(code,addition)
 var shader:=Shader.new();shader.code=code;Finish.replace_shader(material,shader)
 material.set_shader_parameter("repair_native_noise",source_breakup);material.set_shader_parameter("repair_native_scale",source_scale_uv);material.set_shader_parameter("repair_native_speed",source_speed_uv)
 repaired_layers.append({"layer":layer,"actual_mask":source_breakup.resource_path,"clock":"unchanged support_clock","source_mesh_height":[0.0,1.0],"original_gradient_retained":true})
func capture_observation() -> Dictionary:
 var result: Dictionary=super.capture_observation()
 result["original_strike_repair"]={"native_layers":repaired_layers,"original50x_intensity":2.2,"original_fresnel_support_weight":.12,"same_native_noise_uv_and_clock":true,"geometry_rebuilt":false,"new_lights":0,"public_promoted":false}
 result["original_strike_flow_followup"]={"native_mask_unchanged":"T_VFX_Noise_7.PNG","source_uv_scale":Vector2(3.0,0.45),"source_uv_speed":Vector2(0.0,1.17),"reason":"three repeated vertical native UV bands in v135","native_geometry_unchanged":true,"source_clock_unchanged":true,"new_lights":0,"public_promoted":false}
 return result

const VfxPackageIO_31dc71c377 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
