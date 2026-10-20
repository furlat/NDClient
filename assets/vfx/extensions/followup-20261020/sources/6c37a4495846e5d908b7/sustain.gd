extends "res://assets/vfx/extensions/followup-20261020/sources/d9eb87da8c2b85a8c2dd/condition_pose_occurrence.gd"

static func preparation_resources(input: Dictionary) -> Array:
	return [input.get("pose_interface_bank","res://assets/vfx/extensions/followup-20261020/sources/2cf6c17c16d3f0fed83b/interface.tres")]

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D=VfxPackageIO_6c37a44958.resource("res://assets/vfx/extensions/followup-20261020/sources/6c37a4495846e5d908b7/sustain.gd").new()
	instance.parameters={"scene":"res://assets/vfx/conditions/condition_shocked_persistent/prepared.scn","geometry":["network/MeasuredContactArcs1"],"emitters":[],"application_seconds":0.35,"removal_seconds":0.35,"loop_seconds":2.0,"sustain_gain":0.65,"adaptive_surface":{"kind":"electric_contact","settings":{},"prepared_pose_table":true},"phase":"sustain","pose_interface_bank":"res://assets/vfx/extensions/followup-20261020/sources/2cf6c17c16d3f0fed83b/interface.tres"}
	instance.parameters.merge(input,true)
	return instance

const VfxPackageIO_6c37a44958 = preload("res://assets/vfx/extensions/followup-20261020/scoped_resource_io.gd")
