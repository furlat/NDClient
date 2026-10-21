extends "res://assets/vfx/extensions/material-runtime-20261021/sources/4abcde8e3ba2b6a1dc85/application.gd"
## Original native geometry/lifecycle; mutable display fields belong to each draw.
const InstanceRestore = preload("res://assets/vfx/extensions/material-runtime-20261021/sources/4ded3a9ddf1737b5bf17/restore.gd")
const Display = preload("res://assets/vfx/extensions/material-runtime-20261021/sources/f0ffda9c0b87b3d8975f/display.gd")
var display := Display.new()


static func preparation_resources(input: Dictionary) -> Array:
	return [input.prepared_recipient_bank]


static func make_component(input: Dictionary) -> Node3D:
	return InstanceRestore.make("res://assets/vfx/extensions/material-runtime-20261021/sources/77f2b9e8e5fe777f123c/application.gd", input)


func source_bindings() -> Dictionary:
	return InstanceRestore.bindings(self)


func advance_lifecycle(delta: float) -> void:
	super.advance_lifecycle(delta)
	var age := float(tick) / float(parameters.simulation_hz)
	display.lifecycle(age, Display.envelope_at(age, settings.curseMode))
