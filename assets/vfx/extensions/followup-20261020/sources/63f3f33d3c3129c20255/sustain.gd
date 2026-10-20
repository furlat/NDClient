extends "res://assets/vfx/extensions/followup-20261020/sources/d9eb87da8c2b85a8c2dd/condition_pose_occurrence.gd"

static func preparation_resources(input: Dictionary) -> Array:
	return [input.get("pose_interface_bank","res://assets/vfx/extensions/followup-20261020/sources/fc70c3c0510f3d3651de/interface.tres")]

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D=VfxPackageIO_63f3f33d3c.resource("res://assets/vfx/extensions/followup-20261020/sources/63f3f33d3c3129c20255/sustain.gd").new()
	instance.parameters={"scene":"res://assets/vfx/conditions/condition_aegis_spark_persistent/prepared.scn","geometry":["effect/OriginalCompactShieldPanel"],"emitters":[],"application_seconds":0.24,"removal_seconds":0.2,"loop_seconds":4.0,"sustain_gain":1.0,"adaptive_surface":{"kind":"forms","settings":{"fraction_max":0.88,"fraction_min":0.46,"geometry_slots":["body","chest","cloak"],"height_cap_cells":0.2,"readable":false,"width_cap_cells":0.16},"prepared_pose_table":true},"phase":"sustain","pose_interface_bank":"res://assets/vfx/extensions/followup-20261020/sources/fc70c3c0510f3d3651de/interface.tres"}
	instance.parameters.merge(input,true)
	return instance

const VfxPackageIO_63f3f33d3c = preload("res://assets/vfx/extensions/followup-20261020/scoped_resource_io.gd")
