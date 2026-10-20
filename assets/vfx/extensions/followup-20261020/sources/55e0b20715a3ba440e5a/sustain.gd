extends "res://assets/vfx/extensions/followup-20261020/sources/d9eb87da8c2b85a8c2dd/condition_pose_occurrence.gd"

static func preparation_resources(input: Dictionary) -> Array:
	return [input.get("pose_interface_bank","res://assets/vfx/extensions/followup-20261020/sources/8440de33d0916f8d3348/interface.tres")]

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D=VfxPackageIO_55e0b20715.resource("res://assets/vfx/extensions/followup-20261020/sources/55e0b20715a3ba440e5a/sustain.gd").new()
	instance.parameters={"scene":"res://assets/vfx/conditions/condition_ensnaring_vines_persistent/prepared.scn","geometry":["owned_contact/MeasuredBarkVine0","owned_contact/MeasuredBarkVine1","owned_contact/MeasuredBarkVine2"],"emitters":[],"application_seconds":0.35,"removal_seconds":0.35,"loop_seconds":2.0,"sustain_gain":1.0,"adaptive_surface":{"kind":"support","settings":{"geometry_slots":["body","chest","cloak","legs","shoes"],"vine_bounds":true},"prepared_pose_table":true},"phase":"sustain","pose_interface_bank":"res://assets/vfx/extensions/followup-20261020/sources/8440de33d0916f8d3348/interface.tres"}
	instance.parameters.merge(input,true)
	return instance

const VfxPackageIO_55e0b20715 = preload("res://assets/vfx/extensions/followup-20261020/scoped_resource_io.gd")
