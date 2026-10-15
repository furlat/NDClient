@tool
extends Resource
## Offline presentation tuning; gameplay and production authoring stay separate.
@export var spell_id := "fire_bolt"
@export var title := "Fire Bolt"
@export_file("*.json") var choreography := "res://authoring/spells/spell.fire_bolt.json"
## Authored retains the spell recipe; alternatives select a complete pose/socket profile.
@export var casting_profile := "authored"
@export_range(0.01, 3.0, 0.01) var effect_scale := 0.18
@export var stage_scales: Dictionary = {"cast":1.0,"travel":1.0,"impact":1.0,"delivery":1.0}
@export_range(0.0, 1.0, 0.01) var lead_in_seconds := 0.15
@export_range(0.0, 1.0, 0.01) var tail_seconds := 0.15
