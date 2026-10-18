extends Node3D
## Supplied stationary FireSurface patches, separate from the moving body owner.
const Fire=preload("res://assets/vfx/sources/cb6c8716b8516ba846d5/native_fire.gd")
const Surface=preload("res://assets/vfx/sources/5d2781cac4ec7582d670/chromatic_orb_surface.gd")
var specification: Dictionary={}
var patches: Array=[]
var layers: Array[Node3D]=[]
var flames: Array=[]
var materials: Array=[]
static func make_component(input: Dictionary) -> Node3D:
 var node: Node3D=VfxPackageIO_1aba5a2937.resource("res://assets/vfx/sources/1aba5a2937d9632fe87b/fire_trail.gd").new();node.specification=input.duplicate(true);node.set_patch_states(input.get("patches",[]));return node
func set_patch_states(value: Array) -> bool:
 for child in get_children():
  remove_child(child);child.queue_free()
 layers.clear();flames.clear();materials.clear();patches.clear()
 var supplied=value.duplicate(true)
 for patch in supplied:
  if patch.get("position",null) is Array and patch.position.size()==3:patch.position=Vector3(float(patch.position[0]),float(patch.position[1]),float(patch.position[2]))
 for patch in supplied:
  if str(patch.get("owner_uuid",""))=="" or str(patch.get("surface_kind",""))!="spatial_effect.material.fire" or not patch.get("position",null) is Vector3:return false
  if patch.get("cells",[]).is_empty():return false
 patches=supplied;return true
func prepare() -> void:
 for i in patches.size():
  var patch: Dictionary=patches[i]
  var layer=Surface.make_component({"source_material":specification.source_material,"perimeter_texture_parameter":"Base_noise2","native_parameters":{"enable_vertex_movement":false,"Color_Intensity2":.6},"opacity":.30,"emission_gain":.18,"observed_surface_kind":"spatial_effect.material.fire","surface_admitted":true,"admitted_cells":patch.cells,"birth_seconds":.2,"retire_at_seconds":float(patch.get("remove_seconds",1000000.0))})
  layer.name="SurfacePatch%d"%i
  add_child(layer);layers.append(layer);layer.set_live_endpoints([{"point":patch.position}])
  # Register the complete native plane/material before the first visible tick.
  # At age zero its existing birth envelope is transparent. Delaying this
  # until the patch's birth made the renderer/baker miss an entire surface.
  layer.sample(0.0)
  var draws=[];var patch_materials=[]
  for cell in patch.cells:
   for n in 3:
    var material=Fire.flame(.42);patch_materials.append(material)
    var draw=Fire.draw(self,"FirePatch%dFlame%d"%[i,draws.size()],VfxPackageIO_1aba5a2937.resource(Fire.CONE),material)
    draw.top_level=true
    var offset=Vector3(.10 if n==0 else (-.16 if n==1 else .18),.018,.08 if n==0 else (-.10 if n==1 else -.13))
    draw.global_position=patch.position+Vector3(float(cell[0]),0,float(cell[1]))+offset
    var height=.075 if n==0 else (.10 if n==1 else .062)
    var direction=Vector3(.13 if n==0 else -.12,1,.06).normalized()
    draw.basis=Basis(Quaternion(Vector3.UP,direction))*Basis.from_scale(Vector3(.039 if n==0 else .032,height,.035));draws.append(draw)
  flames.append(draws);materials.append(patch_materials)
func _supplied_join_edges(index: int,occupied: Dictionary) -> void:
 var values=PackedVector4Array();var patch: Dictionary=patches[index]
 for cell in patch.cells:
  var point=Vector2(patch.position.x+float(cell[0]),patch.position.z+float(cell[1]))
  values.append(Vector4(0.0 if occupied.has(point+Vector2.LEFT) else 1.0,0.0 if occupied.has(point+Vector2.RIGHT) else 1.0,0.0 if occupied.has(point+Vector2.UP) else 1.0,0.0 if occupied.has(point+Vector2.DOWN) else 1.0))
 while values.size()<32:values.append(Vector4.ZERO)
 layers[index].material.set_shader_parameter("observed_open_edges",values)
func sample(seconds: float) -> void:
 if layers.is_empty() and not patches.is_empty():prepare()
 # Adjacency of supplied stationary owners, never new area membership. Each
 # owner still renders only its own cells and can disappear independently.
 var occupied={}
 for patch in patches:
  var age=seconds-float(patch.get("birth_seconds",0.0))
  if Fire.observed(patch) and age>=0.0 and age<float(patch.get("remove_seconds",1000000.0))+.65:
   for cell in patch.cells:occupied[Vector2(patch.position.x+float(cell[0]),patch.position.z+float(cell[1]))]=true
 for i in layers.size():
  var patch: Dictionary=patches[i]
  var local=seconds-float(patch.get("birth_seconds",0.0))
  var active=Fire.observed(patch) and local>=0.0
  layers[i].visible=active
  if active:
   layers[i].sample(local);_supplied_join_edges(i,occupied)
   layers[i].material.set_shader_parameter("orb_burst_seconds",seconds)
  var alpha=smoothstep(0.0,.2,local)*(1.0-smoothstep(float(patch.get("remove_seconds",1000000.0)),float(patch.get("remove_seconds",1000000.0))+.3,local)) if active else 0.0
  for draw in flames[i]:draw.visible=alpha>.001
  for n in materials[i].size():Fire.clock(materials[i][n],seconds+float(i)*.23+float(n)*.173,alpha*.82)
  # Same source clock; stationary world patches retain independent alpha/owners.
func capture_observation() -> Dictionary:
 var result=[]
 for patch in patches:result.append({"owner_uuid":patch.owner_uuid,"surface_kind":patch.surface_kind,"position":patch.position,"cells":patch.cells,"present":Fire.observed(patch)})
 return {"stationary_patch_owners":result,"separate_from_summoned_body":true,"movement_creates_patches":false,"dousing_despawns_body":false,"source_material":Fire.TORCH,"optical_lights":0}

const VfxPackageIO_1aba5a2937 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
