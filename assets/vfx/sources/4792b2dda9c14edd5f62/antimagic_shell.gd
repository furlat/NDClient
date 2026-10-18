extends "res://assets/vfx/sources/a4fd0883f0b17d893a03/base.gd"
var material: ShaderMaterial


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/4792b2dda9c14edd5f62/antimagic_shell.gd", input)


func prepare_materials(_node: Node) -> void:
	pass


func apply_scene_edits(node: Node) -> void:
	var mesh = SphereMesh.new()
	mesh.radius = 2.
	mesh.height = 4.
	mesh.radial_segments = 96
	mesh.rings = 48
	var n = MeshInstance3D.new()
	n.mesh = mesh
	n.scale.y = .81649658
	node.add_child(n)
	material = ShaderMaterial.new()
	material.shader = VfxPackageIO_4792b2dda9.resource("res://assets/vfx/sources/fbb8f01e55a3231d7d95/antimagic.gdshader")
	material.set_shader_parameter(
		"authored_noise", ImageTexture.create_from_image(VfxPackageIO_4792b2dda9.image(parameters.noise))
	)
	material.set_shader_parameter("side", -1. if side == "back" else 1.)
	n.material_override = material


func advance_lifecycle(_d: float) -> void:
	tick += 1
	var frame = maxi(0, int(floor(float(tick - 1) * 32. / float(parameters.simulation_hz))))
	material.set_shader_parameter("clock", float(frame) / 64.)

const VfxPackageIO_4792b2dda9 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
