extends Resource
## Offline native Wind Wall materials/meshes, never current path or owner state.
@export var grid: ArrayMesh
@export var debris_mesh: Mesh
@export var hit_mesh: Mesh
@export var flow_materials: Array[ShaderMaterial] = []
@export var hit_materials: Array[ShaderMaterial] = []
@export var feed_material: StandardMaterial3D
@export var source_parameters: Dictionary = {}
@export var source_phase := ""
@export var source_hashes: Dictionary = {}
