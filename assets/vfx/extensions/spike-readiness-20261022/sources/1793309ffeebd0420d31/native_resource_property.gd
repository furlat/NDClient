extends RefCounted
## Exact v2 direct-Resource predicate; only caller-owned native metadata is cached.
const NATIVE_CLASSES := ["ArrayMesh", "QuadMesh", "ShaderMaterial", "StandardMaterial3D"]


static func can_elide_native_getter(value: Resource, property: Dictionary, native_properties: Dictionary) -> bool:
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
