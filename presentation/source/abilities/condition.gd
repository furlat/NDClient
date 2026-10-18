class_name PresentationCondition
extends Resource
## One server condition id (condition.spell.shield), or a condition the pinned
## engine sends under a trait or class feature id. Its lifecycle is the
## package's condition selections; its look changes the body; zone conditions
## point at their surface.
const ImageRef = preload("res://presentation/source/image_ref.gd")
const SoundRef = preload("res://presentation/source/sound_ref.gd")
const Look = preload("res://presentation/source/look.gd")
const BodyUse = preload("res://presentation/source/abilities/body_use.gd")
const Feedback = preload("res://presentation/source/abilities/feedback.gd")

@export var id: String = ""
@export var label: String = ""
## HUD icon (the game shows no condition icons yet).
@export var icon: ImageRef
## authored or state_only (state only draws nothing).
@export var disposition: String = ""

@export_group("Lifecycle")
## Package condition selections played from the server's condition owner
## (application, sustain on the owner's age, removal), in package order.
@export var lifecycle: PackedStringArray = []
## The spell whose staging names this condition as its lifecycle owner.
@export var owner_spell: String = ""
## Surface id of a zone condition (its visuals belong to the surface).
@export var surface: String = ""

@export_group("Look")
## Body adjust, film, outline and pose steps while it lasts.
@export var look: Look
## Held or looping poses per rig and activity (hide crouch, frozen frames).
@export var poses: Array = []
## Old sprite condition layers as exported (asset ids; drawn only through a
## native source naming them, e.g. Raging's mantle); their media rows are the
## shared condition_media context.
@export var layers: Array = []

@export_group("Stacking")
@export var group: String = ""
@export var exclusive_group: String = ""
@export var priority: float = 0.0
@export var max_layers: float = 0.0

@export_group("Feedback")
@export var application_text: Feedback
@export var removal_text: Feedback
@export var application_body: BodyUse
@export var removal_body: BodyUse
## Body playback multiplier while it lasts (haste).
@export var playback_rate: float = 0.0
## The reaction spell whose cast gesture plays on application (Shield).
@export var reaction_cast: String = ""
## Sound per phase (application, removal, persistent), mirroring the audio
## library's bindings (authoring/audio/bindings.json, checked by the build).
@export var sounds: Dictionary[String, Resource] = {}

@export_group("Status")
@export_enum("ready", "partial", "stand_in", "missing", "internal") var status: String = "missing"
## Old-model fields with no typed home, as exported (relationships,
## classification, equipment modifiers, appearance layers...).
@export var unported: Dictionary = {}
@export_multiline var notes: String = ""
