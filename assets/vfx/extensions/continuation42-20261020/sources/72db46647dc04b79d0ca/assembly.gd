extends "res://assets/vfx/sources/0738ff2d24aa41b1b963/native_review_composition.gd"
## Original live inputs/timing; exact leaf declarations avoid repeat discovery.
var cached_bindings: Dictionary={}
static func preparation_resources(input: Dictionary) -> Array:return Composition.preparation_resources(input)
static func make_component(input: Dictionary) -> Node3D:
 var node: Node3D=VfxPackageIO_72db46647d.resource("res://assets/vfx/extensions/continuation42-20261020/sources/72db46647dc04b79d0ca/assembly.gd").new()
 node.definition=input.duplicate(true)
 return node
func prepare_source_interfaces() -> Array:
 cached_bindings=composition.source_bindings()
 assert(not cached_bindings.is_empty())
 return SourceSpace.adapt_materials(cached_bindings.materials)
func source_bindings() -> Dictionary:return cached_bindings
func has_verified_stable_paths() -> bool:
 if not prepared or composition==null:return false
 for component in composition.components.values():
  if not component.has_verified_stable_paths():return false
 return true
func refresh_live_inputs(age: float) -> void:sample(age)

const VfxPackageIO_72db46647d = preload("res://assets/vfx/extensions/continuation42-20261020/scoped_resource_io.gd")
