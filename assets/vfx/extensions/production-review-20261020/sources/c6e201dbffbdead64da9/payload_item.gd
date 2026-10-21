extends Node3D
## Exact real payload identity. Supplied location/power/state own all behavior.
const Native=preload("res://assets/vfx/extensions/late-20261020/sources/a3ec7774922fb78f255c/native_materials.gd")
var specification: Dictionary={}
var state: Dictionary={}
var endpoints: Array=[]
var draws: Array[MeshInstance3D]=[]
var materials: Array[ShaderMaterial]=[]
var visible_owner=false
var rejection="unbound"
static func make_component(input: Dictionary) -> Node3D:
 assert(input.get("kind","") in ["freezing","delayed_fire"] and not str(input.get("item_uuid","")).is_empty())
 assert(not str(input.get("lifetime_uuid","")).is_empty() and not str(input.get("original_caster_uuid","")).is_empty())
 var node: Node3D=VfxPackageIO_c6e201dbff.resource("res://assets/vfx/extensions/production-review-20261020/sources/c6e201dbffbdead64da9/payload_item.gd").new();node.specification=input.duplicate(true);node.set_payload_state(input.get("state",{}));return node
func set_payload_state(value: Dictionary) -> bool:
 for draw in draws:draw.hide()
 state.clear();rejection="payload_identity"
 for key in ["item_uuid","lifetime_uuid","original_caster_uuid","kind"]:
  if str(value.get(key,""))!=str(specification.get(key,"")):return false
 if str(value.get("item_id",""))!=("spell_payload.freezing_sphere" if specification.kind=="freezing" else "spell_payload.delayed_fireball"):return false
 if not value.has("dice_count") or not value.has("spell_dc"):rejection="retained_power_snapshot_missing";return false
 state=value.duplicate(true);rejection="";return true
func set_payload_anchor(value: Dictionary) -> bool:
 for draw in draws:draw.hide()
 specification.anchor_binding={}
 if str(value.get("item_uuid",""))!=str(specification.item_uuid) or not bool(value.get("observed",false)):return false
 specification.anchor_binding=value.duplicate(true);return true
func set_live_endpoints(value: Array) -> void:endpoints=value
func prepare() -> void:
 var sphere=SphereMesh.new();sphere.radial_segments=24;sphere.rings=14
 if specification.kind=="freezing":
  for surface in [false,true]:
   var material=Native.ice(surface);materials.append(material);draws.append(Native.draw(self,"NativeCrystallinePayloadLayer",sphere,material))
 else:
  var material=Native.fire();materials.append(material);draws.append(Native.draw(self,"NativeRetainedFireballBead",Native.fire_source().mesh,material))
 for draw in draws:draw.top_level=true
func sample(seconds: float) -> void:
 if draws.is_empty():prepare()
 for i in draws.size():draws[i].hide();Native.clock(materials[i],seconds,0.0)
 visible_owner=false
 if not Native.observed(state) or bool(state.get("retired",true)) or not bool(state.get("lifetime_present",false)) or endpoints.is_empty():return
 if str(state.get("location_kind","")) not in ["exposed_hand","floor","exposed_container"]:return
 var binding: Dictionary=specification.get("anchor_binding",{})
 if str(binding.get("item_uuid",""))!=str(state.item_uuid) or not bool(binding.get("observed",false)):rejection="exact_item_anchor_missing";return
 if str(binding.get("location_owner_uuid",""))!=str(state.get("location_owner_uuid","")):rejection="current_location_owner";return
 if str(binding.get("location_kind",""))!=str(state.location_kind):rejection="current_location_kind";return
 var alpha=Native.envelope(specification,seconds)
 var point: Vector3=endpoints[0].point
 if state.location_kind=="floor":point+=Vector3(0,.11,0)
 var radius=.055 if specification.kind=="freezing" else .035+.001*clampf(float(state.dice_count)-float(specification.get("base_power",12)),0.0,10.0)
 for i in draws.size():
  var scale=radius*2.0*(1.14 if i==1 else 1.0)
  draws[i].global_transform=Transform3D(Basis(Vector3.UP,seconds*.35)*Basis.from_scale(Vector3.ONE*scale),point);draws[i].visible=alpha>.001
  if specification.kind=="delayed_fire":Native.fire_clock(materials[i],seconds,alpha*.8,.30+.03*sin(seconds*3.0))
  else:Native.clock(materials[i],seconds,alpha*(.6 if i==1 else .9))
 visible_owner=alpha>.001;rejection=""
func capture_observation() -> Dictionary:
 return {"item_uuid":specification.item_uuid,"lifetime_uuid":specification.lifetime_uuid,"original_caster_uuid":specification.original_caster_uuid,"state":state,"exact_anchor_binding":specification.get("anchor_binding",{}),"visible":visible_owner,"rejection":rejection,"power_or_clock_computed":false,"original_cast_position_used":false,"automatic_created_item_presentation":false,"optical_lights":0}

const VfxPackageIO_c6e201dbff = preload("res://assets/vfx/extensions/production-review-20261020/scoped_resource_io.gd")
