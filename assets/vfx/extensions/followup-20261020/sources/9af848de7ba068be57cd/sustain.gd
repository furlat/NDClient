extends "res://assets/vfx/extensions/followup-20261020/sources/d9eb87da8c2b85a8c2dd/condition_pose_occurrence.gd"

static func preparation_resources(input: Dictionary) -> Array:
	return [input.get("pose_interface_bank","res://assets/vfx/extensions/followup-20261020/sources/a99f507d280fd38559f1/interface.tres")]

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D=VfxPackageIO_9af848de7b.resource("res://assets/vfx/extensions/followup-20261020/sources/9af848de7ba068be57cd/sustain.gd").new()
	instance.parameters={"scene":"res://assets/vfx/conditions/condition_foresight_persistent/prepared.scn","geometry":["support/FactoryGenerated_0000_MeshInstance3D","support/FactoryGenerated_0001_MeshInstance3D","support/FactoryGenerated_0002_MeshInstance3D","support/FactoryGenerated_0003_MeshInstance3D","support/FactoryGenerated_0004_MeshInstance3D"],"emitters":[],"application_seconds":0.35,"removal_seconds":0.35,"loop_seconds":62.8318530717959,"sustain_gain":1.0,"adaptive_surface":{"kind":"support","settings":{"readable":false},"prepared_pose_table":true},"phase":"sustain","pose_interface_bank":"res://assets/vfx/extensions/followup-20261020/sources/a99f507d280fd38559f1/interface.tres"}
	instance.parameters.merge(input,true)
	return instance

const VfxPackageIO_9af848de7b = preload("res://assets/vfx/extensions/followup-20261020/scoped_resource_io.gd")
