extends "res://assets/vfx/extensions/owner-fields-v2-20261021/sources/f95a9864b1f165d83f44/timed_assembly.gd"
## Original timelines/placement/orbits stay live. Private leaves are disjoint.
var cached_bindings: Dictionary={}
static func preparation_resources(input: Dictionary) -> Array:
 return Composition.preparation_resources({"components":input.entries.map(func(entry):return entry.composition.components[0])})
static func make_component(input: Dictionary) -> Node3D:
 var node: Node3D=VfxPackageIO_aa6d31e0db.resource("res://assets/vfx/extensions/owner-fields-v2-20261021/sources/aa6d31e0db538a4bab5e/assembly.gd").new()
 node.selections=input.entries.duplicate(true)
 node.opacity_control=input.get("opacity_control",false)
 return node
func _prepare() -> void:
 super._prepare()
 cached_bindings={"geometry":[],"materials":[],"lights":[],"players":[],"static_material_topology":true,"static_geometry_layers":true}
 for entry in entries:
  var declared: Dictionary=entry.composition.source_bindings()
  assert(not declared.is_empty())
  for field in ["geometry","materials","lights","players"]:cached_bindings[field].append_array(declared.get(field,[]))
func source_bindings() -> Dictionary:return cached_bindings
func has_verified_stable_paths() -> bool:
 if not prepared or entries.size()!=selections.size():return false
 for entry in entries:
  for component in entry.composition.components.values():
   if not component.get_meta("prepared_timed_bank").stable_paths_prepared:return false
 return true
func refresh_live_inputs(seconds: float) -> void:sample(seconds)

const VfxPackageIO_aa6d31e0db = preload("res://assets/vfx/extensions/owner-fields-v2-20261021/scoped_resource_io.gd")
