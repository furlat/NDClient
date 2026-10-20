extends Resource
## Offline immutable source program/templates. No actor, owner, event or clock.
@export var source_constructor := ""
@export var source_input_sha256 := ""
@export var family := 0
@export var active_piece_count := 0
@export var material: ShaderMaterial
@export var meshes: Array[Mesh] = []
@export var bounds: Array[AABB] = []
