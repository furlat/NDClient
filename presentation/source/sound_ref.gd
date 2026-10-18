class_name PresentationSoundRef
extends Resource
## A sound cue (an id in authoring/audio cues) and when it plays.
@export var cue: String = ""
## Event or clip marker it follows (release, contact, effect, footstep frame...).
@export var at: String = ""
@export var delay: float = 0.0
@export var gain_db: float = 0.0
@export var enabled: bool = true
