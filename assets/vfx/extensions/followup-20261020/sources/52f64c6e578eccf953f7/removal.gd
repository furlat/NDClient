extends "res://assets/vfx/extensions/followup-20261020/sources/d9eb87da8c2b85a8c2dd/condition_pose_occurrence.gd"

static func preparation_resources(input: Dictionary) -> Array:
	return [input.get("pose_interface_bank","res://assets/vfx/extensions/followup-20261020/sources/b6d1c7425c55ede2770b/interface.tres")]

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D=VfxPackageIO_52f64c6e57.resource("res://assets/vfx/extensions/followup-20261020/sources/52f64c6e578eccf953f7/removal.gd").new()
	instance.parameters={"scene":"res://assets/vfx/conditions/condition_irresistible_dance_persistent/prepared.scn","geometry":["receiving/ReceivingForm0Layer0","receiving/ReceivingForm1Layer0","receiving/ReceivingForm2Layer0"],"emitters":[],"application_seconds":0.35,"removal_seconds":0.35,"loop_seconds":18.4799567858223,"sustain_gain":1.0,"adaptive_surface":{"kind":"forms","settings":{"height_cap_cells":0.45,"readable":false,"width_cap_cells":0.28},"prepared_pose_table":true},"phase":"removal","pose_interface_bank":"res://assets/vfx/extensions/followup-20261020/sources/b6d1c7425c55ede2770b/interface.tres"}
	instance.parameters.merge(input,true)
	return instance

const VfxPackageIO_52f64c6e57 = preload("res://assets/vfx/extensions/followup-20261020/scoped_resource_io.gd")
