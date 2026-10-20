extends "res://assets/vfx/extensions/followup-20261020/sources/d9eb87da8c2b85a8c2dd/condition_pose_occurrence.gd"

static func preparation_resources(input: Dictionary) -> Array:
	return [input.get("pose_interface_bank","res://assets/vfx/extensions/followup-20261020/sources/7ccc2ac09caac83cbd73/interface.tres")]

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D=VfxPackageIO_034e7f2805.resource("res://assets/vfx/extensions/followup-20261020/sources/034e7f280562d41a574e/sustain.gd").new()
	instance.parameters={"scene":"res://assets/vfx/conditions/condition_paladin_aura_protection_persistent/prepared.scn","geometry":["divine_art/FactoryGenerated_0000_MeshInstance3D","divine_art/FactoryGenerated_0001_MeshInstance3D","divine_art/FactoryGenerated_0002_MeshInstance3D","divine_art/FactoryGenerated_0003_MeshInstance3D","divine_art/FactoryGenerated_0004_MeshInstance3D","divine_art/FactoryGenerated_0005_MeshInstance3D","divine_art/FactoryGenerated_0006_MeshInstance3D","divine_art/FactoryGenerated_0007_MeshInstance3D"],"emitters":[],"application_seconds":0.35,"removal_seconds":0.35,"loop_seconds":2.0,"sustain_gain":1.0,"adaptive_surface":{"kind":"support","settings":{},"prepared_pose_table":true},"phase":"sustain","pose_interface_bank":"res://assets/vfx/extensions/followup-20261020/sources/7ccc2ac09caac83cbd73/interface.tres"}
	instance.parameters.merge(input,true)
	return instance

const VfxPackageIO_034e7f2805 = preload("res://assets/vfx/extensions/followup-20261020/scoped_resource_io.gd")
