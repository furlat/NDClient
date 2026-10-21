extends "res://assets/vfx/extensions/spike-seed-20261021/sources/13c22cca5a622218385f/spike_growth_relief.gd"
## Round bark-bearing hooks replace the original per-quad constant UV strips.
## Native seeded layout, donor vine, footprint and lifecycle remain unchanged.
const TaperedTube = preload("res://assets/vfx/sources/3f0e256c0dfb8bef8d73/tapered_tube.gd")


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/extensions/spike-seed-20261021/sources/21d9b70cf2bfd288b0ba/spike_growth_bark_mass.gd", input)


func tube(points: Array[Vector3], radii: Array[float], mat: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.mesh = TaperedTube.build(points,radii)
	mesh.material_override = mat
	return mesh


func wood() -> ShaderMaterial:
	var result: ShaderMaterial = super.wood()
	var shader := Shader.new()
	shader.code = result.shader.code.replace("norm=NORMAL;", "norm=normalize(MODEL_NORMAL_MATRIX*NORMAL);")
	SourceMaterials.replace_shader(result,shader)
	return result
