class_name PresentationImageRef
extends Resource
## An icon or portrait bound by the client from its own banks (never the
## server's icon/portrait keys). Paths are relative to res://assets/.
@export var path: String = ""
@export var rect: Rect2i = Rect2i()
@export var native_size: Vector2i = Vector2i.ZERO
@export var pivot: Vector2 = Vector2.ZERO
## Named size variants (hud, sheet, preview, initiative, ...) -> path.
@export var sizes: Dictionary[String, String] = {}
## Another entry's image used on purpose, e.g. a shared Help glyph.
@export var reuses: String = ""
@export_enum("ready", "stand_in", "missing") var status: String = "ready"
@export var source: String = ""
