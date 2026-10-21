extends Resource
## Passive admission index. Paths select actual component categories lazily.
@export var revision: String = ""
@export var root_rig: String = ""
@export var creature_rigs: Dictionary = {}
@export var effect_owned_creatures: Dictionary = {}
@export var rigs: Dictionary = {}
@export var layers: Dictionary = {}
@export var source_owners: Dictionary = {}
@export var equipment: Dictionary = {}
@export var equipment_errors: Dictionary = {}
## Actual item id -> explicit family and exact dropped visual variants.
@export var ground_equipment: Dictionary = {}
## Item id -> ordered native decoration cues. Equipment sheets remain separate.
@export var item_effects: Dictionary = {}
## Item id -> finite cues triggered by its actual attack contact.
@export var item_impact_effects: Dictionary = {}
@export var sheets: Dictionary = {}
## Server item id -> [family item id whose looks it wears, visual variant it stands for].
@export var gear: Dictionary = {}
## AppearanceConfig mapping: category, flag and tint fields -> slots and parts.
@export var appearance: Dictionary = {}
## Measured palette-swap luminance ranges: sheet path -> cell height -> facing -> Vector2.
@export var palette_ranges: Dictionary = {}
