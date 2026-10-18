extends RefCounted
const Programs = preload("res://assets/vfx/sources/801b495c0bd760a8e358/directed_program.gd")
const Materials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
static var templates: Dictionary = {}

static func assign(draw: MeshInstance3D, points: Array[Vector3], radius: float, growth: float) -> void:
	var material: ShaderMaterial = draw.material_override
	if not material.has_meta("gpu_tube_atlas"):
		Programs.prepare(material,"contact_tube",false,"float tube_gate;gpu_tube_vertex(VERTEX,NORMAL,tube_gate);gpu_tube_gate=tube_gate;")
		var shader := Shader.new()
		shader.code = Materials.finish_fragment(material.shader.code,"\nALPHA*=gpu_tube_gate;\n")
		Materials.replace_shader(material,shader)
		var image := Image.create(64, 16, false, Image.FORMAT_RGBAF)
		var texture := ImageTexture.create_from_image(image)
		material.set_meta("gpu_tube_atlas",{"image":image,"texture":texture,"rows":0})
		material.set_shader_parameter("gpu_tube_points",texture)
	var atlas: Dictionary = material.get_meta("gpu_tube_atlas")
	if not draw.has_meta("gpu_tube_row"):
		assert(atlas.rows<16)
		draw.set_meta("gpu_tube_row",atlas.rows)
		draw.set_instance_shader_parameter("gpu_tube_row",atlas.rows)
		atlas.rows+=1
	assert(points.size()>=2 and points.size()<=64)
	if draw.get_meta("gpu_tube_count",0)!=points.size():
		draw.mesh=template(points.size())
		draw.set_meta("gpu_tube_count",points.size())
		draw.set_instance_shader_parameter("gpu_tube_count",points.size())
	draw.set_instance_shader_parameter("gpu_tube_growth",growth)
	draw.set_instance_shader_parameter("gpu_tube_radius",radius)
	var previous: Array = draw.get_meta("gpu_tube_points",[])
	if previous!=points:
		draw.set_meta("gpu_tube_points",points.duplicate())
		var row: int = draw.get_meta("gpu_tube_row")
		var bounds := AABB(points[0],Vector3.ZERO)
		for index in points.size():
			var point := points[index]
			atlas.image.set_pixel(index,row,Color(point.x,point.y,point.z,1.))
			bounds=bounds.expand(point)
		draw.custom_aabb=bounds.grow(radius+.001)
		atlas.texture.update(atlas.image)

static func template(count: int) -> ArrayMesh:
	if templates.has(count):return templates[count]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var corners := [Vector2i(0,0),Vector2i(0,1),Vector2i(1,1),Vector2i(0,0),Vector2i(1,1),Vector2i(1,0)]
	for index in count-1:
		for side in 7:
			for corner in 6:
				surface.set_normal(Vector3.UP)
				surface.set_uv(Vector2(float(side+corners[corner].y)/7.,float(index+corners[corner].x)/float(count-1)))
				surface.add_vertex(Vector3(index,corner,side))
	var mesh := surface.commit()
	templates[count]=mesh
	return mesh
