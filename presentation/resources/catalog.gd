class_name PresentationResourceCatalog
extends Resource
## Small selection index. Resource paths avoid eagerly loading a future VFX library.
@export var condition_recipes: Dictionary[String, String] = {}
@export var action_recipes: Dictionary[String, String] = {}
@export var body_clips: PackedStringArray = []
