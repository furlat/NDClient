extends Resource
## Prepared immutable draw inputs. Each occurrence duplicates only material state.
@export var layer_id := ""
@export var mesh: Mesh
@export var material: ShaderMaterial
@export var source_paths: PackedStringArray = []


func validate() -> PackedStringArray:
	var issues := PackedStringArray()
	if layer_id.is_empty() or mesh == null or material == null or material.shader == null:
		issues.append("Weapon contact requires a named native mesh/material/program")
	if source_paths.is_empty():
		issues.append("Weapon contact layer requires explicit owned source lineage")
	return issues
