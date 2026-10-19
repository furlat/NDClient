class_name PresentationResourceCatalog
extends Resource
## Small selection index. Resource paths avoid eagerly loading a future VFX library.
@export var condition_recipes: Dictionary[String, String] = {}
@export var action_recipes: Dictionary[String, String] = {}
# The animation schema's supplied default for movement_reference_speed_feet.
# The compiler needs only this value; it no longer parses the 213 KB schema.
@export var movement_reference_speed_feet: float = 30.0
