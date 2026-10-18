class_name PresentationCharacter
extends Resource
## One server creature (or the player body): the rig that draws it, its
## portrait, and how its actions choose clips. Keyed by the server id.
@export var id: String = ""
## Server identity the binding was authored against (pack:creature:id@version), when known.
@export var identity: String = ""
@export var rig: String = ""
## Portrait id in the creature or player bank.
@export var portrait: String = ""
## Server size and the visual scale the art needs for it.
@export var size: String = ""
@export var scale: float = 1.0
## Where cell size and creature size disagree (e.g. a 192 px cell on a Medium creature).
@export var size_note: String = ""
## Attack variants that pick this body's clips: [{variant, delivery, items, clip, contact, trail, ...}].
@export var attacks: Array[Dictionary] = []
## Cast gesture: {role, clip, release_sockets, stand_in}.
@export var cast: Dictionary = {}
## Block, parry and protection -> clip.
@export var reactions: Dictionary[String, String] = {}
## Death clip by damage or outcome ("default" first).
@export var death: Dictionary[String, String] = {}
## What the art shows against what the kit holds.
@export var kit_mismatch: String = ""
@export_enum("ready", "partial", "stand_in", "missing", "internal") var status: String = "ready"
@export_multiline var notes: String = ""
