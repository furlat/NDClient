class_name PresentationAttack
extends Resource
## Attack defaults for one attack behaviour (action.attack,
## action.monster.natural_attack, reaction.opportunity_attack...): outcome
## feedback, the weapon trail and its variants per delivery, rig and item.
const BodyUse = preload("res://presentation/source/abilities/body_use.gd")
const AttackVariant = preload("res://presentation/source/abilities/attack_variant.gd")
const Feedback = preload("res://presentation/source/abilities/feedback.gd")
const NativeSource = preload("res://presentation/source/abilities/native_source.gd")
@export var id: String = ""
@export var body: BodyUse
## Outcome texts: hit, miss, critical, critical_miss (absent: none).
@export var outcome_texts: Dictionary[String, Feedback] = {}
@export var variants: Array[AttackVariant] = []
## Weapon trail: which behaviours and outcomes draw it, its palette, and the
## measured per-frame weapon points (res path relative to res://assets/).
@export var trail_palette: PackedStringArray = []
@export var trail_outcomes: PackedStringArray = []
@export var trail_behaviours: PackedStringArray = []
@export var trail_points: String = ""
## Source choice and native source-clock window for the measured weapon
## path. Actual body contact fits this authored source time to the same track.
@export var trail_source: NativeSource
@export var trail_impact_source: NativeSource
@export var trail_contact_seconds: float = 0.0
@export var trail_end_seconds: float = 0.0
@export var trail_unported: Dictionary = {}
## Measured arrow release sockets per variant id (res path relative to res://assets/).
@export var variant_sockets: String = ""
@export_enum("ready", "partial", "stand_in", "missing", "internal") var status: String = "ready"
@export var unported: Dictionary = {}
@export_multiline var notes: String = ""
