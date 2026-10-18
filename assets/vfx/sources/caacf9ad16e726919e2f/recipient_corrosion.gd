extends Node3D
## Vitriolic residue and next-END applied packet stay separate factual owners.
const Native=preload("res://assets/vfx/sources/a3ec7774922fb78f255c/native_materials.gd")
var specification: Dictionary={}
var state: Dictionary={}
var endpoints: Array=[]
var geometry: Dictionary={}
var draws: Array[MeshInstance3D]=[]
var material: ShaderMaterial
var rejection="unbound"
static func make_component(input: Dictionary) -> Node3D:
 assert(input.get("phase","") in ["initial_contact","residue","delayed_tick"])
 var node: Node3D=VfxPackageIO_caacf9ad16.resource("res://assets/vfx/sources/caacf9ad16e726919e2f/recipient_corrosion.gd").new();node.specification=input.duplicate(true);node.set_native_state(input.get("state",{}));return node
func set_live_endpoints(value: Array) -> void:endpoints=value
func set_entity_geometry(value: Dictionary) -> void:geometry=value
func set_native_state(value: Dictionary) -> bool:
 for draw in draws:draw.hide()
 state.clear();rejection="identity"
 for key in ["source_owner_uuid","recipient_uuid","original_caster_uuid"]:
  if str(value.get(key,""))!=str(specification.get(key,"")):return false
 if specification.phase=="residue":
  if str(value.get("condition_uuid",""))!=str(specification.get("condition_uuid","")) or str(value.get("condition_id",""))!="condition.spell.vitriolic_sphere.residue":return false
 else:
  if str(value.get("event_uuid",""))=="" or not bool(value.get("damage_applied",false)):rejection="no_applied_damage_fact";return false
  if specification.phase=="delayed_tick" and (str(value.get("condition_uuid",""))!=str(specification.get("condition_uuid","")) or str(value.get("reason",""))!="recipient_end_residue_packet"):return false
 state=value.duplicate(true);rejection="";return true
func sample(seconds: float) -> void:
 if material==null:
  material=Native.acid();var sphere=SphereMesh.new();sphere.radial_segments=12;sphere.rings=6
  for i in 10:draws.append(Native.draw(self,"ActualRecipientCorrosion"+str(i),sphere,material));draws[i].top_level=true
 for draw in draws:draw.hide()
 Native.clock(material,seconds,0.0)
 if state.is_empty() or geometry.get("points",[]).is_empty() or endpoints.is_empty():return
 if specification.phase=="residue" and not Native.observed(state):return
 if bool(state.get("suppressed",false)):return
 var ticking=specification.phase=="delayed_tick";var contact=specification.phase=="initial_contact"
 var alpha=Native.envelope(specification,seconds) if not ticking and not contact else smoothstep(0.0,.035,seconds)*(1.0-smoothstep(.13,.48,seconds))
 var points: Array=geometry.points;var anchor: Vector3=endpoints[0].point;var candidates: Array=[]
 for point in points:
  if point.position.distance_to(anchor)<.46:candidates.append(point)
 if candidates.is_empty():return
 for i in draws.size():
  var actual: Dictionary=candidates[(i*173+31)%candidates.size()];var normal: Vector3=actual.normal.normalized()
  var point: Vector3=actual.position+normal*.014
  if ticking:point+=normal*seconds*.3-Vector3.UP*seconds*seconds*.12
  var size=Vector3(.055,.08 if ticking else .035,.035)*(1.0+float(i%3)*.16)
  draws[i].global_transform=Transform3D(Basis.looking_at(normal,Vector3.UP if absf(normal.y)<.98 else Vector3.RIGHT)*Basis.from_scale(size),point);draws[i].visible=alpha>.001
 Native.clock(material,seconds,alpha*(.8 if ticking else .53))
func capture_observation() -> Dictionary:
 return {"phase":specification.phase,"typed_state_or_applied_packet":state,"actual_recipient_points":geometry.get("points",[]).size(),"rejection":rejection,"fixed_five_d4_computed":false,"recipient_end_or_condition_duration_counted":false,"poisoned_invented":false,"optical_lights":0}

const VfxPackageIO_caacf9ad16 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
