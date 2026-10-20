extends "res://assets/vfx/extensions/followup-20261020/sources/d9eb87da8c2b85a8c2dd/condition_pose_occurrence.gd"

static func preparation_resources(input: Dictionary) -> Array:
	return [input.get("pose_interface_bank","res://assets/vfx/extensions/followup-20261020/sources/8a98577ccc83101c2b6c/interface.tres")]

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D=VfxPackageIO_6fc1b6a6af.resource("res://assets/vfx/extensions/followup-20261020/sources/6fc1b6a6af02572dfeaf/application.gd").new()
	instance.parameters={"scene":"res://assets/vfx/conditions/condition_phantasmal_killer_persistent/prepared.scn","geometry":["receiving/ReceivingForm0Layer0","receiving/ReceivingForm1Layer0","receiving/ReceivingForm0Layer1","receiving/ReceivingForm1Layer1"],"emitters":[],"application_seconds":0.35,"removal_seconds":0.35,"loop_seconds":19.6349540849362,"sustain_gain":1.0,"adaptive_surface":{"kind":"forms","settings":{"height_cap_cells":0.12,"readable":true,"width_cap_cells":0.17},"prepared_pose_table":true},"phase":"application","pose_interface_bank":"res://assets/vfx/extensions/followup-20261020/sources/8a98577ccc83101c2b6c/interface.tres"}
	instance.parameters.merge(input,true)
	return instance

const VfxPackageIO_6fc1b6a6af = preload("res://assets/vfx/extensions/followup-20261020/scoped_resource_io.gd")
