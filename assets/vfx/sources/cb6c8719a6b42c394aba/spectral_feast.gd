@tool
extends Node3D
## Approved Blender geometry + preserved material. Capture and cameras stay shared.
var subject: Node3D
var motes: Array[MeshInstance3D]=[]
var flames: Array[Dictionary]=[]
var material_shader: String
var material_parameters: Dictionary={}

static func make_component(input: Dictionary) -> Node3D:
 var component=VfxPackageIO_cb6c8719a6.resource("res://assets/vfx/sources/cb6c8719a6b42c394aba/spectral_feast.gd").new()
 component.material_shader=str(input.get("material_shader","res://assets/vfx/sources/74ea69b6f35e3650235f/feast_spectral.gdshader"))
 component.material_parameters=input.get("material_parameters",{}).duplicate(true)
 var doc:=VfxPackageDocument_cb6c8719a6.new();var state:=GLTFState.new()
 if doc.append_from_file(str(input.get("geometry","")),state)!=OK:component.free();return null
 component.subject=doc.generate_scene(state)
 component.add_child(component.subject)
 component.subject.scale=Vector3(.28,.81649658*.9,.50)
 component.apply_materials(component.subject)
 for i in 18:
  var mesh:=SphereMesh.new();mesh.radius=.009 if i%3 else .014;mesh.height=mesh.radius*2.;mesh.radial_segments=6;mesh.rings=3
  var mote:=MeshInstance3D.new();mote.mesh=mesh;mote.material_override=component.make_material("Flame")
  component.subject.add_child(mote);component.motes.append(mote)
 return component

func make_material(kind: String) -> ShaderMaterial:
 var shader: Shader=VfxPackageIO_cb6c8719a6.resource(material_shader).duplicate(false)
 if not kind.begins_with("Spectral"):
  shader.code=shader.code.replace("ALPHA=mix(.64+rim*.25+flow*.08,.15+rim*.48+flow*.14,ghost);", "")
 var material:=ShaderMaterial.new();material.shader=shader
 material.set_shader_parameter("ghost",1. if kind.begins_with("Spectral") else 0.)
 material.set_shader_parameter("lightness",1. if kind.begins_with("Flame") else (.26 if kind=="Silver" else 0.))
 for key in material_parameters.get(kind,{}):material.set_shader_parameter(key,material_parameters[kind][key])
 return material

func apply_materials(node: Node) -> void:
 if node is MeshInstance3D:
  if "Flame" in node.name:flames.append({"node":node,"base_scale":node.scale})
  for surface in node.mesh.get_surface_count():
   var previous: Material=node.mesh.surface_get_material(surface)
   if previous:node.set_surface_override_material(surface,make_material(previous.resource_name))
 for child in node.get_children():apply_materials(child)

func sample(phase: float) -> void:
 for i in motes.size():
  var angle: float=TAU*(float(i)/18.+.012*sin(TAU*phase))
  var rise: float=fmod(phase+float(i)/18.,1.)
  motes[i].position=Vector3(1.55*cos(angle),1.2+.34*sin(PI*rise),.76*sin(angle))
  motes[i].scale=Vector3.ONE*sin(PI*rise)
 for i in flames.size():flames[i].node.scale=flames[i].base_scale*Vector3(1.,1.+.08*sin(TAU*phase*3.+i),1.)

const VfxPackageIO_cb6c8719a6 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")

const VfxPackageDocument_cb6c8719a6 = preload("res://assets/vfx/sources/55f3fdb093ba9d7c2784/scene_document.gd")
