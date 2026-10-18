extends RefCounted
## Stable three-fin source geometry. Only current 3D stations/widths change;
## no CPU triangle generation or new mesh resources during animation.
const Programs = preload("res://assets/vfx/sources/801b495c0bd760a8e358/directed_program.gd")
static var templates: Dictionary = {}

static func assign(draw: MeshInstance3D, points: Array[Vector3], widths: Array[float], colour: Color = Color.WHITE, uv_bounds: Vector2 = Vector2(0, 1), uv_swap: bool = false) -> void:
	assert(points.size() == widths.size() and points.size() >= 2)
	var material: ShaderMaterial = draw.material_override
	if not material.has_meta("gpu_path_atlas"):
		Programs.prepare(material, "path_ribbon")
		var image := Image.create(64, 32, false, Image.FORMAT_RGBAF)
		var texture := ImageTexture.create_from_image(image)
		material.set_meta("gpu_path_atlas", {"image":image, "texture":texture, "rows":0})
		material.set_shader_parameter("gpu_path_points", texture)
	var atlas: Dictionary = material.get_meta("gpu_path_atlas")
	if not draw.has_meta("gpu_path_row"):
		assert(atlas.rows < atlas.image.get_height(), "Current material exceeded its explicitly bounded 32 path instances")
		draw.set_meta("gpu_path_row", atlas.rows)
		draw.set_instance_shader_parameter("gpu_path_row", atlas.rows)
		atlas.rows += 1
	assert(points.size() <= atlas.image.get_width(), "Path exceeds the current 64-station source family")
	if int(draw.get_meta("gpu_path_count", 0)) != points.size() or draw.get_meta("gpu_path_colour", Color.WHITE) != colour or draw.get_meta("gpu_path_uv", Vector2(0, 1)) != uv_bounds or draw.get_meta("gpu_path_uv_swap",false)!=uv_swap:
		draw.set_meta("gpu_path_count", points.size())
		draw.mesh = template(points.size(), colour, uv_bounds,uv_swap)
		draw.set_meta("gpu_path_uv_swap",uv_swap)
		draw.set_meta("gpu_path_uv", uv_bounds)
		draw.set_meta("gpu_path_colour", colour)
		draw.set_instance_shader_parameter("gpu_path_count", points.size())
	var previous: Array = draw.get_meta("gpu_path_data", [])
	if previous.size() == 2 and previous[0] == points and previous[1] == widths:
		return
	draw.set_meta("gpu_path_data", [points.duplicate(), widths.duplicate()])
	var row: int = draw.get_meta("gpu_path_row")
	var bounds := AABB(points[0], Vector3.ZERO)
	var maximum_width := 0.
	for index in points.size():
		var point := points[index]
		atlas.image.set_pixel(index, row, Color(point.x, point.y, point.z, widths[index]))
		bounds = bounds.expand(point)
		maximum_width = maxf(maximum_width, widths[index])
	draw.custom_aabb = bounds.grow(maximum_width + .001)
	atlas.texture.update(atlas.image)

static func template(count: int, colour: Color = Color.WHITE, uv_bounds: Vector2 = Vector2(0, 1), uv_swap: bool = false) -> ArrayMesh:
	var key: Array = [count, colour, uv_bounds,uv_swap]
	if templates.has(key):
		return templates[key]
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var coordinates := PackedVector2Array()
	var colours := PackedColorArray()
	var indices := PackedInt32Array()
	for fin in 3:
		var offset := vertices.size()
		for index in count:
			for edge in [-1., 1.]:
				vertices.append(Vector3(index, edge, fin))
				normals.append(Vector3.UP)
				colours.append(colour)
				var uv:=Vector2((edge+1.)*.5,lerpf(uv_bounds.x,uv_bounds.y,float(index)/float(count-1)))
				coordinates.append(Vector2(uv.y,uv.x) if uv_swap else uv)
			if index > 0:
				var first := offset + (index - 1) * 2
				indices.append_array(PackedInt32Array([first, first + 1, first + 2, first + 1, first + 3, first + 2]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = coordinates
	arrays[Mesh.ARRAY_COLOR] = colours
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	templates[key] = mesh
	return mesh
