extends "res://assets/vfx/conditions/measured.gd"
## Cached prepared original tongues follow the same measured item as the imprint.
## Only changed optical poses upload/route geometry; no per-frame mesh creation.
var tongues: Array = []
var identity: Dictionary = {}
var tongue_key: Array = []

func configure(visual: Node3D, specification: Dictionary, geometry: Array) -> void:
 super.configure(visual,specification,geometry)
 for entry in geometry:
  if str(entry.node.name).begins_with("AttachedNativeBladeFlame"):
   tongues.append(entry.node)
   entry.node.top_level=false
   entry.node.hide()
 assert(tongues.size()==6,"Flame Blade must retain all six original tongues")
 tongues.sort_custom(func(a: Node3D,b: Node3D) -> bool: return str(a.name)<str(b.name))

func set_created_item_identity(value: Dictionary) -> void:
 # Independent authoritative identity comes from the exact lifetime owner.
 if identity==value:return
 identity=value.duplicate(true)
 last_key=[]
 tongue_key=[]
 update(current_surface)

func set_created_item_binding(value: Dictionary) -> void:
 set_weapon_binding(value)

func _created_admitted() -> bool:
 return (not str(identity.get("created_item_uuid","")).is_empty()
  and not str(identity.get("lifetime_condition_uuid","")).is_empty()
  and not str(identity.get("caster_uuid","")).is_empty()
  and str(weapon_binding.get("item_uuid",""))==str(identity.get("created_item_uuid",""))
  and str(weapon_binding.get("item_id",""))=="weapon.flame_blade"
  and str(weapon_binding.get("lifetime_condition_uuid",""))==str(identity.get("lifetime_condition_uuid",""))
  and str(weapon_binding.get("caster_uuid",""))==str(identity.get("caster_uuid",""))
  and str(weapon_binding.get("holder_uuid",""))==str(identity.get("caster_uuid",""))
  and bool(weapon_binding.get("lifetime_present",false))
  and bool(weapon_binding.get("item_in_caster_holdings",false))
  and str(weapon_binding.get("render_slot","")) in ["weapon","offhand"])

func update(surface: Dictionary) -> void:
 current_surface=surface
 if not _created_admitted():
  admitted_geometry=false
  last_key=[]
  tongue_key=[]
  for entry in entries:entry.node.hide()
  for node in tongues:node.hide()
  return
 super.update(surface)
 if not admitted_geometry:
  tongue_key=[]
  for node in tongues:node.hide()
  return
 if not last_key.is_empty() and last_key==tongue_key:return
 var material: ShaderMaterial=entries[0].material
 var along: Vector2=material.get_shader_parameter("vfx_measured_along")
 var reverse: bool=material.get_shader_parameter("vfx_measured_reverse")
 var inverse: Transform3D=entries[0].visual.global_transform.affine_inverse()
 var low:=INF
 var high:=-INF
 var base:=Vector3.ZERO
 var tip:=Vector3.ZERO
 var normal:=Vector3.ZERO
 var chosen: Dictionary={}
 for point in surface.get("points",[]):
  if str(point.get("slot",""))==str(weapon_binding.render_slot) and point.get("pixel") is Vector2i:
   chosen[point.pixel]=point
 var directions: Array=[Vector2i.RIGHT,Vector2i.LEFT,Vector2i.UP,Vector2i.DOWN,Vector2i(1,1),Vector2i(-1,1),Vector2i(1,-1),Vector2i(-1,-1)]
 for pixel: Vector2i in chosen:
  var point: Dictionary=chosen[pixel]
  var connected:=false
  for direction: Vector2i in directions:
   if chosen.has(pixel+direction):
    var distance: float=point.position.distance_to(chosen[pixel+direction].position)
    if distance>=.00001 and distance<=.07:
     connected=true
     break
  if not connected:continue
  var projected: float=Vector2(pixel).dot(along)
  var position: Vector3=inverse*point.position
  normal+=(inverse.basis*point.normal).normalized()
  if projected<low:
   low=projected
   base=position
  if projected>high:
   high=projected
   tip=position
 if reverse:
  var swap:=base
  base=tip
  tip=swap
 var axis: Vector3=(tip-base).normalized()
 if axis.is_zero_approx():
  admitted_geometry=false
  for entry in entries:entry.node.hide()
  for node in tongues:node.hide()
  return
 normal=normal.normalized()
 if normal.is_zero_approx():normal=Vector3.UP
 for i in 6:
  var direction: Vector3=(axis+normal*(.22 if i%2==0 else -.12)).normalized()
  var axes:=Basis(Quaternion(Vector3.UP,direction))
  var world_local:=Transform3D(axes*Basis.from_scale(Vector3(.019+.002*float(i%2),.031+.003*float(i%3),.019)),base.lerp(tip,.14+.135*float(i)))
  # Source component paths can be nested: convert from prepared visual coordinates.
  tongues[i].transform=tongues[i].get_parent().global_transform.affine_inverse()*entries[0].visual.global_transform*world_local
  tongues[i].show()
 tongue_key=last_key.duplicate()
