extends "res://assets/vfx/extensions/followup-20261020/sources/d9eb87da8c2b85a8c2dd/condition_pose_occurrence.gd"

static func preparation_resources(input: Dictionary) -> Array:
	return [input.get("pose_interface_bank","res://assets/vfx/extensions/followup-20261020/sources/995242841f3e83a670d7/interface.tres")]

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D=VfxPackageIO_799600ed4f.resource("res://assets/vfx/extensions/followup-20261020/sources/799600ed4fe4908d8576/application.gd").new()
	instance.parameters={"scene":"res://assets/vfx/conditions/condition_weird_persistent/prepared.scn","geometry":["receiving/ReceivingForm0Layer0","receiving/ReceivingForm1Layer0","receiving/ReceivingForm2Layer0","receiving/ReceivingForm0Layer1","receiving/ReceivingForm1Layer1","receiving/ReceivingForm2Layer1"],"emitters":[],"application_seconds":0.35,"removal_seconds":0.35,"loop_seconds":38.0799109526036,"sustain_gain":1.0,"adaptive_surface":{"kind":"forms","settings":{"height_cap_cells":0.45,"readable":false,"width_cap_cells":0.28},"prepared_pose_table":true},"phase":"application","pose_interface_bank":"res://assets/vfx/extensions/followup-20261020/sources/995242841f3e83a670d7/interface.tres"}
	instance.parameters.merge(input,true)
	return instance

const VfxPackageIO_799600ed4f = preload("res://assets/vfx/extensions/followup-20261020/scoped_resource_io.gd")
