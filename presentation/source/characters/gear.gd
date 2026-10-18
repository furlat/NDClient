class_name PresentationGear
extends Resource
## One server item id as the body wears it. A family entry holds the looks per
## visual slot; other ids of the same look name it as their family and the
## visual variant they stand for. Layers are {slot, part, tint "#rrggbb"}.
const ImageRef = preload("res://presentation/source/image_ref.gd")
@export var id: String = ""
## Server item kind (weapon, armor, shield, usable, item).
@export var kind: String = ""
## Item id whose looks this item uses; empty when it holds its own.
@export var family: String = ""
## Visual variant this id stands for (the server still sends visual_variant_id).
@export var visual_variant_id: String = ""
## Visual slot (weapon_melee_main, body_armor, ...) -> {layers: [...], variants: {id: [...]}}.
@export var slots: Dictionary[String, Dictionary] = {}
## Hand overrides: visual slot -> {variant id ("" for none): layers}. They win over slots.
@export var hands: Dictionary[String, Dictionary] = {}
## How the item looks dropped: [{variant, part, clip, frame, rows_by_camera, pivots_by_camera, scale, tint, shadow_part, shadow_scale}].
@export var ground: Array[Dictionary] = []
@export var icon: ImageRef
## Natural, summoned and internal items draw no layers.
@export var natural: bool = false
## Lights when lit (the radius comes from the server).
@export var lights: bool = false
@export_enum("ready", "partial", "stand_in", "missing", "internal") var status: String = "ready"
@export_multiline var notes: String = ""
