class_name PresentationPortraitBank
extends Resource
## One portrait bank (player, creature or hero aliases): portrait id -> image.
const ImageRef = preload("res://presentation/source/image_ref.gd")
@export var id: String = ""
@export var portraits: Dictionary[String, ImageRef] = {}
## Display labels (player portrait choices).
@export var labels: Dictionary[String, String] = {}
## Alias id -> portrait id it shows (premade heroes).
@export var aliases: Dictionary[String, String] = {}
## Named sizes the art was drawn for: name -> size in px (hud, sheet, preview ...).
@export var named_sizes: Dictionary[String, Vector2i] = {}
@export var source: String = ""
@export_multiline var notes: String = ""
