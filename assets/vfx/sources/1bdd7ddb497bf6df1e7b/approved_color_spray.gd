extends "res://assets/vfx/sources/8bc14eb2046d9d28c368/control_shell.gd"
## Approved density/noise revision; no legacy exporter or scene delegation.
static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/1bdd7ddb497bf6df1e7b/approved_color_spray.gd", input)

func apply_scene_edits(node: Node) -> void:
	super.apply_scene_edits(node)
	var layer := 0
	for sheet in node.find_children("*", "MeshInstance3D", true, false):
		var arrays: Array = sheet.mesh.surface_get_arrays(0)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var axis := Vector2(settings.axis[0], settings.axis[1])
		var root := Vector3(settings.root[0], settings.root[1], settings.root[2])
		for i in points.size():
			var u := uv[i].x
			var v := uv[i].y
			points[i] = Vector3(v*6.36396103*axis.x-(u-.5)*v*6.36396103*axis.y+root.x*(1.0-v), root.y*(1.0-v)+.15+sin(u*PI)*sin(v*PI)*float(layer)*.35, v*6.36396103*axis.y+(u-.5)*v*6.36396103*axis.x+root.z*(1.0-v))
		arrays[Mesh.ARRAY_VERTEX] = points
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var tool := SurfaceTool.new()
		tool.create_from(mesh, 0)
		tool.generate_normals()
		sheet.mesh = tool.commit()
		layer += 1
	for mat in mats:
		var shader := Shader.new()
		shader.code = mat.shader.code.replace("UV.x*2.0+layer*.22,UV.y*2.0-clock*1.2", "UV.x*4.0+layer*.22,UV.y*1.4-clock*1.6")
		shader.code = shader.code.replace("(.60*smoothstep(.20,.66,n)+.07*smoothstep(.35,.65,fine))", ".68*smoothstep(.28,.60,n)*smoothstep(.18,.42,fine)")
		# Near/far extraction owns the split. Historical halves share one instance.
		shader.code = shader.code.replace("if((front&&dep<0.0)||(!front&&dep>=0.0))discard;", "")
		mat.shader = shader
