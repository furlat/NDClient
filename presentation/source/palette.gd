class_name PresentationPalette
extends Resource
## A named set of colours with roles (primary, secondary, tertiary, impact...)
## and an optional ordered ramp. Damage types, spells and looks name palettes.
@export var id: String = ""
@export var roles: Dictionary[String, Color] = {}
@export var ramp: PackedColorArray = []
