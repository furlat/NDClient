extends Node3D
## A real created item presentation, not an enchantment discovered on an old sword.
const Fire=preload("res://assets/vfx/sources/cb6c8716b8516ba846d5/native_fire.gd")
const Measured=preload("res://assets/vfx/sources/2e511bee2be14a679d5d/measured_surface.gd")
var specification: Dictionary={}
var binding: Dictionary={}
var surface: Dictionary={}
var endpoints: Array=[]
var imprint: MeshInstance3D
var aura_material: ShaderMaterial
var tongues: Array[MeshInstance3D]=[]
var tongue_material: ShaderMaterial
var tongue_materials: Array[ShaderMaterial]=[]
var measurement: Dictionary={}
var rejection="unbound"
var envelope=0.0
static func make_component(input: Dictionary) -> Node3D:
 assert(not str(input.get("created_item_uuid","")).is_empty() and not str(input.get("lifetime_condition_uuid","")).is_empty())
 var effect: Node3D=VfxPackageIO_da8dee7afe.resource("res://assets/vfx/sources/da8dee7afedb3e5d3fac/flame_blade.gd").new()
 effect.specification=input.duplicate(true);effect.set_created_item_binding(input.get("binding",{}));return effect
func set_created_item_binding(value: Dictionary) -> bool:
 binding.clear();surface.clear();measurement.clear();_hide()
 rejection="created_item_identity"
 if str(value.get("item_uuid",""))!=str(specification.created_item_uuid) or str(value.get("item_id",""))!="weapon.flame_blade":return false
 if str(value.get("lifetime_condition_uuid",""))!=str(specification.lifetime_condition_uuid):return false
 if str(value.get("caster_uuid",""))!=str(specification.caster_uuid):return false
 binding=value.duplicate(true);rejection="";return true
func set_live_endpoints(value: Array) -> void:endpoints=value
func set_entity_geometry(value: Dictionary) -> void:surface=value
func prepare() -> void:
 aura_material=Fire.flame(.48,true);imprint=Fire.draw(self,"ActualCreatedItemMeasuredFire",ArrayMesh.new(),aura_material);imprint.top_level=true
 for i in 6:
  var material=Fire.flame(.38);tongue_materials.append(material)
  var draw=Fire.draw(self,"AttachedNativeBladeFlame"+str(i),VfxPackageIO_da8dee7afe.resource(Fire.CONE),material);draw.top_level=true;tongues.append(draw)
 tongue_material=tongue_materials[0]
func _admitted() -> bool:
 return Fire.observed(binding) and bool(binding.get("lifetime_present",false)) and bool(binding.get("item_in_caster_holdings",false)) and bool(binding.get("equipped",false)) and str(binding.get("holder_uuid",""))==str(specification.caster_uuid) and str(binding.get("render_slot","")) in ["weapon","offhand"]
func _hide() -> void:
 if imprint!=null:imprint.hide()
 for draw in tongues:draw.hide()
func sample(seconds: float) -> void:
 if imprint==null:prepare()
 _hide();measurement.clear();envelope=0.0
 Fire.clock(aura_material,seconds,0.0)
 for material in tongue_materials:Fire.clock(material,seconds,0.0)
 if not _admitted() or surface.is_empty() or endpoints.is_empty():return
 if str(surface.get("actor",""))!=str(binding.holder_uuid):rejection="surface_holder";return
 if surface.has("item_uuid"):
  if str(surface.item_uuid)!=str(binding.item_uuid):rejection="surface_item_uuid";return
 elif not bool(specification.get("disclosed_fixture_uuid_gap",false)):
  rejection="missing_surface_item_uuid";return
 measurement=Measured.build(surface,str(binding.render_slot),endpoints[0].point,.007)
 if int(measurement.cells)==0:rejection="missing_created_item_geometry";return
 rejection="";envelope=Fire.fixture_envelope(specification,seconds)
 imprint.mesh=measurement.mesh;imprint.global_transform=Transform3D(Basis.IDENTITY,surface.origin);imprint.visible=envelope>.001
 var axis: Vector3=(measurement.tip-measurement.base).normalized()
 if axis.is_zero_approx():return
 var normal_sum=Vector3.ZERO
 for point in surface.get("points",[]):
  if str(point.slot)==str(binding.render_slot):normal_sum+=point.normal
 var normal=normal_sum.normalized()
 if normal.is_zero_approx():normal=Vector3.UP
 for i in tongues.size():
  var position: Vector3=measurement.base.lerp(measurement.tip,.14+.135*float(i))
  var direction=(axis+normal*(.22 if i%2==0 else -.12)).normalized()
  var axes=Basis(Quaternion(Vector3.UP,direction))
  tongues[i].global_transform=Transform3D(axes*Basis.from_scale(Vector3(.019+.002*float(i%2),.031+.003*float(i%3),.019)),position)
  tongues[i].visible=envelope>.001
  Fire.clock(tongue_materials[i],seconds+float(i)*.16,envelope*.78)
 Fire.clock(aura_material,seconds,envelope*.98)
func capture_observation() -> Dictionary:
 return {"created_item_uuid":specification.created_item_uuid,"created_item_id":"weapon.flame_blade","lifetime_condition_uuid":specification.lifetime_condition_uuid,"owner_kind":"created_item","state":binding,"rejection":rejection,"measured_cells":measurement.get("cells",0),"visible":imprint!=null and imprint.visible,"envelope":envelope,"source_aura":Fire.TORCH,"source_fire":Fire.TORCH,"fixture_uuid_gap":not surface.has("item_uuid"),"automatic_created_item_visual_binding":false,"optical_lights":0,"creates_item_or_damage":false,"concentration":false}

const VfxPackageIO_da8dee7afe = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
