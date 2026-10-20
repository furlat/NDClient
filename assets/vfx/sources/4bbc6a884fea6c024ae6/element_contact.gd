extends Node3D
## Brief contact from an explicitly supplied applied typed damage fact.
const Native=preload("res://assets/vfx/sources/be83e762baa1da26d392/native_sources.gd")
var specification: Dictionary={}
var event: Dictionary={}
var endpoints: Array=[]
var surface: Dictionary={}
var draw: MeshInstance3D
var material: ShaderMaterial
static func make_component(input: Dictionary) -> Node3D:
 assert(input.get("element","") in Native.ELEMENTS)
 var node: Node3D=VfxPackageIO_4bbc6a884f.resource("res://assets/vfx/sources/4bbc6a884fea6c024ae6/element_contact.gd").new();node.specification=input.duplicate(true);node.set_damage_event(input.get("event",{}));return node
func set_damage_event(value: Dictionary) -> bool:
 event.clear()
 if str(value.get("source_owner_uuid",""))!=str(specification.source_owner_uuid) or str(value.get("recipient_uuid",""))!=str(specification.recipient_uuid):return false
 if str(value.get("element",""))!=str(specification.element) or str(value.get("event_uuid",""))=="" or not bool(value.get("damage_applied",false)):return false
 event=value.duplicate(true);return true
func set_live_endpoints(value: Array) -> void:endpoints=value
func set_entity_geometry(value: Dictionary) -> void:surface=value
func sample(seconds: float) -> void:
 if draw==null:
  material=Native.element(str(specification.element));var mesh=SphereMesh.new();mesh.radial_segments=16;mesh.rings=8;draw=Native.draw(self,"OneMeasuredNativeElementContact",mesh,material);draw.top_level=true
 draw.hide();Native.clock(material,seconds,0.0)
 if event.is_empty() or endpoints.is_empty():return
 var alpha=smoothstep(0.0,.035,seconds)*(1.0-smoothstep(.1,.32,seconds))
 var anchor: Vector3=endpoints[0].point;var point=anchor;var distance=.26*.26
 for actual in surface.get("points",[]):
  var value: float=actual.position.distance_squared_to(anchor)
  if value<distance:distance=value;point=actual.position
 draw.global_transform=Transform3D(Basis.IDENTITY.scaled(Vector3(.23,.32,.23)),point)
 draw.visible=alpha>.001;Native.clock(material,seconds,alpha*(.45 if bool(event.get("saved",false)) else .7))
func capture_observation() -> Dictionary:
 return {"source_owner_uuid":specification.source_owner_uuid,"recipient_uuid":specification.recipient_uuid,"typed_applied_fact":event,"actual_surface_points":surface.get("points",[]).size(),"visible":draw!=null and draw.visible,"optical_lights":0,"invented_condition_or_damage":false}
func source_bindings() -> Dictionary:
 return {"geometry":[draw],"materials":[material],"static_material_topology":true}

const VfxPackageIO_4bbc6a884f = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
