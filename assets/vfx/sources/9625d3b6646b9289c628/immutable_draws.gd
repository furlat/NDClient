extends Resource
## Source-owned immutable GPU templates, never an occurrence or encounter pose.
@export var constructor := ""
@export var input_sha256 := ""
@export var meshes: Array[Mesh] = []
@export var materials: Array[ShaderMaterial] = []
@export var material_indices: Array[int] = []
@export var bounds: Array[AABB] = []
@export var instance_uniforms: Array[Dictionary] = []
@export var transforms: Array[Transform3D] = []
@export var sorting_offsets: Array[float] = []
@export var groups: Dictionary = {}
@export var constants: Dictionary = {}
