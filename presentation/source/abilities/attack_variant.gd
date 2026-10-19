class_name PresentationAttackVariant
extends Resource
## One attack presentation chosen by match rules (delivery, weapon slot,
## outcome, item, source kind, rig, damage types) and precedence: its body
## clip and contact, slash layers, projectile and trail. Characters override
## per rig and item through these matches.
const BodyUse = preload("res://presentation/source/abilities/body_use.gd")
@export var id: String = ""
@export var precedence: float = 0.0
## Match rules as exported (kind, delivery, weaponSlots, outcomes,
## sourceItemIds, sourceItemRefs, sourceKinds, rigIds, elemental,
## primaryDamageTypes); null rules match anything.
@export var match: Dictionary = {}
@export var body: BodyUse
## Slash sprite layers per outcome (onHit, onMiss, onCrit -> slot -> category, tint).
@export var slash: Dictionary = {}
## Arrow speed in tiles per second, and the measured release sockets per rig
## (res path relative to res://assets/).
@export var flight_tiles_per_second: float = 0.0
@export var sockets: String = ""
## The rest of the variant as exported (its arrow shape, trajectory...).
@export var unported: Dictionary = {}
