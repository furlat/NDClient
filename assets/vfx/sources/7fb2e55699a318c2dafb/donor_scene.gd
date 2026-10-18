extends RefCounted


## Explicitly remove obsolete donor control scripts from an in-memory scene copy.
## Native geometry, materials, particle data and AnimationPlayers remain intact.
static func instantiate(source: PackedScene, disabled_scripts: Array) -> Node:
	if disabled_scripts.is_empty():
		return source.instantiate()
	var bundle: Dictionary = source.get("_bundled").duplicate(true)
	var matched: Dictionary = {}
	for index in bundle.variants.size():
		var value: Variant = bundle.variants[index]
		if value is Script and value.resource_path in disabled_scripts:
			matched[value.resource_path] = true
			bundle.variants[index] = null
	for path in disabled_scripts:
		if not matched.has(path):
			push_error("Declared donor driver not present: " + str(path))
			return null
	var prepared := PackedScene.new()
	prepared.set("_bundled", bundle)
	return prepared.instantiate()
