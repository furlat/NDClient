extends Resource
## Native meshes with reusable local transform recordings. No actor, encounter,
## camera or target coordinates are included in these source-local buffers.
@export var source: String = ""
@export var rate: float = 144.
@export var formation_seconds: float = 2.
@export var loop_seconds: float = 6.
@export var groups: Array = []
@export var trajectory: Image
