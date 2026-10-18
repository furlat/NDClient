extends "res://assets/vfx/sources/c6e201dbffbdead64da9/payload_item.gd"
## Local material contrast on the existing tiny retained bead. No new light,
## radius, anchor, power calculation, state admission or lifetime ownership.


static func make_component(input: Dictionary) -> Node3D:
	assert(input.kind == "delayed_fire")
	assert(not str(input.get("item_uuid", "")).is_empty() and not str(input.get("lifetime_uuid", "")).is_empty())
	assert(not str(input.get("original_caster_uuid", "")).is_empty())
	var node: Node3D = VfxPackageIO_82dcbb6479.resource("res://assets/vfx/sources/82dcbb6479593213885a/payload_item_readable.gd").new()
	node.specification = input.duplicate(true)
	node.set_payload_state(input.get("state", {}))
	return node


func prepare() -> void:
	super.prepare()
	for material in materials:
		var shader := Shader.new()
		shader.code = Native.Source.finish_fragment(material.shader.code,
			"\nALBEDO *= 4.0; EMISSION *= 4.0;\n")
		Native.Source.replace_shader(material, shader)

const VfxPackageIO_82dcbb6479 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
