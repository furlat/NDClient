extends RefCounted
const Base=preload("res://assets/vfx/sources/ca69e9e47c9d66bb69fd/restore.gd")
const Profile=preload("res://assets/vfx/sources/5e6062cb1efe781a65b7/construction_profile.gd")

static func make(script_path: String,input: Dictionary) -> Node3D:
 var bank: Resource=VfxPackageIO_6d7cfd14f2.resource(input.prepared_recipient_bank)
 assert(bank.interface_ready)
 var node: Node3D
 if bank.plain_flow:
  node=bank.scene.instantiate()
  node.set_script(VfxPackageIO_6d7cfd14f2.resource(script_path))
  node.duration=float(input.get("seconds",4.5))
  node.set_meta("prepared_timed_subject",node)
 else:
  node=Base.make(script_path,input)
  node.set_meta("prepared_timed_subject",node.subject)
 var subject: Node3D=node.get_meta("prepared_timed_subject")
 var extras:=[]
 for material in bank.extra_materials:extras.append(material.duplicate(false))
 for name in bank.node_arrays:
  var array: Array=node.get(name)
  for path in bank.node_arrays[name]:array.append(subject.get_node(path))
 for name in bank.value_members:
  var value: Variant=bank.value_members[name]
  var current: Variant=node.get(name)
  if current is Array:current.assign(value)
  else:node.set(name,value)
 for name in bank.material_members:
  var description: Dictionary=bank.material_members[name]
  node.set(name,extras[int(description.extra)] if description.has("extra") else Base.material(subject,description.binding))
 for name in bank.material_arrays:
  var array: Array=node.get(name)
  array.clear()
  for description in bank.material_arrays[name]:
   array.append(extras[int(description.extra)] if description.has("extra") else Base.material(subject,description.binding))
 var materials:=[]
 for binding in bank.all_shader_bindings:materials.append(Base.material(subject,binding))
 node.set_meta("prepared_timed_materials",materials)
 node.set_meta("prepared_timed_geometry",bank.geometry_paths.map(func(path):return subject.get_node(path)))
 node.set_meta("prepared_timed_bank",bank)
 return node

static func start(node: Node3D) -> void:
 var bank: Resource=node.get_meta("prepared_timed_bank")
 var subject: Node3D=node.get_meta("prepared_timed_subject")
 for path in bank.restart_paths:subject.get_node(path).restart()

static func bindings(node: Node3D) -> Dictionary:
 return {"geometry":node.get_meta("prepared_timed_geometry"),"materials":node.get_meta("prepared_timed_materials"),
  "lights":[],"players":[],"static_material_topology":true,"static_geometry_layers":true}

const VfxPackageIO_6d7cfd14f2 = preload("res://assets/vfx/extensions/continuation42-20261020/scoped_resource_io.gd")
