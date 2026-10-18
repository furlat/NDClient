extends RefCounted
## Inspected common native material layers. No complete unrelated spell copy.
const Graph=preload("res://assets/vfx/sources/1d02b6d800655ef86df2/resource_graph.gd")
const Source=preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
const ACID="res://assets/vfx/sources/b04b42a4923c6a72466f/acid_native.tres"
const FIRE="res://assets/vfx/sources/a8722f23fa2473f95558/fireball_native.tres"
const ICE_CORE="res://assets/vfx/sources/7930926904ee91afb592/ice_ball_03_core.tres"
const ICE_SURFACE="res://assets/vfx/sources/fcf94b08d428cd3cc60b/ice_ball_03_surface.tres"
static func finite(original: ShaderMaterial,gain: float) -> ShaderMaterial:
 Graph.native_sampler_scopes+=1;var material: ShaderMaterial=Graph.clone_value(original,{});Graph.native_sampler_scopes-=1
 var code=Source.stable_proximity(Source.expand_shader(original.shader.code,original.shader.resource_path.get_base_dir()))
 code=code.replace("depth_draw_always","depth_draw_never")
 code=code.replace("smoothstep(Fill,0.0,n_out58p1)","(1.0-smoothstep(0.0,max(Fill,0.0001),n_out58p1))")
 code=code.replace("smoothstep(n_out33p4, n_in20p1, n_out38p1)","smoothstep(min(n_out33p4,0.9999),n_in20p1,n_out38p1)")
 var token=RegEx.new();token.compile("\\bTIME\\b");code=token.sub(code,"payload_seconds",true)
 code=code.replace("shader_type spatial;","shader_type spatial;\nuniform float payload_seconds=0.0;\nuniform float payload_alpha=0.0;")
 var alpha_statement="ALPHA*=payload_alpha;" if code.contains("ALPHA =") or code.contains("ALPHA=") else "ALPHA=payload_alpha;"
 code=Source.finish_fragment(code,"\nALBEDO*="+str(gain)+";EMISSION*="+str(gain)+";"+alpha_statement+"\n")
 var shader=Shader.new();shader.code=code;Source.replace_shader(material,shader);return material
static func acid() -> ShaderMaterial:return finite(VfxPackageIO_a3ec777492.resource(ACID),.24)
static func ice(surface: bool=false) -> ShaderMaterial:
 var material=finite(VfxPackageIO_a3ec777492.resource(ICE_SURFACE if surface else ICE_CORE),.22 if surface else .28)
 material.set_shader_parameter("alpha_mode",0)
 material.set_shader_parameter("emission_strength",.7 if surface else .3)
 if not surface:material.set_shader_parameter("displacement_scale",.18)
 return material
static var retained_fire_source: Resource
static func fire_source() -> Resource:
 if retained_fire_source==null:retained_fire_source=VfxPackageIO_a3ec777492.resource(FIRE)
 return retained_fire_source
static func fire() -> ShaderMaterial:
 var bundle=fire_source();var material=finite(bundle.material,.14)
 var code=material.shader.code.replace("shader_type spatial;","shader_type spatial;\nuniform vec4 payload_source_color=vec4(0.0,0.0,0.0,0.0);")
 code=code.replace("void vertex() {","void vertex() {\nCOLOR=payload_source_color;\n")
 var shader=Shader.new();shader.code=code;Source.replace_shader(material,shader);return material
static func fire_burst() -> ShaderMaterial:
 var material=fire()
 # The donor's particle COLOR encodes one temperature per emitter particle.
 # A sparse native mesh burst needs source texture variation across each puff,
 # not eleven uniformly coloured solids. Reuse its actual displacement noise
 # and original dark/emission gradients; source dissolve and clocks remain.
 var code=Source.finish_fragment(material.shader.code,"""
 float native_fire_flow=texture(Dissplacement_texture,UV+payload_seconds*Displacement_Speed).r;
 float native_fire_temperature=clamp(COLOR.r+(native_fire_flow-0.5)*0.55,0.0,1.0);
 ALBEDO=texture(Dark_Color_Gradient_1D,vec2(native_fire_temperature)).rgb*0.14;
 EMISSION=texture(Emission_Gradient_1D,vec2(native_fire_temperature)).rgb*0.14;
 ALPHA*=smoothstep(0.18,0.52,native_fire_flow);
 """)
 var shader=Shader.new();shader.code=code;Source.replace_shader(material,shader);return material
static func fire_clock(material: ShaderMaterial,seconds: float,alpha: float,source_age: float) -> void:
 var bundle=fire_source();var point=clampf(source_age,0.0,.98)
 var color: Color=bundle.source_color.sample(point);color.a=bundle.source_alpha.sample(point)
 material.set_shader_parameter("payload_source_color",color);clock(material,seconds,alpha)
static func draw(parent: Node3D,label: String,mesh: Mesh,material: Material) -> MeshInstance3D:
 var node=MeshInstance3D.new();node.name=label;node.mesh=mesh;node.material_override=material;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;node.hide();parent.add_child(node);return node
static func clock(material: ShaderMaterial,seconds: float,alpha: float) -> void:
 material.set_shader_parameter("payload_seconds",maxf(seconds,0.0));material.set_shader_parameter("payload_alpha",clampf(alpha,0.0,1.0))
static func observed(state: Dictionary) -> bool:
 return bool(state.get("present",false)) and bool(state.get("observed",false)) and bool(state.get("contributions_active",false)) and not bool(state.get("suppressed",true))
static func envelope(specification: Dictionary,seconds: float) -> float:
 if seconds<0.0:return 0.0
 var alpha=smoothstep(0.0,.2,seconds)
 if specification.get("lifecycle_mode","")=="recorded_fixture":alpha*=1.0-smoothstep(float(specification.retire_at_seconds),float(specification.retire_at_seconds)+.25,seconds)
 return alpha

const VfxPackageIO_a3ec777492 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
