extends Resource
## One actual rig/category, shared by every actor wearing this source.
## These are metadata strings/values; loading this never loads texture pixels.
@export var rig_id: String = ""
@export var category: String = ""
@export var clips: Dictionary = {}
@export var headers: Dictionary = {}
