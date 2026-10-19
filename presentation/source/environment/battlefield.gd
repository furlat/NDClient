class_name PresentationBattlefield
extends Resource
## Optional per-battlefield presentation: ambient light, background and music.
@export var id: String = ""
@export var title: String = ""
@export var ambient: Color = Color(0, 0, 0, 0)
@export var background: String = ""
@export var music: String = ""
@export_enum("ready", "partial", "stand_in", "missing", "internal") var status: String = "missing"
@export_multiline var notes: String = ""
