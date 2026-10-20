extends RefCounted
## Selected source fire only. Masks, hue and native scroll are preserved.
const Graph=preload("res://assets/vfx/sources/1d02b6d800655ef86df2/resource_graph.gd")
const Source=preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
const BALL="res://assets/vfx/extensions/continuation42-20261020/sources/743a74035cd215eb0188/VFX_Fire_ball_standar.tscn"
const AURA="res://assets/vfx/sources/95d9c64322a82e35653e/s_magic_aura.tres"
const TORCH="res://assets/vfx/sources/c5ad74ab3c07ce02119f/m_fireflameth4.tres"
const CONE="res://assets/vfx/sources/90363fadea5df270b1fb/sm_flamethrower_l2.res"
const NOISE="res://assets/vfx/sources/8bc8bf311494b7cec395/texture.res"
static func finite(original: ShaderMaterial, gain: float, axial_uv: bool=false) -> ShaderMaterial:
 Graph.native_sampler_scopes+=1
 var material: ShaderMaterial=Graph.clone_value(original,{})
 Graph.native_sampler_scopes-=1
 var code=Source.expand_shader(original.shader.code,original.shader.resource_path.get_base_dir())
 code=code.replace("smoothstep(Fill,0.0,n_out58p1)","(1.0-smoothstep(0.0,max(Fill,0.0001),n_out58p1))")
 var token=RegEx.new();token.compile("\\bTIME\\b")
 code=token.sub(code,"fire_owner_seconds",true)
 if axial_uv:
  var uv=RegEx.new();uv.compile("\\bUV\\b");code=uv.sub(code,"UV2",true)
 code=code.replace("shader_type spatial;","shader_type spatial;\nuniform float fire_owner_seconds=0.0;\nuniform float fire_owner_alpha=0.0;")
 code=Source.finish_fragment(code,"\nALBEDO*="+str(gain)+";\nEMISSION*="+str(gain)+";\nALPHA*=fire_owner_alpha;\n")
 var shader=Shader.new();shader.code=code;Source.replace_shader(material,shader)
 return material
static func flame(gain: float=.4, axial_uv: bool=false, breakup: bool=false) -> ShaderMaterial:
 var result=finite(VfxPackageIO_cb6c8716b8.resource(TORCH),gain,axial_uv)
 result.set_shader_parameter("wobble_strength",.28)
 if axial_uv:result.set_shader_parameter("enable_vertex_movement",false)
 if breakup:
  # Original native gradient has opaque black stops. Treat the same sampled
  # source fire value as coverage, so dark membranes do not expose the carrier.
  var code=Source.finish_fragment(result.shader.code,"\nALPHA*=smoothstep(0.04,0.28,n_out57p0);\n")
  var shader=Shader.new();shader.code=code;Source.replace_shader(result,shader)
 return result
static func aura() -> ShaderMaterial:
 var source=ShaderMaterial.new();source.shader=VfxPackageIO_cb6c8716b8.resource(AURA)
 source.set_shader_parameter("Aura_Color",Color(.952941,.34902,.0235294,1))
 source.set_shader_parameter("Aura_Divide",Vector2(.8,.8))
 source.set_shader_parameter("Speed",Vector2(.1,-1))
 source.set_shader_parameter("Aura_Texture",VfxPackageIO_cb6c8716b8.resource(NOISE))
 # Measured geometry is already the exact silhouette. The donor's absent Mask
 # is not substituted by an unrelated texture or a fitted sword silhouette.
 source.set_shader_parameter("Has_mask",false)
 return finite(source,.14,true)
static func selected(label: String, gain: float) -> Dictionary:
 if label=="FireVolume":
  # Exact K1 source sphere/material selection; no GPUTrail or donor light loads.
  var mesh=SphereMesh.new();mesh.radial_segments=24;mesh.rings=15
  return {"mesh":mesh,"material":finite(VfxPackageIO_cb6c8716b8.resource("res://assets/vfx/sources/dae15c0f6786fc9b6d4a/fireball_k1_native.tres"),gain),"transform":Transform3D.IDENTITY}
 var donor=VfxPackageIO_cb6c8716b8.resource(BALL).instantiate()
 var draw: MeshInstance3D=donor.get_node(label)
 var result={"mesh":draw.mesh,"material":finite(draw.material_override,gain),"transform":draw.transform}
 donor.free();return result
static func draw(parent: Node3D,label: String,mesh: Mesh,material: Material) -> MeshInstance3D:
 var node=MeshInstance3D.new();node.name=label;node.mesh=mesh;node.material_override=material
 node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;node.hide();parent.add_child(node);return node
static func clock(material: ShaderMaterial,seconds: float,alpha: float) -> void:
 material.set_shader_parameter("fire_owner_seconds",maxf(seconds,0.0))
 material.set_shader_parameter("fire_owner_alpha",clampf(alpha,0.0,1.0))
static func observed(state: Dictionary) -> bool:
 return bool(state.get("present",false)) and bool(state.get("observed",false)) and not bool(state.get("suppressed",true))
static func fixture_envelope(settings: Dictionary,seconds: float) -> float:
 if seconds<0.0:return 0.0
 var alpha=smoothstep(0.0,float(settings.get("birth_seconds",.18)),seconds)
 if settings.get("lifecycle_mode", "owned_state")=="recorded_fixture":
  var retirement=float(settings.retire_at_seconds)
  alpha*=1.0-smoothstep(retirement,retirement+.3,seconds)
 return alpha

const VfxPackageIO_cb6c8716b8 = preload("res://assets/vfx/extensions/continuation42-20261020/scoped_resource_io.gd")
