class_name PresentationRigContext
extends Resource
## A body context: which clip a situation plays (movement by mode and
## trajectory, shove, forced move, death, equipment, condition entry/hold/exit)
## and how it plays.
@export var role: String = ""
## kind (default, movement, condition ...) and its qualifiers as the server names them.
@export var qualifier: Dictionary = {}
@export var clip: String = ""
@export var enabled: bool = true
@export var playback_speed: float = 1.0
@export var hidden_slots: PackedStringArray = []
## Cue media the context adds (none authored today).
@export var media: Array = []
## loop when the body loops for the whole context.
@export var playback: String = ""
## [[time fraction, frame], ...] keys; empty plays the clip's own clock.
@export var frame_keys: Array = []
## [{name, frame}] markers of this context (contact, brace ...).
@export var anchors: Array = []
@export var reversed: bool = false
## Frame held after the context, -1 for none.
@export var rest_frame: int = -1
