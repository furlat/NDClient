extends Node3D
## Real IceSurface owner, with original source decal textures on supplied cells.
const Native=preload("res://assets/vfx/sources/a3ec7774922fb78f255c/native_materials.gd")
const Footprint=preload("res://assets/vfx/sources/4d63f507234a77da8092/observed_footprint.gd")
const ICE="res://assets/vfx/sources/151c0c74d9338c7a3c7a/texture.res"
const ORM="res://assets/vfx/sources/09e7d31aaa750c933e38/texture.res"
var specification: Dictionary={}
var state: Dictionary={}
var endpoints: Array=[]
var draw: MeshInstance3D
var material: ShaderMaterial
static func make_component(input: Dictionary) -> Node3D:
 var node: Node3D=VfxPackageIO_460b56ed36.resource("res://assets/vfx/sources/460b56ed364586c04386/observed_ice.gd").new();node.specification=input.duplicate(true);node.set_surface_state(input.get("state",{}));return node
func set_surface_state(value: Dictionary) -> bool:
 if draw!=null:draw.hide()
 state.clear()
 if str(value.get("surface_uuid",""))!=str(specification.get("surface_uuid","")) or str(value.get("surface_kind",""))!="spatial_effect.material.ice":return false
 if value.get("admitted_cells",[]).is_empty():return false
 state=value.duplicate(true)
 if draw!=null:draw.mesh=Footprint.plane(state.admitted_cells);Footprint.set_cells(material,state.admitted_cells)
 return true
func set_live_endpoints(value: Array) -> void:endpoints=value
func sample(seconds: float) -> void:
 if draw==null:
  var shader=Shader.new();shader.code="""shader_type spatial;
render_mode blend_mix,cull_disabled,unshaded;
uniform sampler2D native_ice:source_color,repeat_enable,filter_linear_mipmap;
uniform sampler2D native_orm:repeat_enable,filter_linear_mipmap;
uniform float payload_alpha=0.0;
varying vec2 native_ice_world;
void vertex(){vec4 ice_world4=MODEL_MATRIX*vec4(VERTEX,1.0);native_ice_world=ice_world4.xz;}
void fragment(){vec4 ice=texture(native_ice,native_ice_world*0.31);vec3 orm=texture(native_orm,native_ice_world*0.31).rgb;ALBEDO=ice.rgb*0.55;ROUGHNESS=orm.g;METALLIC=orm.b;ALPHA=(0.45+0.55*ice.a)*payload_alpha;}
""";material=ShaderMaterial.new();material.shader=shader;material.set_shader_parameter("native_ice",VfxPackageIO_460b56ed36.resource(ICE));material.set_shader_parameter("native_orm",VfxPackageIO_460b56ed36.resource(ORM))
  Footprint.bind(material,state.get("admitted_cells",specification.get("admitted_cells",[])));draw=Native.draw(self,"ObservedNativeIceFloor",Footprint.plane(state.get("admitted_cells",specification.get("admitted_cells",[]))),material);draw.top_level=true
 draw.hide();material.set_shader_parameter("payload_alpha",0.0)
 if not Native.observed(state) or endpoints.is_empty():return
 var alpha=Native.envelope(specification,seconds)*.36
 draw.global_transform=Transform3D(Basis.IDENTITY,endpoints[0].point);Footprint.move(material,endpoints[0].point);material.set_shader_parameter("payload_alpha",alpha);draw.visible=alpha>.001
func capture_observation() -> Dictionary:
 return {"surface_uuid":specification.surface_uuid,"supplied_surface_state":state,"visible":draw!=null and draw.visible,"original_source_textures":[ICE,ORM],"ten_native_rounds_counted_here":false,"computes_membership_or_slip":false,"separate_payload_owner":true,"optical_lights":0}

const VfxPackageIO_460b56ed36 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
