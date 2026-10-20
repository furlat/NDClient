extends "res://assets/vfx/extensions/followup-20261020/sources/d9eb87da8c2b85a8c2dd/condition_pose_occurrence.gd"

static func preparation_resources(input: Dictionary) -> Array:
	return [input.get("pose_interface_bank","res://assets/vfx/extensions/followup-20261020/sources/453b44fc49c588ec40b1/interface.tres")]

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D=VfxPackageIO_1d86829678.resource("res://assets/vfx/extensions/followup-20261020/sources/1d86829678d2fd3ef6cb/application.gd").new()
	instance.parameters={"scene":"res://assets/vfx/conditions/condition_feeblemind_persistent/prepared.scn","geometry":["receiving/ReceivingForm0Layer0","receiving/ReceivingForm1Layer0","receiving/ReceivingForm0Layer1","receiving/ReceivingForm1Layer1"],"emitters":[],"application_seconds":0.35,"removal_seconds":0.35,"loop_seconds":25.1327412287183,"sustain_gain":1.0,"adaptive_surface":{"kind":"forms","settings":{"height_cap_cells":0.12,"readable":true,"width_cap_cells":0.17},"prepared_pose_table":true},"phase":"application","pose_interface_bank":"res://assets/vfx/extensions/followup-20261020/sources/453b44fc49c588ec40b1/interface.tres"}
	instance.parameters.merge(input,true)
	return instance

const VfxPackageIO_1d86829678 = preload("res://assets/vfx/extensions/followup-20261020/scoped_resource_io.gd")
