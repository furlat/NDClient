extends "res://assets/vfx/extensions/owner-fields-v2-20261021/sources/06b214e81043f90468de/gust_registration.gd"
## Keep the native travelling fronts and three connected wind strands. Source
## noise controls soft coverage; rolled geometry supplies its actual normals.
const AirMaterials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/extensions/owner-fields-v2-20261021/sources/bccb9b827ea1205577dd/gust_airy_strands.gd", input)


func material(base: ShaderMaterial, strength: float, phase: float) -> ShaderMaterial:
	var source := super.material(base, strength, phase)
	if phase <= 0.0:
		return source
	var code: String = source.shader.code
	var old := "step(n_out4p4, n_out92p0)"
	assert(code.contains(old), "Gust donor's source noise threshold changed")
	code = code.replace(old, "smoothstep(.08,.68,n_out92p0)")
	code = AirMaterials.finish_fragment(code, "\nALPHA*=smoothstep(0.0,.16,UV.x)*(1.-smoothstep(.84,1.0,UV.x));\n")
	var shader := Shader.new()
	shader.code = code
	AirMaterials.replace_shader(source, shader)
	return source


func ribbon_mesh(which: int, reach: float, time: float) -> ArrayMesh:
	var source := super.ribbon_mesh(which, reach, time)
	var arrays := source.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals := PackedVector3Array()
	var tangents := PackedFloat32Array()
	for ring in 65:
		var previous: int = maxi(0, ring-1)*2
		var following: int = mini(64, ring+1)*2
		var tangent := ((vertices[following]+vertices[following+1])-(vertices[previous]+vertices[previous+1])).normalized()
		var across := (vertices[ring*2+1]-vertices[ring*2]).normalized()
		if across.is_zero_approx():
			across = Vector3.RIGHT
		var normal := across.cross(tangent).normalized()
		if normal.is_zero_approx():
			normal = Vector3.UP
		for side in 2:
			normals.append(normal)
			tangents.append_array(PackedFloat32Array([across.x, across.y, across.z, 1.0]))
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TANGENT] = tangents
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
