class_name PresentationRig
extends Resource
## One art variant and how its body plays: the layered modular rig, or one
## creature's own sheets. Every number is this art's own (cell, pivot, frames).
const Clip = preload("res://presentation/source/characters/rig_clip.gd")
const Context = preload("res://presentation/source/characters/rig_context.gd")
@export var id: String = ""
## layered: parts per slot. fixed: the creature's own sheets.
@export_enum("layered", "fixed") var kind: String = "fixed"
## Delivery pack and the variant's own folder name, e.g. undead / 3DarkKnight.
@export var pack: String = ""
@export var variant: String = ""
@export var source: String = ""
@export var cell: Vector2i = Vector2i(128, 128)
## Ground contact and body centre in cell pixels.
@export var pivot: Vector2 = Vector2.ZERO
@export var anchor: Vector2 = Vector2.ZERO
## Explicit feedback placement; the painted anchor is generic authoring, not anatomy.
@export_enum("legacy", "painted_body_anchor") var feedback_anchor: String = "legacy"
@export_enum("facing8", "camera4", "single", "repeated") var directions: String = "facing8"
## Sheet row of each facing, top to bottom.
@export var direction_order: PackedStringArray = ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]
@export var camera_elevation_degrees: float = 45.0
## Layer draw order and the categories each slot accepts.
@export var slot_order: PackedStringArray = []
@export var slot_categories: Dictionary[String, PackedStringArray] = {}
## Layered rig: part categories it never offers for selection.
@export var excluded_categories: PackedStringArray = []
@export var clips: Array[Clip] = []
## Explicit stand-ins: role -> clip name drawn instead (each flagged stand_in).
@export var fallbacks: Dictionary[String, String] = {}
@export var contexts: Array[Context] = []
## generated from depth, baked into the colour, separate sheets, or none.
@export_enum("generated", "baked", "separate", "none") var shadow: String = "generated"
## Alpha of a separate shadow sheet; -1 when not authored.
@export var shadow_alpha: float = -1.0
## Scale of lifecycle effects on this body; 0 when not authored.
@export var lifecycle_scale: float = 0.0
## The art draws its own wings (flight shows no added wings).
@export var native_wings: bool = false
## Clips held on their last frame after playing (the rest poses).
@export var hold_clips: PackedStringArray = []
## Optical ground line in source pixels when the rig has no measured one per clip.
@export var ground_pixels: float = 0.0
## Measured sockets, rest anchors and clip sockets: path relative to res://assets/.
@export var measurements: String = ""
@export_enum("ready", "partial", "stand_in", "missing") var status: String = "ready"
@export_multiline var notes: String = ""
