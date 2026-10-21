extends "res://assets/vfx/extensions/production-review-20261020/sources/31e748f7ee89dab7359c/baked_effect_bundle.gd"
## Optional recording data. Existing bundles/player defaults stay unchanged.
## Each placement binds an indexed private material's uniform to the inverse
## world transform of the named actual source component, relative to scene root.
@export var material_placements: Array[Dictionary] = []
## The source's one-time formation followed by its authored cycle. Empty = none.
@export var source_loop: Dictionary = {}
