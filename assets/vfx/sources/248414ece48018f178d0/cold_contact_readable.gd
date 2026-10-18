extends "res://assets/vfx/sources/4bbc6a884fea6c024ae6/element_contact.gd"
## Same admitted cold packet and measured receiving point; local source mist
## contrast/extent only. This adds no Chilled/Frozen gameplay condition.


static func make_component(input: Dictionary) -> Node3D:
	assert(input.element == "cold")
	var node: Node3D = VfxPackageIO_248414ece4.resource("res://assets/vfx/sources/248414ece48018f178d0/cold_contact_readable.gd").new()
	node.specification = input.duplicate(true)
	node.set_damage_event(input.get("event", {}))
	return node


func sample(seconds: float) -> void:
	super.sample(seconds)
	if not draw.visible:
		return
	var transform: Transform3D = draw.global_transform
	transform.basis = transform.basis.scaled(Vector3.ONE * 1.5)
	draw.global_transform = transform
	material.set_shader_parameter("ward_alpha", minf(1.0, float(material.get_shader_parameter("ward_alpha")) * 1.75))

const VfxPackageIO_248414ece4 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
