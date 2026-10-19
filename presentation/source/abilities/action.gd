class_name PresentationAction
extends Resource
## One server action, trait, reaction, class feature or feat id
## (action.dash, trait.pack_tactics, reaction.spell.shield), including the
## action ids the server sends without a catalogue entry (rage, action surge):
## the body it plays, the object it targets, its effects and feedback.
const EffectUse = preload("res://presentation/source/effect_use.gd")
const ImageRef = preload("res://presentation/source/image_ref.gd")
const SoundRef = preload("res://presentation/source/sound_ref.gd")
const BodyUse = preload("res://presentation/source/abilities/body_use.gd")
const Feedback = preload("res://presentation/source/abilities/feedback.gd")

@export var id: String = ""
## action, trait, reaction, class_feature or feat; the server's family
## (core, environment, item, monster, summon_form, spell, class...).
@export var kind: String = ""
@export var family: String = ""
@export var icon: ImageRef
## authored or state_only.
@export var disposition: String = ""

@export_group("Body")
## Clip role, markers and hidden slots; empty when the action has no body.
@export var body: BodyUse
## Another action's recipe this one plays (door close plays the lever pull).
@export var plays: String = ""
## Shove's own recipe (shove facts read it instead of the action recipe).
@export var shove: bool = false

@export_group("Target")
## Object interaction: the target's server object kind and the transition it
## drives (environment owns the transition's art), e.g. door -> open.
@export var target: String = ""
@export var target_transition: String = ""
## The spell this sub-action delivers (action.spell.sunbeam.strike -> spell.sunbeam).
@export var delivers_spell: String = ""

@export_group("Effects")
## Class-action effects its media play: native sources (the `sources`
## section, built from res://assets/native_effects) whose media ids its old
## media list names, e.g. class.rage.ground.
@export var effect_sources: PackedStringArray = []
@export var feedback: Feedback
@export var sounds: Array[SoundRef] = []

@export_group("Status")
@export_enum("ready", "partial", "stand_in", "missing", "internal") var status: String = "missing"
## Old-model fields with no typed home, as exported.
@export var unported: Dictionary = {}
@export_multiline var notes: String = ""
