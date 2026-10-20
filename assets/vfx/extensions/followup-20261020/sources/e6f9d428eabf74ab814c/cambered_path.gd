extends RefCounted
## Stable three-fin source geometry. Only current 3D stations/widths change;
## no CPU triangle generation or new mesh resources during animation.
const Programs = preload("res://assets/vfx/extensions/followup-20261020/sources/801b495c0bd760a8e358/directed_program.gd")
static var templates: Dictionary = {}

static func assign(draw: MeshInstance3D,path: Dictionary,origin: Vector3,fallback: Vector3,colour: Color,uv_bounds: Vector2=Vector2(0,1)) -> void:
	var material: ShaderMaterial=draw.material_override
	if not material.has_meta("gpu_cambered_atlas"):
		Programs.prepare(material,"cambered_path")
		var image:=Image.create(64,64,false,Image.FORMAT_RGBAF)
		var texture:=ImageTexture.create_from_image(image)
		material.set_meta("gpu_cambered_atlas",{"image":image,"texture":texture,"rows":0})
		material.set_shader_parameter("gpu_cambered_points",texture)
	var atlas: Dictionary=material.get_meta("gpu_cambered_atlas")
	if not draw.has_meta("gpu_cambered_row"):
		assert(atlas.rows<32)
		draw.set_meta("gpu_cambered_row",atlas.rows)
		draw.set_instance_shader_parameter("gpu_cambered_row",atlas.rows)
		atlas.rows+=1
	var count: int=path.points.size()
	assert(count>=3 and count<=64)
	if draw.get_meta("gpu_cambered_shape",[])!=[count,colour,uv_bounds]:
		draw.mesh=template(count,colour,uv_bounds)
		draw.set_instance_shader_parameter("gpu_cambered_count",count)
		draw.set_meta("gpu_cambered_shape",[count,colour,uv_bounds])
	material.set_shader_parameter("gpu_cambered_fallback",fallback)
	var data: Array=[path.points,path.normals,path.width,origin]
	if draw.get_meta("gpu_cambered_data",[])==data:
		return
	draw.set_meta("gpu_cambered_data",data.duplicate(true))
	var row: int=draw.get_meta("gpu_cambered_row")
	var bounds:=AABB(path.points[0]-origin,Vector3.ZERO)
	for index in count:
		var point: Vector3=path.points[index]-origin
		var normal: Vector3=path.normals[index]
		atlas.image.set_pixel(index,row*2,Color(point.x,point.y,point.z,path.width))
		atlas.image.set_pixel(index,row*2+1,Color(normal.x,normal.y,normal.z,1.))
		bounds=bounds.expand(point)
	draw.custom_aabb=bounds.grow(float(path.width)*1.2+.001)
	atlas.texture.update(atlas.image)

static func template(count: int, colour: Color = Color.WHITE,uv_bounds: Vector2=Vector2(0,1)) -> ArrayMesh:
	var key: Array = [count, colour,uv_bounds]
	if templates.has(key):
		return templates[key]
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var coordinates := PackedVector2Array()
	var colours := PackedColorArray()
	var indices := PackedInt32Array()
	for index in count:
		for column in 5:
			var fraction:=float(column)/4.
			vertices.append(Vector3(index,fraction*2.-1.,0))
			normals.append(Vector3.UP)
			colours.append(colour)
			coordinates.append(Vector2(fraction,lerpf(uv_bounds.x,uv_bounds.y,float(index)/float(count-1))))
			if index>0 and column>0:
				var first: int=(index-1)*5+column-1
				indices.append_array(PackedInt32Array([first,first+1,first+5,first+1,first+6,first+5]))
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
