extends "res://assets/vfx/sources/1bdd7ddb497bf6df1e7b/approved_color_spray.gd"
const Programs=preload("res://assets/vfx/sources/801b495c0bd760a8e358/directed_program.gd")
var endpoints: Array=[]
var sheets: Array[MeshInstance3D]=[]

static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/ec591a5b9c4c194952ab/color_spray.gd",input)

func set_live_endpoints(value: Array) -> void:endpoints=value

func apply_scene_edits(node: Node) -> void:
	super.apply_scene_edits(node)
	for sheet in node.find_children("*","MeshInstance3D",true,false):
		var arrays: Array=sheet.mesh.surface_get_arrays(0)
		var uv: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
		assert(arrays[Mesh.ARRAY_INDEX]==null,"The accepted prism source has explicit flat triangles")
		var builder:=SurfaceTool.new()
		builder.begin(Mesh.PRIMITIVE_TRIANGLES)
		builder.set_custom_format(0,SurfaceTool.CUSTOM_RGBA_FLOAT)
		for index in uv.size():
			var triangle: int=(index/3)*3
			var b: Vector2=uv[triangle+(index+1)%3]
			var c: Vector2=uv[triangle+(index+2)%3]
			builder.set_uv(uv[index])
			builder.set_normal(arrays[Mesh.ARRAY_NORMAL][index])
			builder.set_custom(0,Color(b.x,b.y,c.x,c.y))
			builder.add_vertex(Vector3(uv[index].x,uv[index].y,sheets.size()))
		sheet.mesh=builder.commit()
		sheet.custom_aabb=AABB(Vector3.ONE*-10.,Vector3.ONE*20.)
		sheets.append(sheet)
		Programs.prepare(sheet.material_override,"color_spray",false,"gpu_color_vertex(VERTEX,NORMAL,UV,CUSTOM0);")

func sample(seconds: float) -> void:
	super.sample(seconds)
	if endpoints.size()<3:return
	var inverse:=subject.global_transform.affine_inverse()
	var caster: Vector3=inverse*endpoints[0].point
	var hand: Vector3=inverse*endpoints[1].point
	var target: Vector3=inverse*endpoints[2].point
	var direction:=Vector3(target.x-caster.x,0.,target.z-caster.z).normalized()
	if direction.is_zero_approx():return
	var across:=Vector3(-direction.z,0.,direction.x)
	for sheet in sheets:
		var material: ShaderMaterial=sheet.material_override
		var key: Array=[caster,hand,direction,across]
		if material.get_meta("gpu_color_inputs",[])==key:continue
		material.set_meta("gpu_color_inputs",key)
		material.set_shader_parameter("gpu_color_caster",caster)
		material.set_shader_parameter("gpu_color_hand",hand)
		material.set_shader_parameter("gpu_color_direction",direction)
		material.set_shader_parameter("gpu_color_across",across)
		material.set_shader_parameter("gpu_color_range",float(settings.range_cells))
		# Transparent order uses the actual source AABB centre. Oversized common
		# bounds changed the three sheets' blend order despite identical vertices.
		var bounds:=AABB(hand,Vector3.ZERO)
		var layer_index: int=sheets.find(sheet)
		for row in 25:
			for column in 17:
				var u:=float(column)/16.
				var v:=float(row)/24.
				var point: Vector3=caster+direction*v*float(settings.range_cells)+across*(u-.5)*v*float(settings.range_cells)+(hand-caster)*(1.-v)
				point.y+=sin(u*PI)*sin(v*PI)*float(layer_index)*.165
				bounds=bounds.expand(point)
		sheet.custom_aabb=bounds
