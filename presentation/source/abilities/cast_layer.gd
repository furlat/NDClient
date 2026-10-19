class_name PresentationCastLayer
extends Resource
## A sprite overlay drawn on the caster's rig during the cast: the hand glow
## (Magic1-3) or an effect sheet (Effect1-5), recoloured by a palette ramp.
const Look = preload("res://presentation/source/look.gd")
## weapon_glow, aura or effect (the old recipe's weaponGlow / aura / effects[]).
@export_enum("weapon_glow", "aura", "effect") var place: String = "weapon_glow"
## Sprite category and its sheet for this clip (old logical sheet URL).
@export var category: String = ""
@export var sheet: String = ""
@export var enabled: bool = true
@export var hidden: bool = false
## The palette_ramp step that recolours it (colours, noise sheet, gamma).
@export var look: Look
## Old-model metadata (id, slot, role, colour mode) kept as exported.
@export var unported: Dictionary = {}
