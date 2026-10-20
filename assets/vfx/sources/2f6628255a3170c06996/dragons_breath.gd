extends Node3D
## Recipient-owned grant and a finite native cone from that acting recipient's face.
const Native=preload("res://assets/vfx/sources/be83e762baa1da26d392/native_sources.gd")
var specification: Dictionary={}
var state: Dictionary={}
var endpoints: Array=[]
var draw: MeshInstance3D
var material: ShaderMaterial
var launch_seconds=.3
var travel_seconds=.35
var origin=Vector3.ZERO
var heading=Vector3.ZERO
var active=false
var binding_diagnostic: Dictionary={}
static func make_component(input: Dictionary) -> Node3D:
 assert(input.get("element","") in ["acid","cold","fire","lightning","poison"] and not str(input.get("grant_uuid","")).is_empty() and not str(input.get("recipient_uuid","")).is_empty())
 var effect: Node3D=VfxPackageIO_2f6628255a.resource("res://assets/vfx/sources/2f6628255a3170c06996/dragons_breath.gd").new();effect.specification=input.duplicate(true);effect.set_grant_state(input.get("state",{}));return effect
func set_grant_state(value: Dictionary) -> bool:
 state.clear()
 if str(value.get("grant_uuid",""))!=str(specification.grant_uuid) or str(value.get("recipient_uuid",""))!=str(specification.recipient_uuid) or str(value.get("original_caster_uuid",""))!=str(specification.original_caster_uuid):return false
 if str(value.get("element",""))!=str(specification.element):return false
 state=value.duplicate(true);return true
func set_live_endpoints(value: Array) -> void:endpoints=value
func set_delivery_timing(launch: float,travel: float) -> void:launch_seconds=maxf(launch,0.0);travel_seconds=maxf(travel,.001)
func sample(seconds: float) -> void:
 if draw==null:
  material=Native.element(str(specification.element),str(specification.phase)=="exhale")
  draw=Native.draw(self,"NativeRecipientBreathCone" if specification.phase=="exhale" else "NativeElementalGrant",VfxPackageIO_2f6628255a.resource(Native.CONE),material);draw.top_level=true
 draw.hide();active=false;Native.clock(material,seconds,0.0)
 if not Native.observed(state):return
 if specification.phase=="exhale":
  if endpoints.size()<3 or not bool(state.get("recipient_action_discovered",false)) or str(specification.get("acting_recipient_uuid",""))!=str(specification.recipient_uuid):return
  origin=endpoints[1].point
  heading=endpoints[2].point-endpoints[0].point;heading.y=0.0
  if heading.is_zero_approx():return
  heading=heading.normalized()
  var alpha=smoothstep(0.0,.13,seconds)*(1.0-smoothstep(.65,1.0,seconds))
  # Original cone Y axis becomes forward. Source radial dimensions are scaled
  # to the supplied15ft presentation; no cells/targets are solved by this VFX.
  var axes=Basis.looking_at(heading,Vector3.UP)*Basis(Vector3.RIGHT,Vector3.FORWARD,Vector3.UP)
  draw.global_transform=Transform3D(axes*Basis.from_scale(Vector3(.728,.613,.35)),origin)
  material.set_shader_parameter("cone_origin",origin);material.set_shader_parameter("cone_forward",heading);material.set_shader_parameter("cone_length",3.0)
  draw.visible=alpha>.001;Native.clock(material,seconds,alpha*.68);active=draw.visible
 else:
  if endpoints.size()<3:return
  var preparing=seconds<launch_seconds;var u=clampf((seconds-launch_seconds)/travel_seconds,0.0,1.0)
  var alpha=smoothstep(0.0,.18,seconds)*(1.0-smoothstep(launch_seconds+travel_seconds,launch_seconds+travel_seconds+.2,seconds))
  origin=endpoints[0].point if preparing else (endpoints[2].point as Vector3).lerp(endpoints[1].point,u)
  heading=(endpoints[1].point-endpoints[2].point).normalized()
  if heading.is_zero_approx():heading=Vector3.UP
  var axes=Basis(Quaternion(Vector3.UP,heading));draw.global_transform=Transform3D(axes.scaled(Vector3.ONE*.045),origin)
  draw.visible=alpha>.001;Native.clock(material,seconds,alpha*.65);active=draw.visible
func _read_only_binding_diagnostic() -> Dictionary:
 if not binding_diagnostic.is_empty():return binding_diagnostic
 if str(specification.element)!="cold" or str(specification.phase)!="exhale" or not active:return {}
 var result={"phase_seconds":material.get_shader_parameter("ward_seconds"),"ward_alpha":material.get_shader_parameter("ward_alpha"),"cone_origin":material.get_shader_parameter("cone_origin"),"cone_forward":material.get_shader_parameter("cone_forward"),"cone_length":material.get_shader_parameter("cone_length"),"draw_transform":draw.global_transform,"draw_layers":draw.layers,"draw_in_tree":draw.is_visible_in_tree(),"native_shader_sha256":material.shader.code.sha256_text(),"active_material_matches":draw.get_active_material(0)==material,"textures":{}}
 for key in ["mask1_texture","mask2_texture","mask3_texture"]:
  var texture: Texture2D=material.get_shader_parameter(key)
  var info={"bound":texture!=null}
  if texture!=null:
   info["class"]=texture.get_class();info["size"]=texture.get_size();info["rid_valid"]=texture.get_rid().is_valid()
   var picture=texture.get_image();info["readback_available"]=picture!=null and not picture.is_empty()
   if picture!=null and not picture.is_empty():
    var low=1.0;var high=0.0;var total=0.0;var count=0
    for y in range(0,picture.get_height(),8):
     for x in range(0,picture.get_width(),8):
      var value=picture.get_pixel(x,y).r;low=minf(low,value);high=maxf(high,value);total+=value;count+=1
    info["minimum_r"]=low;info["maximum_r"]=high;info["mean_r"]=total/maxi(count,1)
   if texture is GradientTexture2D:info["gradient"]=texture.gradient.colors;info["fill_from"]=texture.fill_from;info["fill_to"]=texture.fill_to;info["fill"]=texture.fill
  result.textures[key]=info
 for key in ["alpha_mode","alpha_multiplier","alpha_smoothness","use_mask2","use_mask3","mask2_blend_mode","mask3_blend_mode","billboard","factory_occurrence_alpha"]:result[key]=material.get_shader_parameter(key)
 binding_diagnostic=result;return result
func capture_observation() -> Dictionary:
 return {"read_only_cold_binding_diagnostic":_read_only_binding_diagnostic(),"phase":specification.phase,"grant_uuid":specification.grant_uuid,"recipient_uuid":specification.recipient_uuid,"original_caster_uuid":specification.original_caster_uuid,"explicit_retained_element":specification.element,"acting_recipient_uuid":specification.get("acting_recipient_uuid",""),"origin":origin,"heading":heading,"range_cells":3.0,"source_material":Native.ELEMENTS[specification.element],"source_mesh":Native.CONE,"visible":active,"original_dc_level_retained_externally":true,"source_socket":"face" if specification.phase=="exhale" else "current_hand","solves_area_save_damage_or_surface":false,"optical_lights":0,"observer_element_snapshot_gap":true}

func source_bindings() -> Dictionary:
 return {"geometry":[draw],"materials":[material],"static_material_topology":true}

const VfxPackageIO_2f6628255a = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
