extends "res://assets/vfx/extensions/material-runtime-20261021/sources/4a236db91859c712a27e/assembly.gd"
## Preserve the original generic timed assembly, private processes and body fit.


static func preparation_resources(input: Dictionary) -> Array:
	var paths: Array = []
	for entry: Dictionary in input.entries:
		for specification: Dictionary in entry.composition.components:
			var path: String = specification.input.prepared_recipient_bank
			if path not in paths:
				paths.append(path)
	return paths


static func make_component(input: Dictionary) -> Node3D:
	assert(not input.get("opacity_control", false), "This exact source has no outer material-opacity writer")
	var node: Node3D = VfxPackageIO_425491fe00.resource("res://assets/vfx/extensions/material-runtime-20261021/sources/425491fe00d93a21a92e/assembly.gd").new()
	node.selections = input.entries.duplicate(true)
	node.opacity_control = false
	return node


func sample(seconds: float) -> void:
	super.sample(seconds)
	_publish_display(seconds)


func refresh_live_inputs(seconds: float) -> void:
	super.refresh_live_inputs(seconds)
	_publish_display(seconds)


func _publish_display(seconds: float) -> void:
	for entry: Dictionary in entries:
		var frame := Transform3D.IDENTITY
		if entry.has("last_transform"):
			frame = entry.last_transform.affine_inverse()
		for component: Node3D in entry.composition.components.values():
			component.display.publish(seconds, frame)

const VfxPackageIO_425491fe00 = preload("res://assets/vfx/extensions/material-runtime-20261021/scoped_resource_io.gd")
