extends "res://assets/vfx/extensions/followup-20261020/sources/d9eb87da8c2b85a8c2dd/condition_pose_occurrence.gd"

static func preparation_resources(input: Dictionary) -> Array:
	return [input.get("pose_interface_bank","res://assets/vfx/extensions/followup-20261020/sources/ec5fb7f519cfd2094db1/interface.tres")]

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D=VfxPackageIO_82ec396c6a.resource("res://assets/vfx/extensions/followup-20261020/sources/82ec396c6a473dff3d83/application.gd").new()
	instance.parameters={"scene":"res://assets/vfx/conditions/condition_aura_of_life_benefit_persistent/prepared.scn","geometry":["support/FactoryGenerated_0000_MeshInstance3D","support/FactoryGenerated_0001_MeshInstance3D","support/FactoryGenerated_0002_MeshInstance3D","support/FactoryGenerated_0003_MeshInstance3D"],"emitters":[],"application_seconds":0.35,"removal_seconds":0.35,"loop_seconds":62.8318530717959,"sustain_gain":1.0,"adaptive_surface":{"kind":"support","settings":{"readable":false},"prepared_pose_table":true},"phase":"application","pose_interface_bank":"res://assets/vfx/extensions/followup-20261020/sources/ec5fb7f519cfd2094db1/interface.tres"}
	instance.parameters.merge(input,true)
	return instance

const VfxPackageIO_82ec396c6a = preload("res://assets/vfx/extensions/followup-20261020/scoped_resource_io.gd")
