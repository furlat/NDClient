extends RefCounted
## Inspected selected native masks/materials, never entire unrelated effects.
const Graph=preload("res://assets/vfx/sources/1d02b6d800655ef86df2/resource_graph.gd")
const Source=preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
const CONE="res://assets/vfx/sources/90363fadea5df270b1fb/sm_flamethrower_l2.res"
const ELEMENTS={"thunder":"res://assets/vfx/sources/dd903604bf5fc6524309/wind_native.tres","fire":"res://assets/vfx/sources/c5ad74ab3c07ce02119f/m_fireflameth4.tres","acid":"res://assets/vfx/sources/6ff209a98aedfb2bcb41/acid_native.tres","cold":"res://assets/vfx/sources/ffded0928bacd3bd740f/ice_mist_04_mist.tres","poison":"res://assets/vfx/sources/70be1c02a6cdaa3372d3/stink_small_02_clouds_01.tres","lightning":"res://assets/vfx/sources/5d37dbe1ea3b5e8b3ebb/electric_tail_native.tres"}
static func finite(original: ShaderMaterial,gain: float) -> ShaderMaterial:
 Graph.native_sampler_scopes+=1
 var material: ShaderMaterial=Graph.clone_value(original,{})
 Graph.native_sampler_scopes-=1
 var code=Source.expand_shader(original.shader.code,original.shader.resource_path.get_base_dir())
 code=Source.stable_proximity(code)
 code=code.replace("smoothstep(Fill,0.0,n_out58p1)","(1.0-smoothstep(0.0,max(Fill,0.0001),n_out58p1))")
 code=code.replace("clamp(0.5 - (alpha_smoothness * .5), 0.5 + (alpha_smoothness * .5), mask_value)","clamp(mask_value,0.5-(alpha_smoothness*.5),0.5+(alpha_smoothness*.5))")
 var token=RegEx.new();token.compile("\\bTIME\\b");code=token.sub(code,"ward_seconds",true)
 code=code.replace("shader_type spatial;","shader_type spatial;\nuniform float ward_seconds=0.0;\nuniform float ward_alpha=0.0;")
 code=Source.finish_fragment(code,"\nALBEDO*="+str(gain)+";\nEMISSION*="+str(gain)+";\nALPHA*=ward_alpha;\n")
 var shader=Shader.new();shader.code=code;Source.replace_shader(material,shader);return material
static func element(kind: String,cone: bool=false) -> ShaderMaterial:
 assert(ELEMENTS.has(kind),"Explicit supplied native element is required")
 var material=finite(VfxPackageIO_be83e762ba.resource(ELEMENTS[kind]),.11 if kind in ["fire","acid"] else .55 if kind in ["cold","poison"] else .42)
 # Particle billboard orientation cannot replace the admitted 3D cone carrier.
 if kind in ["cold","poison"]:
  material.set_shader_parameter("billboard",false);material.set_shader_parameter("emission_strength",.35)
  # Three original multiplicative masks followed by cubic alpha disappear on
  # the cone. Retain all source masks/clock/colours, soften opacity response.
  var code=material.shader.code.replace("pow(alpha_mask, 3.0)","pow(max(alpha_mask,0.0),0.65)")
  # This native particle material now covers a static, two-sided source mesh.
  # Its former emitter supplied COLOR; the mesh has no colour vertex channel.
  code=code.replace("render_mode blend_mix;","render_mode blend_mix,cull_disabled;")
  if kind=="cold":code=code.replace("render_mode blend_mix,cull_disabled;","render_mode blend_mix,cull_disabled,unshaded;")
  code=Source.finish_function(code,"vertex","\nCOLOR=vec4(1.0);\n")
  var shader=Shader.new();shader.code=code;Source.replace_shader(material,shader)
 if kind=="fire":material.set_shader_parameter("wobble_strength",.18)
 if cone:
  var code=material.shader.code
  code=code.replace("uniform float ward_alpha=0.0;","uniform float ward_alpha=0.0;\nuniform vec3 cone_origin=vec3(0.0);\nuniform vec3 cone_forward=vec3(0.0,0.0,-1.0);\nuniform float cone_length=3.0;\nvarying vec3 cone_world;")
  var record="\nvec4 actual_cone_world4=MODEL_MATRIX*vec4(VERTEX,1.0);cone_world=actual_cone_world4.xyz;\n"
  if code.contains("void vertex()"):
   code=Source.finish_function(code,"vertex",record)
  else:code+="\nvoid vertex(){"+record+"}\n"
  code=Source.finish_fragment(code,"""
   vec3 relative=cone_world-cone_origin;
   float along=dot(relative,cone_forward);
   float across=length(relative-cone_forward*along);
   float width=max(0.04,along*0.5);
   float end_cover=1.0-smoothstep(cone_length-0.22,cone_length,along);
   float side_cover=1.0-smoothstep(max(0.0,width-0.10),width,across);
   ALPHA*=smoothstep(-0.02,0.025,along)*end_cover*side_cover;
  """)
  var shader=Shader.new();shader.code=code;Source.replace_shader(material,shader)
 return material
static func rune() -> ShaderMaterial:
 var material=finite(VfxPackageIO_be83e762ba.resource("res://assets/vfx/sources/15e998736200a1a620df/rune_native.tres"),.16)
 material.set_shader_parameter("Vanishing",.05)
 # Generic perceived spatial state discloses no payload. Preserve native rune
 # mask/erosion and output a neutral luminance instead of inventing an element.
 var original_code=material.shader.code.replace("depth_draw_opaque","depth_draw_never")
 original_code=original_code.replace("ALPHA_SCISSOR_THRESHOLD = n_out6p0;","ALPHA*=smoothstep(n_out6p0,n_out6p0+0.08,n_out18p0);")
 var code=Source.finish_fragment(original_code,"\nALBEDO=vec3(dot(ALBEDO,vec3(0.2126,0.7152,0.0722)));\n")
 var shader=Shader.new();shader.code=code;Source.replace_shader(material,shader);return material
static func draw(parent: Node3D,label: String,mesh: Mesh,material: Material) -> MeshInstance3D:
 var node=MeshInstance3D.new();node.name=label;node.mesh=mesh;node.material_override=material;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;node.hide();parent.add_child(node);return node
static func clock(material: ShaderMaterial,seconds: float,alpha: float) -> void:
 material.set_shader_parameter("ward_seconds",maxf(seconds,0.0));material.set_shader_parameter("ward_alpha",clampf(alpha,0.0,1.0))
static func observed(state: Dictionary) -> bool:
 return bool(state.get("present",false)) and bool(state.get("observed",false)) and bool(state.get("contributions_active",false)) and not bool(state.get("suppressed",true))
static func fixture_envelope(specification: Dictionary,seconds: float) -> float:
 var alpha=smoothstep(0.0,.2,seconds)
 if str(specification.get("lifecycle_mode","owned_state"))=="recorded_fixture":alpha*=1.0-smoothstep(float(specification.retire_at_seconds),float(specification.retire_at_seconds)+.3,seconds)
 return alpha

const VfxPackageIO_be83e762ba = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
