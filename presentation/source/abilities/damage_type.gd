class_name PresentationDamageType
extends Resource
## One server damage type (Fire, Slashing...): its palette, impact colour,
## hit response (air spray), number colour and sound. Ground blood deposits
## belong to the environment's residues.
const Palette = preload("res://presentation/source/palette.gd")
const SoundRef = preload("res://presentation/source/sound_ref.gd")
@export var id: String = ""
@export var label: String = ""
## Element colours (primary, secondary, tertiary) and the impact colour.
@export var palette: Palette
@export var impact_colour: String = ""
## Air spray played on a hit (a native source id, e.g. blood.hit_a2); empty
## uses the default response.
@export var hit_response: String = ""
@export var number_colour: String = ""
@export var sounds: Array[SoundRef] = []
@export_enum("ready", "partial", "stand_in", "missing", "internal") var status: String = "missing"
@export var unported: Dictionary = {}
@export_multiline var notes: String = ""
