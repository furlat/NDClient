class_name PresentationIconSet
extends Resource
## Icons the HUD shows that no other entry owns (end turn, page buttons ...),
## keyed by the client's common id.
const ImageRef = preload("res://presentation/source/image_ref.gd")
@export var id: String = ""
@export var icons: Dictionary[String, ImageRef] = {}
@export var labels: Dictionary[String, String] = {}
@export var source: String = ""
@export_multiline var notes: String = ""
