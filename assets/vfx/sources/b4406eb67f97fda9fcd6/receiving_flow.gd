extends "res://assets/vfx/sources/4373fef56294eece4e7a/receiving_strands.gd"
## Original supported petals/strands. Pose support is cached; motion is GPU-only.
const OriginalFlow = preload("res://assets/vfx/sources/4373fef56294eece4e7a/receiving_strands.gd")
var support_cache: Dictionary = {}
var current_support: ImageTexture
var support_measurements := 0
var current_key: Array = []


static func make_component(input: Dictionary) -> Node3D:
	# Reuse the source's exact donor/uniform preparation and piece topology.
	var reference: Node3D = OriginalFlow.make_component(input)
	return from_native(reference,input)


static func from_native(reference: Node3D,input: Dictionary) -> Node3D:
	var component: Node3D = VfxPackageIO_b4406eb67f.resource("res://assets/vfx/sources/b4406eb67f97fda9fcd6/receiving_flow.gd").new()
	component.settings = input.duplicate(true)
	for index in reference.pieces.size():
		var piece: MeshInstance3D = reference.pieces[index]
		reference.remove_child(piece)
		component.add_child(piece)
		piece.mesh = component._template_mesh()
		piece.custom_aabb = AABB(Vector3(-4,-4,-4),Vector3(8,8,8))
		piece.material_override = reference.material.duplicate(true)
		component._prepare_material(piece.material_override,index)
		component.pieces.append(piece)
	component.material = component.pieces[0].material_override
	reference.free()
	return component


func _template_mesh() -> ArrayMesh:
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var petal: bool = settings.shape != "strands"
	var source_colour := Color.WHITE
	if petal:
		source_colour = Color.html(str(settings.colour)).srgb_to_linear()
		source_colour.a = float(settings.get("source_dissolve",.18))
	for fin in (1 if petal else 3):
		for station in 48:
			for column in (2 if petal else 1):
				var cells := [Vector2i(station,column),Vector2i(station+1,column),Vector2i(station,column+1),Vector2i(station,column+1),Vector2i(station+1,column),Vector2i(station+1,column+1)] if petal else [Vector2i(station,column),Vector2i(station,column+1),Vector2i(station+1,column),Vector2i(station,column+1),Vector2i(station+1,column+1),Vector2i(station+1,column)]
				for cell in cells:
					var edge := float(cell.y)-1.0 if petal else float(cell.y)*2.0-1.0
					surface_tool.set_uv(Vector2((edge+1.0)*.5,float(cell.x)/48.0))
					surface_tool.set_normal(Vector3.UP)
					surface_tool.set_color(source_colour)
					surface_tool.add_vertex(Vector3(cell.x,edge,fin))
	return surface_tool.commit()


func _prepare_material(value: ShaderMaterial, index: int) -> void:
	var code: String = value.shader.code
	var expression := RegEx.new()
	expression.compile("void\\s+vertex\\s*\\(\\s*\\)\\s*\\{")
	var vertex := expression.search(code)
	var include := VfxPackageIO_b4406eb67f.text("res://assets/vfx/sources/633d65f66f1d9af3a8ea/receiving_flow.gdshaderinc")
	if vertex == null:
		code += "\n"+include+"\nvoid vertex(){gpu_flow_deform(VERTEX,NORMAL,COLOR);}\n"
	else:
		code = code.insert(vertex.get_end(),"gpu_flow_deform(VERTEX,NORMAL,COLOR);")
		code = code.insert(vertex.get_start(),include+"\n")
	var shader := Shader.new()
	shader.code = code
	SourceMaterials.replace_shader(value,shader)
	value.set_shader_parameter("gpu_flow_curve",index)
	value.set_shader_parameter("gpu_flow_petal",settings.shape != "strands")
	value.set_shader_parameter("gpu_flow_phase",float(settings.curves[index].get("phase",0.0)))
	value.set_shader_parameter("gpu_flow_width",float(settings.curves[index].width_cells))


func sample(seconds: float) -> void:
	local_clock = seconds
	var lifetime := float(settings.seconds)
	envelope = smoothstep(0.0,.28,seconds)*(1.0-smoothstep(lifetime-.5,lifetime,seconds))
	for piece in pieces:
		piece.material_override.set_shader_parameter("body_flow_clock",seconds)
		piece.material_override.set_shader_parameter("body_flow_envelope",envelope)
	if envelope<=.0001 or surface.get("points",[]).is_empty():
		_hide()
	else:
		_fit_curves()


func _fit_curves() -> void:
	var key: Array = preload("res://assets/vfx/sources/9c05cee00f7d74560348/geometry_key.gd").from_surface(surface)
	if key.is_empty() or current_support == null or current_key != key:
		if not key.is_empty() and support_cache.has(key):
			current_support = support_cache[key].texture
			fit_side = support_cache[key].side
		else:
			if not _measure_frame():
				_hide()
				return
			var image := Image.create(13,pieces.size()*2,false,Image.FORMAT_RGBAF)
			for index in pieces.size():
				for station in 13:
					var control := _curve_value(settings.curves[index].controls,float(station)/12.0)
					var fit := _support(control.x*fit_half_width,control.y*fit_height)
					var point: Vector3 = fit.position-surface.origin+fit.normal*control.z
					var normal: Vector3 = fit.normal
					image.set_pixel(station,index*2,Color(point.x,point.y,point.z,1))
					image.set_pixel(station,index*2+1,Color(normal.x,normal.y,normal.z,1))
			current_support = ImageTexture.create_from_image(image)
			support_measurements += 1
			if not key.is_empty():
				# Bound per-occurrence pose caching; repeated existing idle poses
				# reuse their real supports rather than redoing nearest searches.
				if support_cache.size()>=64:
					support_cache.erase(support_cache.keys()[0])
				support_cache[key.duplicate(true)] = {"texture":current_support,"side":fit_side}
		current_key = key.duplicate(true)
		for piece in pieces:
			piece.material_override.set_shader_parameter("gpu_flow_support",current_support)
			piece.material_override.set_shader_parameter("gpu_flow_side",fit_side)
	fit_origin = surface.origin
	for piece in pieces:
		piece.global_transform = Transform3D(Basis.IDENTITY,fit_origin)
		piece.show()


func capture_observation() -> Dictionary:
	return {"receiving_flow":{"shape":settings.shape,"actor":surface.get("actor"),"clock":local_clock,
		"envelope":envelope,"curves":pieces.size(),"world_origin":fit_origin,"per_frame_mesh_rebuilds":0,
		"support_measurements":support_measurements,"cached_actual_poses":support_cache.size(),"lights":0,
		"remaining_cpu":"Actual new-pose support measurement; existing pose/translation/seek reuses cached support"}}

const VfxPackageIO_b4406eb67f = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
