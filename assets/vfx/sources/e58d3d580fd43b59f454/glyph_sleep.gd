extends Node3D
## Genuine shared Sleep symbol, owned by the independently admitted Glyph Sleep condition.
const Native=preload("res://assets/vfx/sources/be83e762baa1da26d392/native_sources.gd")
const Sleep=preload("res://assets/vfx/sources/fb31fcdb7959ad45d822/sleep_condition.gd")
var specification: Dictionary={}
var state: Dictionary={}
var endpoints: Array=[]
var symbol: Node3D
var halves: Array[Node3D]=[]
static func make_component(input: Dictionary) -> Node3D:
 assert(not str(input.get("condition_uuid","")).is_empty() and not str(input.get("recipient_uuid","")).is_empty())
 var node: Node3D=VfxPackageIO_e58d3d580f.resource("res://assets/vfx/sources/e58d3d580fd43b59f454/glyph_sleep.gd").new();node.specification=input.duplicate(true);node.set_condition_state(input.get("state",{}));return node
func set_condition_state(value: Dictionary) -> bool:
 state.clear()
 if str(value.get("condition_uuid",""))!=str(specification.condition_uuid) or str(value.get("recipient_uuid",""))!=str(specification.recipient_uuid):return false
 if str(value.get("condition_id",""))!="condition.spell.glyph_of_warding.sleep":return false
 state=value.duplicate(true);return true
func set_live_endpoints(value: Array) -> void:endpoints=value
func sample(seconds: float) -> void:
 if symbol==null:
  symbol=Node3D.new();symbol.name="ObservedGlyphSleepSource";add_child(symbol)
  # The accepted shared source is explicitly split into complementary native
  # front/back shader halves. It does not implement a third 'full' mode.
  for side in ["front","back"]:
   var half=Sleep.make_component({"scene":"res://assets/vfx/sources/0715951e8be28c10c13a/vfx_status_sleep.tscn","settings":{"kind":"sleep","animation":""},"side":side,"simulation_hz":144,"seed":7331,"socket_lift_units":.08});symbol.add_child(half);half.scale=Vector3.ONE*.55;halves.append(half)
 symbol.hide()
 if not Native.observed(state) or endpoints.is_empty():return
 var envelope=Native.fixture_envelope(specification,seconds)
 if envelope<=.001:return
 symbol.show()
 for half in halves:half.set_live_endpoints(endpoints);half.sample(seconds)
func capture_observation() -> Dictionary:
 return {"condition_uuid":specification.condition_uuid,"recipient_uuid":specification.recipient_uuid,"condition_id":"condition.spell.glyph_of_warding.sleep","shared_semantic_art":"existing Sleep Zzz","visible":symbol!=null and symbol.is_visible_in_tree(),"independent_of_glyph_spatial_retirement":true,"countdown_inferred":false,"optical_lights":0}

const VfxPackageIO_e58d3d580f = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
