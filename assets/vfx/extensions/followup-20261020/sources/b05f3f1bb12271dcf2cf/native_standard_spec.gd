extends Resource
## Immutable OFFLINE native-property operands; runtime keeps the native class,
## colour-space, feature setters and per-owner mutable material instance.
const Values = preload("res://assets/vfx/extensions/followup-20261020/sources/982094992f0fc8016d1d/values.gd")
@export var properties: Array[Dictionary] = []

static func prepare(source: StandardMaterial3D) -> Resource:
	assert(source.next_pass == null,"No implicit nested material restoration")
	var defaults := StandardMaterial3D.new()
	var spec: Resource = VfxPackageIO_b05f3f1bb1.resource("res://assets/vfx/extensions/followup-20261020/sources/b05f3f1bb12271dcf2cf/native_standard_spec.gd").new()
	for property: Dictionary in source.get_property_list():
		if not (int(property.usage) & PROPERTY_USAGE_STORAGE): continue
		var name := str(property.name)
		if name == "script":
			assert(source.get_script() == null,"Native materials cannot carry unknown executable writers")
			continue
		assert(not name.begins_with("metadata/"),
			"Executable/unknown nested metadata needs explicit native-material admission")
		var value: Variant = source.get(name)
		if Values.different(value,defaults.get(name)):
			spec.properties.append({"property":name,"value":value})
	return spec

func make_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	for property: Dictionary in properties:
		material.set(property.property,property.value)
	return material

const VfxPackageIO_b05f3f1bb1 = preload("res://assets/vfx/extensions/followup-20261020/scoped_resource_io.gd")
