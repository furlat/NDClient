class_name PresentationFeedback
extends Resource
## Floating text or badge shown for an outcome (Miss, +Dashing, Heal...).
@export var enabled: bool = true
@export var text: String = ""
## Text put before the condition label (+ / -) when the text is built from it.
@export var prefix: String = ""
@export_color_no_alpha var colour: Color = Color.WHITE
## Seconds on screen; 0 uses the badge style's default.
@export var duration: float = 0.0
@export var unported: Dictionary = {}
