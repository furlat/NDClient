extends "res://assets/vfx/sources/a4fd0883f0b17d893a03/base.gd"


## Three native expanding solar shells; age and depth partition are explicit inputs.
static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/22c58ef325ab4e207bc2/sunburst.gd", input)


func prepare_materials(_node: Node) -> void:
	pass


func apply_scene_edits(node: Node) -> void:
	node.scale.y = .81649658
	var shader = VfxPackageIO_22c58ef325.resource("res://assets/vfx/sources/203bd56a6814b20140aa/sunburst.gdshader")
	for layer in range(3):
		var mesh = SphereMesh.new()
		mesh.radius = 1.
		mesh.height = 2.
		mesh.radial_segments = 96
		mesh.rings = 48
		var surface = MeshInstance3D.new()
		surface.mesh = mesh
		node.add_child(surface)
		var material = ShaderMaterial.new()
		material.shader = shader
		(
			material
			. set_shader_parameter(
				"noise_tex",
				VfxPackageIO_22c58ef325.resource(
					"res://assets/vfx/sources/79ea8307f7adab9ec44f/texture.res"
				)
			)
		)
		(
			material
			. set_shader_parameter(
				"detail_tex",
				VfxPackageIO_22c58ef325.resource(
					"res://assets/vfx/sources/5b0a18fdc09c1fcdd677/texture.res"
				)
			)
		)
		material.set_shader_parameter("layer", float(layer))
		material.set_shader_parameter("side", -1. if side == "back" else 1.)
		surface.material_override = material
		materials.append(material)


func advance_lifecycle(_delta: float) -> void:
	tick += 1
	var age = float(tick - 1) / float(parameters.simulation_hz)
	for material in materials:
		material.set_shader_parameter("age", age)

const VfxPackageIO_22c58ef325 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
