class_name PresentationContext
extends Resource
## Global defaults that entries override: damage, healing, death, death
## saves, life states, movement, forced movement, equipment, number and badge
## styles, arrow style, hit responses and the hit flash.
const BodyUse = preload("res://presentation/source/abilities/body_use.gd")
const EffectUse = preload("res://presentation/source/effect_use.gd")
const Feedback = preload("res://presentation/source/abilities/feedback.gd")
@export var id: String = ""
## The body it plays by default (damage hurt, death die, equipment taunt...).
@export var body: BodyUse
## Named texts (success, failure, dying, stable, heal...).
@export var texts: Dictionary[String, Feedback] = {}
## Named values in seconds, tiles, pixels or hex colours as their names say.
@export var values: Dictionary = {}
## Item attachment uses select exact disclosed item-effect membership globally;
## Per-gear intrinsic sources remain exact-item assignments.
@export var effects: Array[EffectUse] = []
## Finite contacts selected from the actual equipped attack's disclosed item
## memberships, independent of whichever weapon the actor holds later.
@export var impact_effects: Array[EffectUse] = []
## Actual DamageResultFact.body_release identities select only these authored
## region source/residue pairs. They do not infer release from species/damage.
@export var release_sources: Dictionary[String, Dictionary] = {}
## Exact top-level fields retained in unported as inactive reference studies.
## Their original values stay inspectable; they select no rendering or timing.
@export var inactive_legacy_fields: PackedStringArray = PackedStringArray()
@export var unported: Dictionary = {}
@export_multiline var notes: String = ""
