extends Node3D
## One admitted blast. Runtime retirement and area resolution are external facts.
const Native=preload("res://assets/vfx/sources/a3ec7774922fb78f255c/native_materials.gd")
const Footprint=preload("res://assets/vfx/sources/4d63f507234a77da8092/observed_footprint.gd")
const FRAGMENT="res://assets/vfx/sources/a68e01e8841f23a48709/ice_fragment_native.tres"
var specification: Dictionary={}
var event: Dictionary={}
var consumed: Dictionary={}
var endpoints: Array=[]
var draws: Array[MeshInstance3D]=[]
var materials: Array[ShaderMaterial]=[]
var last_origin=Vector3.ZERO
var rejection="unbound"
static func make_component(input: Dictionary) -> Node3D:
 assert(input.get("kind","") in ["acid","freezing","delayed_fire"])
 assert(not str(input.get("source_owner_uuid","")).is_empty() and not str(input.get("original_caster_uuid","")).is_empty())
 var node: Node3D=VfxPackageIO_9e01bea27a.resource("res://assets/vfx/sources/9e01bea27ad66740b60c/blast.gd").new();node.specification=input.duplicate(true);node.set_blast_event(input.get("event",{}));return node
func set_live_endpoints(value: Array) -> void:endpoints=value
func set_blast_event(value: Dictionary) -> bool:
 for draw in draws:draw.hide()
 event.clear();rejection="identity"
 for key in ["kind","source_owner_uuid","original_caster_uuid"]:
  if str(value.get(key,""))!=str(specification.get(key,"")):return false
 var identity=str(value.get("event_uuid",""))
 if identity.is_empty() or consumed.has(identity):rejection="missing_or_replayed_event";return false
 if not bool(value.get("observed",false)) or not bool(value.get("blast_committed",false)):rejection="no_native_committed_blast";return false
 var immediate=specification.kind=="freezing" and bool(specification.get("immediate_launch",false))
 if immediate and not bool(value.get("immediate_launch",false)):rejection="launch_identity";return false
 if specification.kind!="acid" and not immediate:
  for key in ["item_uuid","lifetime_uuid"]:
   if str(value.get(key,""))!=str(specification.get(key,"")):rejection="exact_payload_owner";return false
  if not bool(value.get("item_retirement_committed",false)) or not bool(value.get("lifetime_removal_committed",false)):rejection="retirement_not_committed";return false
 if bool(value.get("ending_rejected",false)) or bool(value.get("administrative_close",false)):rejection="no_gameplay_ending";return false
 # Suppressed expiry really consumes the event. It cannot appear after recovery.
 consumed[identity]=true
 if bool(value.get("suppressed_at_origin",false)):rejection="suppressed_consumed_without_blast";return true
 if value.get("admitted_cells",[]).is_empty():rejection="native_resolved_cells_missing";return false
 event=value.duplicate(true);rejection=""
 if not draws.is_empty():
  for material in materials:Footprint.set_cells(material,event.admitted_cells)
 return true
func prepare() -> void:
 var sphere=SphereMesh.new();sphere.radial_segments=24;sphere.rings=14
 var cells: Array=event.get("admitted_cells",specification.get("admitted_cells",[]))
 if cells.is_empty():return
 var count=13 if specification.kind=="acid" else 16 if specification.kind=="freezing" else 11
 for i in count:
  var material: ShaderMaterial
  var mesh: Mesh=sphere
  if specification.kind=="acid":
   material=Native.acid()
   if i==0:
    mesh=Footprint.plane(cells)
    var code=material.shader.code.replace("shader_type spatial;","shader_type spatial;\nvarying vec2 payload_liquid_world;")
    code=Native.Source.finish_function(code,"vertex","\nvec4 liquid_world4=MODEL_MATRIX*vec4(VERTEX,1.0);payload_liquid_world=liquid_world4.xz;\n") if code.contains("void vertex()") else code+"\nvoid vertex(){vec4 liquid_world4=MODEL_MATRIX*vec4(VERTEX,1.0);payload_liquid_world=liquid_world4.xz;}\n"
    # A wall's upper/lower gradient masks cannot define a supplied floor.
    # Use the same native flowing noise/ramp, leaving membership to Footprint.
    code=Native.Source.finish_fragment(code,"""
    vec2 native_liquid_uv=payload_liquid_world*0.31+Speed_XY2*payload_seconds;
    float native_liquid_mask=texture(Base_noise2,native_liquid_uv).r;
    ALBEDO=texture(Gradient_Color_1D2,vec2(native_liquid_mask)).rgb*Color_Intensity2*0.24;
    ALPHA=payload_alpha*(0.06+0.40*smoothstep(0.20,0.80,native_liquid_mask));
    """)
    var shader=Shader.new();shader.code=code;Native.Source.replace_shader(material,shader)
  elif specification.kind=="freezing":
   var bundle=VfxPackageIO_9e01bea27a.resource(FRAGMENT);material=Native.finite(bundle.material,.32);mesh=bundle.mesh
  else:material=Native.fire_burst();mesh=Native.fire_source().mesh
  Footprint.bind(material,cells);materials.append(material);draws.append(Native.draw(self,"DistinctNativeBlastLayer"+str(i),mesh,material));draws[i].top_level=true
func sample(seconds: float) -> void:
 if draws.is_empty():prepare()
 for i in draws.size():draws[i].hide();Native.clock(materials[i],seconds,0.0)
 if event.is_empty() or endpoints.is_empty():return
 last_origin=endpoints[0].point
 var alpha=smoothstep(0.0,.045,seconds)*(1.0-smoothstep(.5,1.05,seconds))
 var expansion=1.0-exp(-maxf(seconds,0.0)*5.5)
 for i in draws.size():
  var offset=Vector3.ZERO;var scale=Vector3.ONE;var basis=Basis.IDENTITY;var weight=1.0
  var angle=float(i)*2.399963
  if specification.kind=="acid":
   if i==0:
    weight=.46
   else:
    var radial=.8+float(i%4)*.62
    offset=Vector3(cos(angle)*radial*expansion,.12+(.35+float(i%3)*.16)*sin(clampf(seconds/1.05,0.0,1.0)*PI),sin(angle)*radial*expansion)
    scale=Vector3(.18+float(i%3)*.05,.07,.3)*(1.0-.35*seconds);basis=Basis(Vector3.UP,angle);weight=.72
  elif specification.kind=="freezing":
   var radial=.5+float(i%4)*.7
   offset=Vector3(cos(angle)*radial*expansion,.14+(.3+float(i%3)*.22)*sin(clampf(seconds/1.05,0.0,1.0)*PI),sin(angle)*radial*expansion)
   scale=Vector3.ONE*(.1+float(i%4)*.035)*(1.0+.5*expansion);basis=Basis.from_euler(Vector3(float(i)*.41+seconds*.3,angle,float(i)*.71));weight=.75
  else:
   var radial=.6+float(i%4)*.9
   offset=Vector3(cos(angle)*radial*expansion,.24+float(i%3)*.27,sin(angle)*radial*expansion)
   scale=Vector3(.34,.5,.34)*(1.0+expansion*(.4+float(i%3)*.12));basis=Basis(Vector3.UP,angle);weight=.28
  draws[i].global_transform=Transform3D(basis*Basis.from_scale(scale),last_origin+offset);Footprint.move(materials[i],last_origin)
  draws[i].visible=alpha>.001
  if specification.kind=="delayed_fire":Native.fire_clock(materials[i],seconds,alpha*weight,clampf(.14+seconds*.70+float(i%4)*.12,0.0,.98))
  else:Native.clock(materials[i],seconds,alpha*weight)
func capture_observation() -> Dictionary:
 return {"kind":specification.kind,"admitted_blast":event,"consumed_event_uuids":consumed.keys(),"rejection":rejection,"current_payload_origin":last_origin,"native_resolved_cell_count":event.get("admitted_cells",[]).size(),"all_item_retirement_external":true,"computes_area_or_damage":false,"optical_lights":0}

const VfxPackageIO_9e01bea27a = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
