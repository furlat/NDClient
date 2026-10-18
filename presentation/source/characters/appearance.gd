class_name PresentationAppearance
extends Resource
## How the server's AppearanceConfig values become parts on the layered rig.
@export var rig: String = "neuroclient.modular"
## AppearanceConfig field -> rig slot it fills (body_category -> body, head_category -> head).
@export var category_slots: Dictionary[String, String] = {}
## Field -> the part it selects when the server sends only a flag (has_beard -> Head2).
@export var flag_parts: Dictionary[String, String] = {}
## Tint field -> slot it multiplies (skin_tint -> body, hair_tint -> head, beard_tint -> beard).
@export var tint_slots: Dictionary[String, String] = {}
## Server equipment slot -> visual slot (MELEE_MAIN -> weapon_melee_main ...).
@export var equipment_slots: Dictionary[String, String] = {}
## Weapon slots that show only with their weapon set (melee / ranged).
@export var weapon_sets: Dictionary[String, String] = {}
## Rig slots drawn only by effects, never by gear.
@export var effect_slots: PackedStringArray = []
## Rules as data, e.g. {"rule": "helmet_hides_head", "except": ["Head5", "Head8"], "applies": false}.
@export var rules: Array[Dictionary] = []
## Server values that exist but are not drawn (placeholder_tint).
@export var unused_fields: PackedStringArray = []
@export_multiline var notes: String = ""
