class_name PresentationObjectPart
extends Resource
## A separately drawn part of an object: a door leaf against its frame, a
## window's parent wall and its insert.
@export_enum("leaf", "frame", "wall", "insert") var role: String = "leaf"
## frame: the static frame image per camera view; empty: the bank's own frame regions.
@export var images: Dictionary[String, String] = {}
## leaf: split into back and front passes by the bank's painter depth.
@export var depth_split: bool = false
## insert/wall: the other object of the pair, by id.
@export var other: String = ""
## insert: not drawn once its parent wall is destroyed.
@export var omit_with_destroyed_parent: bool = false
