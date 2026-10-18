extends Node3D
## Brief native surface response from one explicit applied recipient packet.
const Native=preload("res://assets/vfx/sources/a3ec7774922fb78f255c/native_materials.gd")
var specification: Dictionary={}
var event: Dictionary={}
var endpoints: Array=[]
var geometry: Dictionary={}
var draws: Array[MeshInstance3D]=[]
var materials: Array[ShaderMaterial]=[]
static func make_component(input: Dictionary) -> Node3D:
 assert(input.get("kind","") in ["freezing","delayed_fire"])
 var node: Node3D=VfxPackageIO_da9481c1d1.resource("res://assets/vfx/sources/da9481c1d1d2134a59ab/recipient_contact.gd").new();node.specification=input.duplicate(true);node.set_damage_event(input.get("event",{}));return node
func set_live_endpoints(value: Array) -> void:endpoints=value
func set_entity_geometry(value: Dictionary) -> void:geometry=value
func set_damage_event(value: Dictionary) -> bool:
 for draw in draws:draw.hide()
 event.clear()
 for key in ["source_owner_uuid","original_caster_uuid","recipient_uuid","kind"]:
  if str(value.get(key,""))!=str(specification.get(key,"")):return false
 if str(value.get("event_uuid",""))=="" or not bool(value.get("damage_applied",false)) or bool(value.get("suppressed",false)):return false
 event=value.duplicate(true);return true
func sample(seconds: float) -> void:
 if draws.is_empty():
  for i in 5:
   var material=Native.ice(i==0) if specification.kind=="freezing" else Native.fire()
   var mesh: Mesh=SphereMesh.new() if specification.kind=="freezing" else VfxPackageIO_da9481c1d1.resource(Native.FIRE).mesh
   materials.append(material);draws.append(Native.draw(self,"MeasuredActualPayloadContact"+str(i),mesh,material));draws[i].top_level=true
 for i in draws.size():draws[i].hide();Native.clock(materials[i],seconds,0.0)
 if event.is_empty() or endpoints.is_empty():return
 var anchor: Vector3=endpoints[0].point;var candidates: Array=[]
 for actual in geometry.get("points",[]):
  if actual.position.distance_to(anchor)<.4:candidates.append(actual)
 if candidates.is_empty():return
 var alpha=smoothstep(0.0,.035,seconds)*(1.0-smoothstep(.12,.42,seconds))
 for i in draws.size():
  var actual: Dictionary=candidates[(i*173+31)%candidates.size()];var normal: Vector3=actual.normal.normalized()
  var size=Vector3(.09,.17,.09) if specification.kind=="freezing" else Vector3(.16,.22,.16)
  draws[i].global_transform=Transform3D(Basis.looking_at(normal,Vector3.UP if absf(normal.y)<.98 else Vector3.RIGHT)*Basis.from_scale(size),actual.position+normal*(.012+seconds*.12));draws[i].visible=alpha>.001
  var weight=.55 if bool(event.get("saved",false)) else .7
  if specification.kind=="delayed_fire":Native.fire_clock(materials[i],seconds,alpha*weight,.22+seconds*.9)
  else:Native.clock(materials[i],seconds,alpha*weight)
func capture_observation() -> Dictionary:
 return {"typed_applied_packet":event,"measured_surface_point_count":geometry.get("points",[]).size(),"recipient_uuid":specification.recipient_uuid,"no_damage_or_save_solver":true,"optical_lights":0}

const VfxPackageIO_da9481c1d1 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
