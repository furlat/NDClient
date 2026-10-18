@tool
extends Resource
## One authored component selection. Constructors and donor scenes remain shared.

@export var component_id: String = ""
@export_file("*.gd") var constructor_script: String = ""
@export var input: Dictionary = {}
@export var options: Dictionary = {}
@export_multiline var provenance: String = ""

func to_component() -> Dictionary:
	var result := options.duplicate(true)
	result.merge({
		"id": component_id,
		"script": constructor_script,
		"input": input.duplicate(true),
	}, true)
	return result

func validate() -> PackedStringArray:
	var issues := PackedStringArray()
	if component_id.is_empty():
		issues.append("Component identity is empty.")
	if not FileAccess.file_exists(constructor_script):
		issues.append("Missing constructor: " + constructor_script)
	if input.has("scene") and not FileAccess.file_exists(str(input.scene)):
		issues.append("Missing selected source scene: " + str(input.scene))
	return issues
