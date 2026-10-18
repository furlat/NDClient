extends Node3D
## Once-consumed supplied payload event; rest/recast/suppression never detonates.
const Native=preload("res://assets/vfx/sources/be83e762baa1da26d392/native_sources.gd")
const Source=preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
var specification: Dictionary={}
var event: Dictionary={}
var endpoints: Array=[]
var rune: MeshInstance3D
var wave: MeshInstance3D
var rune_material: ShaderMaterial
var element_material: ShaderMaterial
var consumed_event_uuid=""
var active=false
static func make_component(input: Dictionary) -> Node3D:
 assert(not str(input.get("spatial_owner_uuid","")).is_empty())
 var node: Node3D=VfxPackageIO_3388e7d838.resource("res://assets/vfx/sources/3388e7d838f178594366/glyph_payload.gd").new();node.specification=input.duplicate(true);node.set_trigger_event(input.get("event",{}));return node
func set_trigger_event(value: Dictionary) -> bool:
 if not consumed_event_uuid.is_empty():return false
 event.clear()
 if str(value.get("spatial_owner_uuid",""))!=str(specification.spatial_owner_uuid) or str(value.get("event_uuid",""))=="":return false
 if str(value.get("reason",""))!="native_hostile_trigger" or not bool(value.get("triggered",false)):return false
 if str(value.get("payload","")) not in ["acid","cold","fire","lightning","thunder","sleep","detonation"]:return false
 event=value.duplicate(true);consumed_event_uuid=str(value.event_uuid);return true
func set_live_endpoints(value: Array) -> void:endpoints=value
func prepare() -> void:
 rune_material=Native.rune();var plane=PlaneMesh.new();plane.size=Vector2(3,3);rune=Native.draw(self,"NativeWardTriggerDissolve",plane,rune_material);rune.top_level=true
 if not event.is_empty() and Native.ELEMENTS.has(event.payload):
  element_material=Native.element(str(event.payload))
  var code=element_material.shader.code.replace("uniform float ward_alpha=0.0;","uniform float ward_alpha=0.0;\nvarying vec3 actual_payload_position;\nuniform vec3 payload_origin=vec3(0.0);\nuniform float payload_radius=2.6;")
  var record="\nvec4 actual_payload_world=MODEL_MATRIX*vec4(VERTEX,1.0);actual_payload_position=actual_payload_world.xyz;\n"
  if code.contains("void vertex()"):code=Source.finish_function(code,"vertex",record)
  else:code+="\nvoid vertex(){"+record+"}\n"
  code=Source.finish_fragment(code,"\nALPHA*=smoothstep(0.0,0.055,actual_payload_position.y-payload_origin.y)*(1.0-smoothstep(payload_radius-0.12,payload_radius,length(actual_payload_position.xz-payload_origin.xz)));\n")
  var shader=Shader.new();shader.code=code;Source.replace_shader(element_material,shader)
  var mesh=SphereMesh.new();mesh.radial_segments=24;mesh.rings=15;wave=Native.draw(self,"BriefNativeElementalGroundResponse",mesh,element_material);wave.top_level=true
func sample(seconds: float) -> void:
 if rune==null:prepare()
 rune.hide()
 if wave!=null:wave.hide();Native.clock(element_material,seconds,0.0)
 active=false;Native.clock(rune_material,seconds,0.0)
 if event.is_empty() or endpoints.is_empty():return
 var alpha=smoothstep(0.0,.055,seconds)*(1.0-smoothstep(.13,.6,seconds))
 var radius=float(specification.observed_radius_cells)
 rune.global_transform=Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*(radius*2.0/3.0)*(1.0-minf(seconds,.6)*.15)),endpoints[0].point+Vector3(0,.025,0));rune.visible=alpha>.001
 Native.clock(rune_material,seconds,alpha*.7)
 if wave!=null:
  var width=radius*2.0*(.4+clampf(seconds/.22,0.0,1.0)*.6)
  wave.global_transform=Transform3D(Basis.IDENTITY.scaled(Vector3(width,.65,width)),endpoints[0].point+Vector3(0,.02,0));wave.visible=alpha>.001
  element_material.set_shader_parameter("payload_origin",endpoints[0].point);element_material.set_shader_parameter("payload_radius",radius)
  Native.clock(element_material,seconds,alpha*.38)
 active=alpha>.001
func capture_observation() -> Dictionary:
 return {"spatial_owner_uuid":specification.spatial_owner_uuid,"one_event_uuid":consumed_event_uuid,"event":event,"visible":active,"payload_inferred_from_damage":false,"rest_recast_or_suppression_detonates":false,"sleep_condition_or_forced_movement_solved":false,"optical_lights":0}

const VfxPackageIO_3388e7d838 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
