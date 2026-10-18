class_name PresentationSpellVariant
extends Resource
## A variant of a spell: upcast, element choice, outcome (miss, save,
## critical), form, an old child draft (control.blinded, support.*,
## action.spell.*.strike) or a Factory variant selection. Only the fields it
## names override its spell.
const EffectUse = preload("res://presentation/source/effect_use.gd")
## The variant's own id: an old draft key or a Factory selection key.
@export var id: String = ""
## upcast, element, outcome, form, option, sub_action, reaction, draft
@export var kind: String = ""
## The facet value it selects (Fire, miss, wolf, ...).
@export var value: String = ""
## Factory selection key whose staging it carries.
@export var selection: String = ""
@export var effects: Array[EffectUse] = []
## A complete old-model recipe draft for this variant, as exported (the old
## child drafts are full recipes; nothing maps a server fact to them yet).
@export var recipe: Dictionary = {}
@export var staging_from: String = ""
@export_enum("ready", "partial", "stand_in", "missing") var status: String = "missing"
@export_multiline var notes: String = ""
