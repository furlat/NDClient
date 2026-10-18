class_name PresentationObjectTransition
extends Resource
## How an object goes from one state to another (data only today: doors and
## levers snap to their end pose).
const SoundRef = preload("res://presentation/source/sound_ref.gd")
const EffectUse = preload("res://presentation/source/effect_use.gd")
@export var from: String = ""
@export var to: String = ""
## A bank range played between the states; last_frame -1 is the bank's last frame.
@export var bank: String = ""
@export var first_frame: int = 0
@export var last_frame: int = -1
## Per view, the images played in order (fixtures drawn from single images).
@export var images: Dictionary[String, PackedStringArray] = {}
@export var fps: float = 0.0
## Played backwards (a door closing plays its opening bank in reverse).
@export var reversed: bool = false
@export var sound: SoundRef
@export var effect: EffectUse
