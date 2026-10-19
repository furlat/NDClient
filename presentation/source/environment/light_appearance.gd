class_name PresentationLightAppearance
extends Resource
## One server light appearance (torch, neutral): the colour it casts, whether
## it flickers with its flame, its cookie and its optical height.
@export var appearance: String = ""
@export var colour: Color = Color.WHITE
## The flame art whose per-frame energy drives the flicker; empty: steady.
@export var flame: String = ""
## Light cookie image (res://assets/ relative); empty: the generated range cookie.
@export var cookie: String = ""
## Optical height above the support for carried sources, in elevation steps.
@export var carried_height_steps: float = 0.0
## Item ids that show this appearance when their light is not disclosed separately.
@export var item_ids: PackedStringArray = []
@export_enum("ready", "partial", "stand_in", "missing", "internal") var status: String = "ready"
@export_multiline var notes: String = ""
