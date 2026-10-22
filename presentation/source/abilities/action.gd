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
## Optional actual public fact kind for this catalog Action's body only.
## Empty keeps ordinary dispatch; the wire fact/outcome/ancestry never change.
@export var body_fact_kind: String = ""
## Another action's recipe this one plays (door close plays the lever pull).
@export var plays: String = ""
## Shove's own recipe (shove facts read it instead of the action recipe).
@export var shove: bool = false

@export_group("Target")
## Object interaction: the target's server object kind and the transition it
## drives (environment owns the transition's art), e.g. door -> open.
@export var target: String = ""
@export var target_transition: String = ""
## Related spell authoring identity. This is not a runtime delivery alias:
## the actual sub-action declares its effects or an explicit state-only owner.
@export var delivers_spell: String = ""

@export_group("Effects")
## Class-action effects its media play: native sources (the `sources`
## section, built from res://assets/native_effects) whose media ids its old
## media list names, e.g. class.rage.ground.
@export var effect_sources: PackedStringArray = []
## Explicit uses of the existing non-Factory native source programs. The old
## media descriptor retains its actual socket, finite window and predicates.
@export var media: Array[Dictionary] = []
## One completed public fact's immediate nullable witness, not an ActionFact
## or a gameplay reconstruction. The producer schema validates every field.
@export var observed_fact: Dictionary = {}
## Factory package cues on this action's own authored body/event anchors.
## Source media is migrated in the authored entry, never suppressed by name.
@export var effects: Array[EffectUse] = []
## Possible disclosed condition owners created by this action. Selection uses
## this finite set only to prepare sources; actual rows own publication.
@export var applies_conditions: PackedStringArray = []
@export var feedback: Feedback
## Actual ActionFact.reaction.succeeded chooses succeeded or failed. These
## labels do not infer the reaction mode or a result from canceled children.
@export var reaction_feedback: Dictionary[String, Feedback] = {}
@export var sounds: Array[SoundRef] = []

@export_group("Status")
@export_enum("ready", "partial", "stand_in", "missing", "internal") var status: String = "missing"
## Old-model fields with no typed home, as exported.
@export var unported: Dictionary = {}
@export_multiline var notes: String = ""
