extends "res://assets/vfx/sources/a4fd0883f0b17d893a03/base.gd"
## Pinned source authoring only; shared stage owns clock/camera/export.
const SourceMaterials=preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
static func make_component(input: Dictionary) -> Node3D:
 return construct("res://assets/vfx/sources/8bc14eb2046d9d28c368/control_shell.gd", input)
func prepare_materials(_node: Node) -> void:pass
var mats:Array[ShaderMaterial]=[]
func apply_scene_edits(node:Node)->void:
 pass
 subject=node
 node.set_script(null)
 for child in node.find_children("*","GeometryInstance3D",true,false):child.layers=0
 for a in node.find_children("*","AnimationPlayer",true,false):a.stop();a.active=false
 if settings.kind=="silence":
  var source=VfxPackageIO_8bc14eb204.resource("res://assets/vfx/sources/2f8ce99af1c169bac635/control_half_sphere.res")
  for i in range(2):
   var shell=MeshInstance3D.new();shell.mesh=source;node.add_child(shell)
   shell.scale=Vector3.ONE*8.485281374
   if i==1:shell.rotation.y=PI
   var mat=ShaderMaterial.new();mat.shader=VfxPackageIO_8bc14eb204.resource("res://assets/vfx/sources/700d61e5cdfb5bb9f1fb/silence_shell.gdshader")
   mat.set_shader_parameter("authored_noise",VfxPackageIO_8bc14eb204.resource("res://assets/vfx/sources/c0a2515abc39856316d0/texture.res"));mat.set_shader_parameter("front",side=="front");shell.material_override=mat;mats.append(mat)
 else:
  # Three connected unequal sheets in one true world-space 15-foot cone.
  # Cone points along +X; cross section full width equals forward distance.
  for layer in range(3):
   var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
   var rows=24;var cols=16
   for iy in rows:
    for ix in cols:
     for corner in [Vector2i(0,0),Vector2i(1,0),Vector2i(1,1),Vector2i(0,0),Vector2i(1,1),Vector2i(0,1)]:
      var u=float(ix+corner.x)/cols;var v=float(iy+corner.y)/rows
      var x=v*6.36396103+0.265220*(1.0-v)
      var z=(u-.5)*v*6.36396103-0.265220*(1.0-v)
      var y=0.91985*(1.0-v)+0.15+sin(u*PI)*sin(v*PI)*float(layer)*0.35
      st.set_uv(Vector2(u,v));st.add_vertex(Vector3(x,y,z))
   st.generate_normals()
   var sheet=MeshInstance3D.new();sheet.mesh=st.commit();node.add_child(sheet)
   var mat=ShaderMaterial.new();mat.shader=VfxPackageIO_8bc14eb204.resource("res://assets/vfx/sources/3ded7f6a8a13323cc808/prism_fan.gdshader")
   mat.set_shader_parameter("front",side=="front");mat.set_shader_parameter("layer",float(layer));mat.set_shader_parameter("authored_noise",VfxPackageIO_8bc14eb204.resource("res://assets/vfx/sources/c0a2515abc39856316d0/texture.res"));sheet.material_override=mat;mats.append(mat)
func advance_lifecycle(_delta:float)->void:
 if not is_instance_valid(subject):return
 tick+=1
 var phase=float(tick%576)/576.0
 for mat in mats:mat.set_shader_parameter("clock",1.5+sin(phase*TAU)*0.3 if settings.kind=="silence" else float(tick)/float(parameters.simulation_hz))


const VfxPackageIO_8bc14eb204 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
