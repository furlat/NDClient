extends Node3D
## Finite hand preparation / optical transfer. Never the summoned entity itself.
const Fire=preload("res://assets/vfx/sources/cb6c8716b8516ba846d5/native_fire.gd")
var specification: Dictionary={}
var endpoints: Array=[]
var draw: MeshInstance3D
var material: ShaderMaterial
var launch_seconds=.3
var travel_seconds=.45
static func make_component(input: Dictionary) -> Node3D:
 var node: Node3D=VfxPackageIO_1d15e2fed7.resource("res://assets/vfx/sources/1d15e2fed78a98b768a3/conjure_seed.gd").new();node.specification=input.duplicate(true);return node
func set_live_endpoints(value: Array) -> void:endpoints=value
func set_delivery_timing(launch: float,travel: float) -> void:launch_seconds=maxf(launch,0.0);travel_seconds=maxf(travel,.001)
func sample(seconds: float) -> void:
 if draw==null:
  var source=Fire.selected("FireHead",.42);material=source.material;draw=Fire.draw(self,"HandToAdmittedGroundOpticalSeed",source.mesh,material)
 draw.hide();Fire.clock(material,seconds,0.0)
 if endpoints.size()<3:return
 if bool(specification.get("preparation_only",false)) and seconds>=launch_seconds+.12:return
 var preparing=seconds<launch_seconds
 if bool(specification.get("preparation_only",false)):preparing=true
 var u=clampf((seconds-launch_seconds)/travel_seconds,0.0,1.0)
 var alpha=smoothstep(0.0,maxf(launch_seconds,.001),seconds)*(1.0-smoothstep(launch_seconds+travel_seconds,launch_seconds+travel_seconds+.12,seconds))
 if alpha<=.001:return
 var inverse=global_transform.affine_inverse();var hand: Vector3=inverse*endpoints[0].point;var target: Vector3=inverse*endpoints[1].point;var source: Vector3=inverse*endpoints[2].point
 draw.position=hand if preparing else source.lerp(target,u)
 var direction=(target-source).normalized()
 if not direction.is_zero_approx():draw.basis=Basis(Quaternion(Vector3.BACK,direction)).scaled(Vector3(.065,.065,.09))
 draw.show();Fire.clock(material,seconds,alpha*.72)
func capture_observation() -> Dictionary:
 return {"optical_seed_only":true,"summoned_body_in_flight":false,"source_scene":Fire.BALL,"visible":draw!=null and draw.visible,"launch_seconds":launch_seconds,"travel_seconds":travel_seconds,"optical_lights":0}

const VfxPackageIO_1d15e2fed7 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
