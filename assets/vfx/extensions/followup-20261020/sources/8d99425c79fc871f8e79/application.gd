extends "res://assets/vfx/extensions/followup-20261020/sources/d9eb87da8c2b85a8c2dd/condition_pose_occurrence.gd"

static func preparation_resources(input: Dictionary) -> Array:
	return [input.get("pose_interface_bank","res://assets/vfx/extensions/followup-20261020/sources/7e7baf8607e1b5b0ae57/interface.tres")]

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D=VfxPackageIO_8d99425c79.resource("res://assets/vfx/extensions/followup-20261020/sources/8d99425c79fc871f8e79/application.gd").new()
	instance.parameters={"scene":"res://assets/vfx/conditions/condition_divine_sense_persistent/prepared.scn","geometry":["divine_art/FactoryGenerated_0000_MeshInstance3D","divine_art/FactoryGenerated_0001_MeshInstance3D","divine_art/FactoryGenerated_0002_MeshInstance3D","divine_art/FactoryGenerated_0003_MeshInstance3D","divine_art/FactoryGenerated_0004_MeshInstance3D","divine_art/FactoryGenerated_0005_MeshInstance3D","divine_art/FactoryGenerated_0006_MeshInstance3D","divine_art/FactoryGenerated_0007_MeshInstance3D"],"emitters":[],"application_seconds":0.35,"removal_seconds":0.35,"loop_seconds":2.0,"sustain_gain":1.0,"adaptive_surface":{"kind":"support","settings":{},"prepared_pose_table":true},"phase":"application","pose_interface_bank":"res://assets/vfx/extensions/followup-20261020/sources/7e7baf8607e1b5b0ae57/interface.tres"}
	instance.parameters.merge(input,true)
	return instance

const VfxPackageIO_8d99425c79 = preload("res://assets/vfx/extensions/followup-20261020/scoped_resource_io.gd")
