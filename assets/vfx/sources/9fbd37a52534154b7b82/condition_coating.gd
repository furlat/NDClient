extends Node3D
## Selected native material on the actual item support. Owner/item admission
## and measured GPU geometry belong to the prepared occurrence, not a timer.
const WeaponMaterial = preload("res://assets/vfx/sources/642a744813f07bd93ffe/native_material.gd")
const Fire = preload("res://assets/vfx/sources/cb6c8716b8516ba846d5/native_fire.gd")
var material: ShaderMaterial


static func make_component(input: Dictionary) -> Node3D:
	var node: Node3D = VfxPackageIO_9fbd37a525.resource("res://assets/vfx/sources/9fbd37a52534154b7b82/condition_coating.gd").new()
	if input.material_kind == "native_fire":
		node.material = Fire.flame(float(input.gain), true, true)
		node.material.set_shader_parameter("fire_owner_alpha", 1.0)
	else:
		node.material = WeaponMaterial.make(input.material, "", "\nALPHA=clamp(ALPHA,0.0,1.0)*weapon_envelope*.62;\n")
		node.material.set_shader_parameter("weapon_envelope", 1.0)
	var draw := MeshInstance3D.new()
	draw.name = "CurrentItemCoating"
	draw.material_override = node.material
	draw.mesh = QuadMesh.new()
	draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(draw)
	return node


func sample(seconds: float) -> void:
	material.set_shader_parameter("weapon_clock", seconds)
	material.set_shader_parameter("fire_owner_seconds", seconds)

const VfxPackageIO_9fbd37a525 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
