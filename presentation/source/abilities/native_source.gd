class_name PresentationNativeSource
extends Resource
## A class-action or hit effect that is not in the Factory package yet: the
## native source the client builds from its copy in res://assets/native_effects
## (scene or script, clock, canvas, palette). Actions, attacks and damage
## types name it by id; the Factory takes these over later.
@export var id: String = ""
## class_component, authored_script or scene.
@export var kind: String = ""
## The source record as the native effect runtime reads it (script, scene,
## properties, preload paths, duration, loop, emitters, palette...).
@export var record: Dictionary = {}
@export_enum("ready", "partial", "stand_in", "missing", "internal") var status: String = "ready"
@export_multiline var notes: String = ""
