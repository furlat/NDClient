class_name PresentationPart
extends Resource
## One modular part category (Chest7, Head10, Melee20): its sheet per action
## with depth and normals, and the source palette it was painted with.
const ArtSource = preload("res://presentation/source/art_source.gd")
const Palette = preload("res://presentation/source/palette.gd")
@export var id: String = ""
## Category family (Chest, Head, Melee ...).
@export var family: String = ""
## Rig slots that accept this part.
@export var slots: PackedStringArray = []
## Action name (as the files name it) -> sheet, with its surface.
@export var actions: Dictionary[String, ArtSource] = {}
## Source palette (primary, secondary, tertiary) and which of its colours are gray.
@export var palette: Palette
@export var palette_gray: Array[bool] = []
## Measured surface-socket samples per action: path relative to res://assets/.
@export var measurements: String = ""
@export_enum("ready", "partial", "stand_in", "missing") var status: String = "ready"
@export_multiline var notes: String = ""
