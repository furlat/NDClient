extends Node3D
## One explicitly observed native owner light. Range is gameplay supplied;
## optical energy is an authored rendering parameter, not a rules calculation.
const Fire=preload("res://assets/vfx/sources/cb6c8716b8516ba846d5/native_fire.gd")
var specification: Dictionary={}
var state: Dictionary={}
var endpoints: Array=[]
var light: OmniLight3D
static func make_component(input: Dictionary) -> Node3D:
 assert(not str(input.get("owner_uuid","")).is_empty() and input.has("bright_cells") and input.has("dim_extension_cells") and input.has("optical_energy"))
 var node: Node3D=VfxPackageIO_f455fe3246.resource("res://assets/vfx/sources/f455fe3246a4497f52dc/owned_light.gd").new();node.specification=input.duplicate(true);node.set_owner_state(input.get("state",{}));return node
func set_owner_state(value: Dictionary) -> bool:
 state.clear()
 if str(value.get("owner_uuid",""))!=str(specification.owner_uuid):return false
 state=value.duplicate(true);return true
func set_live_endpoints(value: Array) -> void:endpoints=value
func sample(seconds: float) -> void:
 if light==null:
  light=OmniLight3D.new();light.name="ExplicitNativeOwnedFireLight";light.set_meta("factory_light_role","optical");light.light_color=Color(1,.55,.2);light.omni_range=float(specification.bright_cells)+float(specification.dim_extension_cells);add_child(light)
 light.light_energy=0.0
 if not Fire.observed(state) or endpoints.is_empty():return
 light.global_position=endpoints[0].point+Vector3(0,float(specification.get("height_cells",.65)),0)
 light.light_energy=float(specification.optical_energy)*Fire.fixture_envelope(specification,seconds)
func capture_observation() -> Dictionary:
 return {"owner_uuid":specification.owner_uuid,"owner_kind":specification.owner_kind,"bright_cells":specification.bright_cells,"dim_extension_cells":specification.dim_extension_cells,"explicit_observed_owner":Fire.observed(state),"optical_owners":1,"energy":0.0 if light==null else light.light_energy,"created_item_equipment_independent":specification.owner_kind=="FlameBladeLifetime","rule_solver":false}

const VfxPackageIO_f455fe3246 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
