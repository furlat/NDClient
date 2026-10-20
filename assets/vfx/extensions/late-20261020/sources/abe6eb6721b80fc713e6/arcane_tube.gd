extends RefCounted
const Programs=preload("res://assets/vfx/sources/801b495c0bd760a8e358/directed_program.gd")
static var templates: Dictionary={}
static func assign(draw: MeshInstance3D, points: Array[Vector3], widths: Array[float], sides: int = 8) -> void:
	assert(points.size() == widths.size() and points.size() >= 2)
	var material: ShaderMaterial = draw.material_override
	if not material.has_meta("gpu_arcane_atlas"):
		Programs.prepare(material, "arcane_tube")
		var image := Image.create(64, 32, false, Image.FORMAT_RGBAF)
		var texture := ImageTexture.create_from_image(image)
		material.set_meta("gpu_arcane_atlas", {"image":image, "texture":texture, "rows":0})
		material.set_shader_parameter("gpu_arcane_points", texture)
	var atlas: Dictionary = material.get_meta("gpu_arcane_atlas")
	if not draw.has_meta("gpu_arcane_row"):
		assert(atlas.rows < atlas.image.get_height(), "Current material exceeded its explicitly bounded 32 path instances")
		draw.set_meta("gpu_arcane_row", atlas.rows)
		draw.set_instance_shader_parameter("gpu_arcane_row", atlas.rows)
		atlas.rows += 1
	assert(points.size() <= atlas.image.get_width(), "Path exceeds the current 64-station source family")
	if int(draw.get_meta("gpu_arcane_count",0))!=points.size() or int(draw.get_meta("gpu_arcane_sides",0))!=sides:
		draw.set_meta("gpu_arcane_count",points.size())
		draw.set_meta("gpu_arcane_sides",sides)
		draw.mesh=template(points.size(),sides)
		draw.set_instance_shader_parameter("gpu_arcane_count",points.size())
		draw.set_instance_shader_parameter("gpu_arcane_sides",sides)
	var previous: Array = draw.get_meta("gpu_arcane_data", [])
	if previous.size() == 2 and previous[0] == points and previous[1] == widths:
		return
	draw.set_meta("gpu_arcane_data", [points.duplicate(), widths.duplicate()])
	var row: int = draw.get_meta("gpu_arcane_row")
	var bounds := AABB(points[0], Vector3.ZERO)
	var maximum_width := 0.
	for index in points.size():
		var point := points[index]
		atlas.image.set_pixel(index, row, Color(point.x, point.y, point.z, widths[index]))
		bounds = bounds.expand(point)
		maximum_width = maxf(maximum_width, widths[index])
	draw.custom_aabb = bounds.grow(maximum_width + .001)
	atlas.texture.update(atlas.image)

static func template(count: int,sides: int) -> ArrayMesh:
	var key: Array=[count,sides]
	if templates.has(key):return templates[key]
	var vertices:=PackedVector3Array()
	var normals:=PackedVector3Array()
	var uv:=PackedVector2Array()
	var indices:=PackedInt32Array()
	for station in count:
		for ring in sides+1:
			vertices.append(Vector3(station,ring,0))
			normals.append(Vector3.UP)
			uv.append(Vector2(.82+float(ring)/float(sides)*.16,float(station)/float(count-1)*2.))
			if station>0 and ring<sides:
				var first: int=(station-1)*(sides+1)+ring
				indices.append_array(PackedInt32Array([first,first+1,first+sides+1,first+1,first+sides+2,first+sides+1]))
	var arrays:=[]
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices
	arrays[Mesh.ARRAY_NORMAL]=normals
	arrays[Mesh.ARRAY_TEX_UV]=uv
	arrays[Mesh.ARRAY_INDEX]=indices
	var mesh:=ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	templates[key]=mesh
	return mesh
