class_name PresentationBodyClip
extends Resource
## Registration of an adopted source clip. Paths stay passive until media demand.
@export var rig_id: String = ""
@export var clip: String = ""
@export var source_clip: String = ""
@export_range(1, 1024) var frame_count: int = 15
@export_range(0.01, 240.0) var fps: float = 12.0
@export var loop: bool = false
@export var sheets: Dictionary[String, String] = {}
