extends Node3D
## One explicit applied fire component on a measured recipient. No save/damage roll.
const Fire=preload("res://assets/vfx/sources/cb6c8716b8516ba846d5/native_fire.gd")
var specification: Dictionary={}
var endpoints: Array=[]
var surface: Dictionary={}
var draws: Array[MeshInstance3D]=[]
var material: ShaderMaterial
var event: Dictionary={}
var active=false
static func make_component(input: Dictionary) -> Node3D:
 var node: Node3D=VfxPackageIO_40a136ae47.resource("res://assets/vfx/sources/40a136ae47ae570e43c9/fire_contact.gd").new();node.specification=input.duplicate(true);node.set_contact_event(input.get("event",{}));return node
func set_contact_event(value: Dictionary) -> bool:
 event.clear()
 if str(value.get("owner_uuid",""))!=str(specification.owner_uuid) or str(value.get("source_uuid",""))!=str(specification.source_uuid):return false
 if str(value.get("damage_component_uuid",""))=="" or not bool(value.get("applied",false)):return false
 if not str(value.get("trigger","")) in ["created_item_spell_attack","sphere_ram","enemy_turn_end","breakable_object_sphere_turn_end"]:return false
 if str(value.get("outcome","")) not in ["hit","critical","saved_half","failed_save"]:return false
 if str(value.trigger)=="created_item_spell_attack" and str(value.get("attack_kind",""))!="spell":return false
 event=value.duplicate(true);return true
func set_entity_geometry(value: Dictionary) -> void:surface=value
func set_live_endpoints(value: Array) -> void:endpoints=value
func sample(seconds: float) -> void:
 if draws.is_empty():
  material=Fire.flame(.4)
  for i in 2:draws.append(Fire.draw(self,"MeasuredAppliedFireContact"+str(i),VfxPackageIO_40a136ae47.resource(Fire.CONE),material))
 for draw in draws:draw.hide()
 active=false;Fire.clock(material,seconds,0.0)
 if event.is_empty() or endpoints.is_empty():return
 var alpha=smoothstep(0.0,.035,seconds)*(1.0-smoothstep(.1,.38,seconds))
 if alpha<=.001:return
 var inverse=global_transform.affine_inverse();var recipient: Vector3=inverse*endpoints[0].point
 var candidates: Array=surface.get("points",[])
 recipient+=Vector3(0,float(specification.get("anchor_height_cells",0.0)),0)
 var contact=recipient
 var closest=.28*.28
 for point in candidates:
  var actual: Vector3=inverse*point.position
  var distance=actual.distance_squared_to(recipient)
  if distance<closest:contact=actual;closest=distance
 for i in draws.size():
  draws[i].position=contact+Vector3(float(i)*.018,float(i)*.012,0)
  draws[i].basis=Basis.from_scale(Vector3(.023,.045+float(i)*.008,.025));draws[i].show()
 Fire.clock(material,seconds,alpha*(.58 if event.outcome=="saved_half" else .8));active=true
func capture_observation() -> Dictionary:
 return {"applied_component":event,"owner_uuid":specification.owner_uuid,"source_uuid":specification.source_uuid,"visible_contact":active,"recipient_surface_points":surface.get("points",[]).size(),"source_material":Fire.TORCH,"optical_lights":0,"calculates_save_damage_or_condition":false}

const VfxPackageIO_40a136ae47 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
