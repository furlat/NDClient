extends "res://assets/vfx/sources/a27e1fb3208ae1c60763/prismatic_spray.gd"
const Programs=preload("res://assets/vfx/sources/801b495c0bd760a8e358/directed_program.gd")

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D=VfxPackageIO_85042a2091.resource("res://assets/vfx/sources/85042a209129af2bc7e9/prismatic_spray.gd").new()
	instance.settings=input.duplicate(true)
	instance.prepare()
	for index in instance.rays.size():instance._prepare_strip(instance.rays[index],index,25,0)
	for index in instance.contacts.size():instance._prepare_strip(instance.contacts[index],index,13,1)
	return instance

func _prepare_strip(draw: MeshInstance3D,index: int,count: int,kind: int) -> void:
	var material: ShaderMaterial=draw.material_override
	Programs.prepare(material,"prismatic_paths")
	material.set_shader_parameter("gpu_prism_kind",kind)
	material.set_shader_parameter("gpu_prism_index",index)
	material.set_shader_parameter("gpu_prism_count",count)
	var builder:=SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index_station in count-1:
		for corner in [Vector2i(index_station,0),Vector2i(index_station,1),Vector2i(index_station+1,1),Vector2i(index_station,0),Vector2i(index_station+1,1),Vector2i(index_station+1,0)]:
			builder.set_uv(Vector2(corner.y,float(corner.x)/float(count-1)))
			builder.add_vertex(Vector3(corner.x,float(corner.y)*2.-1.,0))
	draw.mesh=builder.commit()
	draw.custom_aabb=AABB(Vector3.ONE*-20.,Vector3.ONE*40.)

func _inputs(material: ShaderMaterial,source: Vector3,ground: Vector3,direction: Vector3,side: Vector3,inverse: Transform3D,reach: float,width: float) -> void:
	var key: Array=[source,ground,direction,side,inverse,reach,width]
	if material.get_meta("gpu_prism_inputs",[])==key:return
	material.set_meta("gpu_prism_inputs",key)
	material.set_shader_parameter("gpu_prism_source",source)
	material.set_shader_parameter("gpu_prism_ground",ground)
	material.set_shader_parameter("gpu_prism_direction",direction)
	material.set_shader_parameter("gpu_prism_side",side)
	material.set_shader_parameter("gpu_prism_inverse",inverse)
	material.set_shader_parameter("gpu_prism_length",float(settings.length_cells)*reach)
	material.set_shader_parameter("gpu_prism_width",width)

func _write_ray(index: int,source: Vector3,ground: Vector3,direction: Vector3,side: Vector3,inverse: Transform3D,reach: float) -> float:
	_inputs(ray_materials[index],source,ground,direction,side,inverse,reach,.045 if index%7==6 else .08+float(index%3)*.035)
	# Preserve the source's observation at its actual 25 stations, independently
	# of raster geometry. No mesh construction or vertex arrays are generated.
	var minimum:=INF
	for step in 25:
		var along:=float(step)/24.
		minimum=minf(minimum,lerpf(source.y,ground.y+.16+float(index%3)*.32,along)+sin(along*PI)*float(index%3)*.22)
	return minimum

func _write_contact(next: int,recipient: Vector3,direction: Vector3,side: Vector3,inverse: Transform3D,color: int) -> void:
	_inputs(contact_materials[next],recipient,recipient,direction,side,inverse,1.,.065 if color==7 else .10)

const VfxPackageIO_85042a2091 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
