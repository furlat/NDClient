class_name PresentationObjectState
extends Resource
## One displayed state of an environment object: a bank and the frame it rests
## on, or one image per camera view for objects drawn from single images.
@export var bank: String = ""
## Frame shown at rest: 0 the first, -1 the last.
@export var frame: int = 0
## View -> image id (fixtures drawn from single images).
@export var images: Dictionary[String, String] = {}
