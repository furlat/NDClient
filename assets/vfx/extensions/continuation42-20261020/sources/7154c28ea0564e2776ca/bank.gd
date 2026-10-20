extends "res://assets/vfx/extensions/continuation42-20261020/sources/0250a3f89c551f4fc017/bank.gd"
## Whole native leaf topology, including siblings outside its nested donor.
## No actual application/recipient/endpoint/pose is stored in immutable data.
const Restore=preload("res://assets/vfx/sources/ca69e9e47c9d66bb69fd/restore.gd")
const Profile=preload("res://assets/vfx/sources/5e6062cb1efe781a65b7/construction_profile.gd")
@export var geometry_paths: Array[NodePath]=[]
@export var shader_bindings: Array[Dictionary]=[]
@export var controller_fields: Dictionary={}
@export var players: Array[Dictionary]=[]
@export var restart_paths: Array[NodePath]=[]
@export var family:=""
@export var shared_image_sites: Array[Dictionary]=[]

func prepare_immutable_interface() -> void:
 if interface_ready:return
 if provenance.get("requires_shared_clock",false):preload("res://assets/vfx/sources/c0017ad639184b208deb/occurrence_clock.gd").ensure_pool()
 super.prepare_immutable_interface()

func decode(record: Dictionary,owner: Node3D,materials: Array) -> Variant:
 match String(record.kind):
  "node":return owner.get_node(record.path)
  "material":return materials[int(record.index)]
  "array":
   var values:=[]
   for value in record.values:values.append(decode(value,owner,materials))
   return values
  "literal":
   var value: Variant=record.value
   return value.duplicate(true) if value is Array or value is Dictionary else value
 assert(false,"Unknown prepared exact source operand")
 return null

func restore(input: Dictionary) -> Node3D:
 assert(interface_ready)
 Profile.begin("solar_contact_scene_instantiate")
 var node: Node3D=scene.instantiate()
 Profile.end("solar_contact_scene_instantiate")
 Profile.begin("solar_contact_controller_restore")
 node.set_script(adapter_script)
 var materials:=[]
 for binding in shader_bindings:materials.append(Restore.material(node,binding))
 for name in controller_fields:
  var value: Variant=decode(controller_fields[name],node,materials)
  var target: Variant=node.get(name)
  if target is Array and value is Array:target.assign(value)
  else:node.set(name,value)
 node.parameters=input.duplicate(true);node.settings=input.settings.duplicate(true);node.side=input.side
 if family=="circle":node.admitted=bool(input.application.damage_applied);node.visible=node.admitted
 node.prepared_bank=self
 node.prepared_geometry=geometry_paths.map(func(path):return node.get_node(path))
 node.prepared_materials=materials
 node.prepared_players=[]
 node.prepared_lights=light_paths.map(func(path):return node.get_node(path))
 for record in players:
  var player: AnimationPlayer=node.get_node(record.node)
  if not String(record.animation).is_empty():
   player.play(record.animation);player.seek(float(record.position),true)
   if record.paused:player.pause()
  node.prepared_players.append(player)
 Profile.end("solar_contact_controller_restore")
 return node
