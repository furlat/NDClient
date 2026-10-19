class_name PresentationConnector
extends Resource
## One server traversal connector kind (ladder, rope, lift, vertical_stairs,
## passage): its art and the movement body context an actor uses on it.
@export var kind: String = ""
## The server's presentation_key for it (traversal.<kind>).
@export var presentation_key: String = ""
@export var art: String = ""
## Movement body context role (climb, rope_climb, ride, walk...).
@export var body_context: String = ""
@export_enum("ready", "partial", "stand_in", "missing", "internal") var status: String = "missing"
@export_multiline var notes: String = ""
