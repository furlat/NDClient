class_name PresentationActivityPose
extends Resource
## Select an existing rig clip for an activity; movement and commits keep their clocks.
@export var rig_id: String = ""
@export_enum("idle", "move") var activity: String = "idle"
@export var clip: String = ""
@export_enum("loop", "hold") var sampling: String = "loop"
@export_range(0, 1024) var frame: int = 0
@export_range(0.01, 8.0) var playback_speed: float = 1.0
