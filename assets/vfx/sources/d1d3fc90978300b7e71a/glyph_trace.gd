extends Node3D
## Small native rune trace from the current hand to an explicitly observed origin.
const Native=preload("res://assets/vfx/sources/be83e762baa1da26d392/native_sources.gd")
var specification: Dictionary={}
var endpoints: Array=[]
var draw: MeshInstance3D
var material: ShaderMaterial
var launch_seconds=.3
var travel_seconds=.45
static func make_component(input: Dictionary) -> Node3D:
 var node: Node3D=VfxPackageIO_d1d3fc9097.resource("res://assets/vfx/sources/d1d3fc90978300b7e71a/glyph_trace.gd").new();node.specification=input.duplicate(true);return node
func set_live_endpoints(value: Array) -> void:endpoints=value
func set_delivery_timing(launch: float,travel: float) -> void:launch_seconds=maxf(launch,0.0);travel_seconds=maxf(travel,.001)
func sample(seconds: float) -> void:
 if draw==null:
  material=Native.rune();var plane=PlaneMesh.new();plane.size=Vector2(.18,.18);draw=Native.draw(self,"NativeRunePreparationTrace",plane,material);draw.top_level=true
 draw.hide();Native.clock(material,seconds,0.0)
 if endpoints.size()<3:return
 var u=clampf((seconds-launch_seconds)/travel_seconds,0.0,1.0)
 var alpha=smoothstep(0.0,.16,seconds)*(1.0-smoothstep(launch_seconds+travel_seconds,launch_seconds+travel_seconds+.15,seconds))
 draw.global_position=endpoints[0].point if seconds<launch_seconds else (endpoints[2].point as Vector3).lerp(endpoints[1].point,u)
 draw.visible=alpha>.001;Native.clock(material,seconds,alpha)
func capture_observation() -> Dictionary:
 return {"source":"native Elementary circle1 rune mask only","current_hand_preparation":true,"observed_ground_destination_required":true,"visible":draw!=null and draw.visible,"optical_lights":0}

const VfxPackageIO_d1d3fc9097 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
