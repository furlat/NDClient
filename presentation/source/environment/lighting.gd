class_name PresentationLighting
extends Resource
## How light is presented around the lights themselves: the range profile at
## the server's radius boundaries, light-level treatments, ambient and
## directional sources.
@export var id: String = "lighting"
## Optical intensity at the very bright and bright range edges.
@export_range(0.0, 1.0) var very_bright_edge: float = 0.85
@export_range(0.0, 1.0) var bright_edge: float = 0.7
## Optical height of a source with no carried registration, in elevation steps.
@export var unregistered_height_steps: float = 1.0
## Cookie used for every light when no range profile applies (res://assets/ relative).
@export var fallback_cookie: String = ""
## Light level (0 magical darkness .. 4 very bright, authored, memory) -> treatment id and tint.
@export var treatments: Dictionary[String, String] = {}
@export var treatment_tints: Dictionary[String, Color] = {}
## Directional sources: {id, direction_to_source, colour_linear, intensity}.
@export var directional: Array[Dictionary] = []
@export_multiline var notes: String = ""
