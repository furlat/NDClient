class_name PresentationSheetTable
extends Resource
## Sheet keys other domains' layers name (spell hand noise, condition films),
## admitted through the body sources so cast layers can borrow them. Paths are
## relative to res://assets/.
@export var id: String = ""
@export var sheets: Dictionary[String, String] = {}
## Domain that owns these images.
@export var owner: String = ""
## Keep the legacy /media/ identity at run time while the owner's readers still use it.
@export var legacy_media_identity: bool = false
@export_multiline var notes: String = ""
