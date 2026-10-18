class_name PresentationContext
extends Resource
## Global defaults that entries override: damage, healing, death, death
## saves, life states, movement, forced movement, equipment, number and badge
## styles, arrow style, hit responses and the hit flash.
const BodyUse = preload("res://presentation/source/abilities/body_use.gd")
const Feedback = preload("res://presentation/source/abilities/feedback.gd")
@export var id: String = ""
## The body it plays by default (damage hurt, death die, equipment taunt...).
@export var body: BodyUse
## Named texts (success, failure, dying, stable, heal...).
@export var texts: Dictionary[String, Feedback] = {}
## Named values in seconds, tiles, pixels or hex colours as their names say.
@export var values: Dictionary = {}
@export var unported: Dictionary = {}
@export_multiline var notes: String = ""
