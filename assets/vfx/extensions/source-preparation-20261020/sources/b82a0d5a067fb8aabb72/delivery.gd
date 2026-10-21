extends Node3D
## Current hand preparation/release to an explicitly admitted recipient/ground.
const Native=preload("res://assets/vfx/extensions/late-20261020/sources/a3ec7774922fb78f255c/native_materials.gd")
var specification: Dictionary={}
var endpoints: Array=[]
var draws: Array[MeshInstance3D]=[]
var materials: Array[ShaderMaterial]=[]
var launch_seconds=.3
var travel_seconds=.45
var point=Vector3.ZERO
var heading=Vector3.ZERO
var release_snapshot=Vector3.ZERO
var release_captured=false
var authoritative_release=false
var previous_seconds=-1.0
static func make_component(input: Dictionary) -> Node3D:
 assert(input.get("kind","") in ["acid","freezing","delayed_fire"])
 var node: Node3D=VfxPackageIO_b82a0d5a06.resource("res://assets/vfx/extensions/source-preparation-20261020/sources/b82a0d5a067fb8aabb72/delivery.gd").new();node.specification=input.duplicate(true);return node
func set_live_endpoints(value: Array) -> void:endpoints=value
func set_accepted_release(value: Dictionary) -> bool:
 if not bool(value.get("observed",false)) or not bool(value.get("release_accepted",false)) or str(value.get("event_uuid",""))=="":return false
 if str(value.get("acting_holder_uuid",""))!=str(specification.get("acting_holder_uuid",specification.get("caster_uuid",""))) or value.get("point") is not Vector3:return false
 release_snapshot=value.point;release_captured=true;authoritative_release=true;return true
func set_delivery_timing(launch: float,travel: float) -> void:launch_seconds=maxf(0.0,launch);travel_seconds=maxf(.001,travel)
func prepare() -> void:
 var sphere=SphereMesh.new();sphere.radial_segments=24;sphere.rings=14
 var count=3 if specification.kind=="acid" else 2 if specification.kind=="freezing" else 1
 for i in count:
  var material=Native.acid() if specification.kind=="acid" else Native.ice(i==1) if specification.kind=="freezing" else Native.fire()
  materials.append(material);draws.append(Native.draw(self,"NativeDistinctPayloadPreparationTravel"+str(i),sphere if specification.kind!="delayed_fire" else Native.fire_source().mesh,material));draws[i].top_level=true
func sample(seconds: float) -> void:
 if draws.is_empty():prepare()
 for i in draws.size():draws[i].hide();Native.clock(materials[i],seconds,0.0)
 if not bool(specification.get("cast_or_throw_accepted",false)) or endpoints.size()<3:return
 var preparing=seconds<launch_seconds;var u=clampf((seconds-launch_seconds)/travel_seconds,0.0,1.0)
 if not authoritative_release:
  if seconds<previous_seconds:release_captured=false
  if preparing:release_snapshot=endpoints[0].point;release_captured=true
 previous_seconds=seconds
 if specification.get("release_mode","")=="current_holder_hand" and not release_captured:return
 var release: Vector3=release_snapshot if authoritative_release or specification.get("release_mode","")=="current_holder_hand" else endpoints[2].point
 var destination: Vector3=endpoints[1].point
 point=endpoints[0].point if preparing else release.lerp(destination,u)
 heading=(destination-release).normalized()
 if heading.is_zero_approx():heading=Vector3.FORWARD
 var alpha=smoothstep(0.0,.18,seconds)*(1.0-smoothstep(launch_seconds+travel_seconds,launch_seconds+travel_seconds+.12,seconds))
 # A formed globe/bead retires at the supplied delivery contact before its
 # blast/inventory presentation. It must not fade as a duplicate live item.
 if specification.kind in ["freezing","delayed_fire"] and seconds>=launch_seconds+travel_seconds:alpha=0.0
 var basis=Basis.looking_at(heading,Vector3.UP if absf(heading.y)<.99 else Vector3.RIGHT)
 var formation=.5+.5*clampf(seconds/maxf(.001,launch_seconds),0.0,1.0)
 for i in draws.size():
  var size=Vector3(.19,.14,.26) if specification.kind=="acid" else Vector3.ONE*(.18 if i==0 else .21) if specification.kind=="freezing" else Vector3.ONE*.075
  var offset=basis*Vector3(.04*float(i-1),.025*float(i%2),.07*float(i-1)) if specification.kind=="acid" else Vector3.ZERO
  draws[i].global_transform=Transform3D(basis*Basis.from_scale(size*formation),point+offset);draws[i].visible=alpha>.001
  if specification.kind=="delayed_fire":Native.fire_clock(materials[i],seconds,alpha*.8,.3)
  else:Native.clock(materials[i],seconds,alpha*(.52 if specification.kind=="freezing" and i==1 else .85))
func capture_observation() -> Dictionary:
 return {"kind":specification.kind,"current_source_actor_uuid":specification.get("acting_holder_uuid",specification.get("caster_uuid","")),"point":point,"heading":heading,"accepted":specification.get("cast_or_throw_accepted",false),"launch_seconds":launch_seconds,"travel_seconds":travel_seconds,"release_snapshot":release_snapshot,"release_captured":release_captured,"authoritative_release":authoritative_release,"source_socket":"current supplied hand; preview holder release caches last prelaunch sample; exact native set_accepted_release state is integration input","flight_moves_item_or_solves_impact":false,"optical_lights":0}

const VfxPackageIO_b82a0d5a06 = preload("res://assets/vfx/extensions/source-preparation-20261020/scoped_resource_io.gd")
