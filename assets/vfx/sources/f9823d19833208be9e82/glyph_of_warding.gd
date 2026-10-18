extends Node3D
## Neutral observed ward. Hidden payload, occupancy, trigger and membership are not guessed.
const Native=preload("res://assets/vfx/sources/be83e762baa1da26d392/native_sources.gd")
var specification: Dictionary={}
var state: Dictionary={}
var endpoints: Array=[]
var draw: MeshInstance3D
var material: ShaderMaterial
var active=false
static func make_component(input: Dictionary) -> Node3D:
 assert(not str(input.get("spatial_owner_uuid","")).is_empty() and not str(input.get("caster_owner_uuid","")).is_empty() and input.has("observed_radius_cells"))
 var node: Node3D=VfxPackageIO_f9823d1983.resource("res://assets/vfx/sources/f9823d19833208be9e82/glyph_of_warding.gd").new();node.specification=input.duplicate(true);node.set_glyph_state(input.get("state",{}));return node
func set_glyph_state(value: Dictionary) -> bool:
 state.clear()
 if str(value.get("spatial_owner_uuid",""))!=str(specification.spatial_owner_uuid) or str(value.get("caster_owner_uuid",""))!=str(specification.caster_owner_uuid):return false
 state=value.duplicate(true);return true
func set_live_endpoints(value: Array) -> void:endpoints=value
func sample(seconds: float) -> void:
 if draw==null:
  material=Native.rune();var plane=PlaneMesh.new();plane.size=Vector2(3,3);draw=Native.draw(self,"OneNeutralObservedNativeRune",plane,material);draw.top_level=true
 draw.hide();active=false;Native.clock(material,seconds,0.0)
 if not Native.observed(state) or not bool(state.get("armed",false)) or endpoints.is_empty():return
 var alpha=Native.fixture_envelope(specification,seconds)
 if specification.get("lifecycle_mode","")=="recorded_fixture":
  for interval in specification.get("suppression_windows",[]):
   if seconds>=float(interval[0]) and seconds<float(interval[1]):alpha=0.0
 var diameter=float(specification.observed_radius_cells)*2.0
 draw.global_transform=Transform3D(Basis.IDENTITY.scaled(Vector3(diameter/3.0,1,diameter/3.0)),endpoints[0].point+Vector3(0,.018,0))
 draw.visible=alpha>.001;Native.clock(material,seconds,alpha*.75);active=draw.visible
func capture_observation() -> Dictionary:
 return {"spatial_owner_uuid":specification.spatial_owner_uuid,"caster_owner_uuid":specification.caster_owner_uuid,"condition":"condition.spell.glyph_of_warding","spatial_effect":"spatial_effect.spell.glyph_of_warding","observed_radius_cells":specification.observed_radius_cells,"neutral_armed_appearance":true,"payload_inferred":false,"visible":active,"suppression_consumes_owner":false,"source_material":"res://assets/vfx/sources/15e998736200a1a620df/rune_native.tres","optical_lights":0,"solves_occupancy_or_trigger":false}

const VfxPackageIO_f9823d1983 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
