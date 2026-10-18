class_name PresentationArtSource
extends Resource
## One image set described by its own measurements, never by assumption: a
## 64 px animal, a 384 px door bank and a 128 px modular sheet differ only in
## these numbers. Paths are relative to res://assets/ (e.g. "art/media/...").
const Surface = preload("res://presentation/source/surface.gd")

## grid_sheet: columns are frames, rows are directions. atlas: explicit rects.
## views_as_files / frames_as_files / stacked_views: one image per view, per
## frame, or views stacked vertically. recording / scene: a Factory clip.
@export_enum("grid_sheet", "atlas", "views_as_files", "frames_as_files", "stacked_views", "recording", "scene", "mesh") var container: String = "grid_sheet"
@export var path: String = ""
## Per-view or per-frame files, and atlas rects (x, y, w, h) when container needs them.
@export var files: PackedStringArray = []
@export var rects: Array[Rect2i] = []
@export var cell: Vector2i = Vector2i.ZERO
@export_range(0, 4096) var frames: int = 0
## 0 means the source has no authored clock.
@export_range(0.0, 240.0) var fps: float = 0.0
## facing8: 8 rows of facings. camera4: one view per camera quarter. single: one
## view. repeated: one view copied into every row (no per-direction art).
@export_enum("facing8", "camera4", "single", "repeated") var directions: String = "facing8"
## Row (or file) order of the directions, e.g. E,SE,S,SW,W,NW,N,NE or e,s,w,n.
@export var direction_order: PackedStringArray = []
## Ground contact and body centre, in cell pixels.
@export var pivot: Vector2 = Vector2.ZERO
@export var anchor: Vector2 = Vector2.ZERO
@export var scale: float = 1.0
@export_range(0.0, 90.0) var camera_elevation_degrees: float = 0.0
@export var pixels_per_metre: float = 0.0
@export var surface: Surface
## Generated measurements beside the art (sockets, ground line, trails), res path.
@export var measurements: String = ""
## Delivery id and version the art came from.
@export var source: String = ""
@export_enum("ready", "partial", "stand_in", "missing") var status: String = "ready"
@export_multiline var notes: String = ""
