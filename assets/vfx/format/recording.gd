extends Resource
## Production data schema. No playback code or client presentation dependency.
@export var clip_id: String = ""
@export var version: int = 1
@export var clip_hash: String = ""
@export var rate: float = 60.0
@export var frames: int = 1
@export var seconds: float = 0.0
@export var scene: PackedScene
@export var systems: Array = []
@export var trails: Array = []
@export var moving: bool = false
@export var tracks: Array = []
@export var private_materials: Array = []
@export var gaps: Array = []
