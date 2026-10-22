extends Resource
## Thin actual rig/category selection, shared by actors and optional discovery.
## Heavy geometry/socket facts live in the selected clip Resources.
@export var rig_id: String = ""
@export var category: String = ""
@export var clips: Dictionary = {}
@export var headers: Dictionary = {}
@export var clip_sources: Dictionary = {}
@export var paths_by_slot: Dictionary = {}
## Native body slot -> clip -> display facing -> actual colour path.
@export var bank_paths_by_slot: Dictionary = {}
