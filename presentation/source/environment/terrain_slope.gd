class_name PresentationTerrainSlope
extends Resource
## A progressive height change on a tile (server surface_kind stairs or ramp):
## its art per camera view and where each step's contact lies in that art.
@export_enum("stairs", "ramp") var kind: String = "stairs"
## Server slope_axis it serves (north_south, east_west); empty: either.
@export var slope_axis: String = ""
@export var art: String = ""
@export var rise_steps: int = 0
## Per view: the contact pixel of each step, lowest first.
@export var contacts: Dictionary[String, PackedVector2Array] = {}
## Per step: the grid offset (x, height, y) of the support it rests on.
@export var support_offsets: Array[Vector3i] = []
@export_enum("ready", "partial", "stand_in", "missing", "internal") var status: String = "missing"
@export_multiline var notes: String = ""
