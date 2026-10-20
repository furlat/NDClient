extends Node3D
## Autonomous native body presentation. Supplied origin moves; no AI or Ram rule.
const Fire=preload("res://assets/vfx/extensions/continuation42-20261020/sources/cb6c8716b8516ba846d5/native_fire.gd")
var specification: Dictionary={}
var state: Dictionary={}
var endpoints: Array=[]
var heads: Array[MeshInstance3D]=[]
var materials: Array[ShaderMaterial]=[]
var core: MeshInstance3D
var fire_material: ShaderMaterial
var core_material: ShaderMaterial
var center=Vector3.ZERO
var envelope=0.0
static func make_component(input: Dictionary) -> Node3D:
 assert(not str(input.get("entity_uuid","")).is_empty() and not str(input.get("existence_condition_uuid","")).is_empty())
 var node: Node3D=VfxPackageIO_0393b1bb8b.resource("res://assets/vfx/extensions/continuation42-20261020/sources/0393b1bb8b406965db34/flaming_sphere.gd").new();node.specification=input.duplicate(true);node.set_body_state(input.get("state",{}));return node
func set_body_state(value: Dictionary) -> bool:
 state.clear()
 if str(value.get("entity_uuid",""))!=str(specification.entity_uuid) or str(value.get("existence_condition_uuid",""))!=str(specification.existence_condition_uuid):return false
 state=value.duplicate(true);return true
func set_live_endpoints(value: Array) -> void:endpoints=value
func prepare() -> void:
 for i in 8:
  var material=Fire.flame(.32,false,true);materials.append(material)
  heads.append(Fire.draw(self,"NativeMovingFlame"+str(i),VfxPackageIO_0393b1bb8b.resource(Fire.CONE),material))
 fire_material=materials[0]
 core_material=Fire.flame(.26,false,true)
 var mesh=SphereMesh.new();mesh.radial_segments=32;mesh.rings=20
 core=Fire.draw(self,"NativeFireFlowBody",mesh,core_material)
func sample(seconds: float) -> void:
 if core==null:prepare()
 for i in heads.size():heads[i].hide();Fire.clock(materials[i],seconds,0.0)
 core.hide();envelope=0.0;Fire.clock(core_material,seconds,0.0)
 if not Fire.observed(state) or not bool(state.get("existence_present",false)) or endpoints.is_empty():return
 envelope=Fire.fixture_envelope(specification,seconds)
 center=global_transform.affine_inverse()*endpoints[0].point+Vector3(0,.44,0)
 for i in heads.size():
  var angle=TAU*float(i%5)/5.0
  var radial=Vector3(cos(angle),0,sin(angle))
  var upper=i>=5
  var base=center+radial*(.09 if upper else .19)+Vector3(0,.055 if upper else -.12,0)
  var direction=(Vector3.UP+radial*(.08 if upper else .18)).normalized()
  var length_scale=.058+float(i%3)*.006
  var width_scale=.045+float((i+1)%3)*.006
  heads[i].position=base
  heads[i].basis=Basis(Quaternion(Vector3.UP,direction))*Basis.from_scale(Vector3(width_scale,length_scale,width_scale*.88))
  heads[i].visible=envelope>.001
  Fire.clock(materials[i],seconds+float(i)*.137,envelope*.70)
 core.position=center;core.scale=Vector3.ONE*.72;core.visible=envelope>.001
 Fire.clock(core_material,seconds,envelope*.72)
func capture_observation() -> Dictionary:
 return {"entity_uuid":specification.entity_uuid,"existence_condition_uuid":specification.existence_condition_uuid,"native_body":"creature.spell.flaming_sphere","manifestation":"spell_construct","source_material":Fire.TORCH,"source_mesh":Fire.CONE,"native_flame_layers":heads.size(),"center":center,"visible":core!=null and core.visible,"envelope":envelope,"separate_aura_owner":true,"trail_created_from_movement":false,"native_ai_or_actions_implemented":false,"optical_lights":0}

const VfxPackageIO_0393b1bb8b = preload("res://assets/vfx/extensions/continuation42-20261020/scoped_resource_io.gd")
