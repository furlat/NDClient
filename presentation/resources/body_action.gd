class_name PresentationBodyAction
extends Resource
## A source clip and effect marker for an actual server action occurrence.
@export var behavior_id: String
@export var rig_id: String
@export var clip: String
@export_range(0.01, 8.0) var playback_speed: float = 1.0
@export_range(0, 1024) var effect_frame: int = 0
@export var effect_audio_cue: String
