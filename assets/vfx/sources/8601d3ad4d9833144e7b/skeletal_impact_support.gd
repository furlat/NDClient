extends "res://assets/vfx/sources/beb8f110e25cf563f964/skeletal_impact.gd"
## Selected Finger impact support correction, visually bounded in v131.
## Original donor, base component, Counterspell and private controls are unchanged.
## GPU probe shows the real star mask. Reject low mask support monotonically:
## unlike the failed smoothstep(.01,.08), this never increases source opacity.
const SourceSupport = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
const SELECTED_MASK = "res://assets/vfx/sources/ef5c68317e3e127c3045/texture.res"
var corrected_materials: Array[Dictionary] = []
static func make_component(input: Dictionary) -> Node3D:
 return construct("res://assets/vfx/sources/8601d3ad4d9833144e7b/skeletal_impact_support.gd", input)
func adapt_shader(material: ShaderMaterial) -> void:
 super.adapt_shader(material)
 var mask: Variant = material.get_shader_parameter("Mask_Texture")
 if not mask is Texture2D or mask.resource_path != SELECTED_MASK: return
 var code: String = material.shader.code
 assert(code.contains("float n_out3p1 = n_out3p0.r;"))
 code = code.replace("float n_out3p1 = n_out3p0.r;", "float n_out3p1 = max(n_out3p0.r - 0.10, 0.0) / 0.90;")
 var shader := Shader.new();shader.code=code;SourceSupport.replace_shader(material,shader)
 corrected_materials.append({"mask":mask.resource_path,"mask_size":mask.get_size(),"support_floor":0.10,"monotone_attenuation_only":true,"palette_changed":false,"proximity_changed":false,"clock_changed":false})
func capture_observation() -> Dictionary:
 var result: Dictionary = super.capture_observation()
 result["private_mask_support_candidate"] = corrected_materials
 result["selected_occurrence"] = "finger_of_death__normal_back:impact"
 result["bounded_recorded_evidence"] = "v131 private equivalent, 56frames/native2.667; no human approval"
 return result
