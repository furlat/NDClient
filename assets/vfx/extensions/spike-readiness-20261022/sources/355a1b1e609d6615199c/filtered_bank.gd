extends "res://assets/vfx/extensions/spike-readiness-20261022/sources/34191b3521d999d8b475/bank.gd"
## The original walker only follows a getter result when it is a Resource.
## In these exact native classes, ClassDB can prove a direct non-object return
## cannot enter that branch. Script/dynamic/unknown metadata keeps the getter.
const NATIVE_CLASSES := ["ArrayMesh", "QuadMesh", "ShaderMaterial", "StandardMaterial3D"]
var native_properties: Dictionary = {}
var elided_getters: Dictionary = {}


func can_elide_native_getter(value: Resource, property: Dictionary) -> bool:
	if value == null or value.get_script() != null or value.get_class() not in NATIVE_CLASSES:
		return false
	if not property.has("type") or typeof(property.type) != TYPE_INT \
		or not property.has("name") or typeof(property.name) not in [TYPE_STRING, TYPE_STRING_NAME] \
		or not property.has("usage") or typeof(property.usage) != TYPE_INT:
		return false
	if (int(property.usage) & PROPERTY_USAGE_STORAGE) == 0 or int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
		return false
	var native_type: int = property.type
	if native_type <= TYPE_NIL or native_type >= TYPE_MAX or native_type == TYPE_OBJECT:
		return false
	var native_class := value.get_class()
	if not native_properties.has(native_class):
		var definitions := {}
		for native_definition: Dictionary in ClassDB.class_get_property_list(native_class):
			# Native definitions only. Dynamic Shader uniforms/metadata are not
			# inferred from the instance's editable property descriptors.
			definitions[str(native_definition.name)] = native_definition
		native_properties[native_class] = definitions
	var native_property: Dictionary = native_properties[native_class].get(str(property.name), {})
	if native_property.is_empty() or typeof(native_property.get("type")) != TYPE_INT:
		return false
	return int(native_property.type) == native_type \
		and (int(native_property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0


func _resource_step() -> Dictionary:
	var frame: Dictionary = resource_stack.back()
	if frame.stage != "children" or int(frame.property) >= frame.properties.size():
		return super._resource_step()
	var value: Resource = frame.value
	var property: Dictionary = frame.properties[frame.property]
	if not can_elide_native_getter(value, property):
		return super._resource_step()
	# Do not fetch _surfaces (or inspect its Array contents). In particular,
	# ArrayMesh's native getter reads GPU buffers although its returned Array
	# was discarded by the old direct-Resource predicate. The unchanged later
	# Mesh.surface_get_material traversal still follows actual material refs.
	frame.property += 1
	var key := value.get_class() + "/" + str(property.name)
	if not elided_getters.has(key):
		elided_getters[key] = {"native_class": value.get_class(), "name": str(property.name),
			"type": int(property.type), "calls": 0}
	elided_getters[key].calls += 1
	return {"ready": true}
