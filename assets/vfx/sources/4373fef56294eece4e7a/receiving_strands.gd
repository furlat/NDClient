extends Node3D
## Open spatial curves fitted to measured receiving support. No actor surface
## stencil, enclosing shell, camera-facing card, gameplay or external light.
const SourceMaterials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
const Values = preload("res://assets/vfx/sources/601eb8db9c55b6ad084e/shader_material.gd")
const PathRibbon = preload("res://assets/vfx/sources/31348bd589e2d41ae443/path_ribbon.gd")
var settings: Dictionary = {}
var surface: Dictionary = {}
var material: ShaderMaterial
var pieces: Array[MeshInstance3D] = []
var paths: Array = []
var local_clock := 0.0
var envelope := 0.0
var measured: Array = []
var fit_origin := Vector3.ZERO
var fit_centre := Vector3.ZERO
var fit_side := Vector3.RIGHT
var fit_height := 0.0
var fit_half_width := .1

static func make_component(input: Dictionary) -> Node3D:
	var component: Node3D = VfxPackageIO_4373fef562.resource("res://assets/vfx/sources/4373fef56294eece4e7a/receiving_strands.gd").new()
	component.settings = input.duplicate(true)
	var scene: PackedScene = VfxPackageIO_4373fef562.resource(input.material_scene)
	var donor: Node3D = scene.instantiate()
	var original: ShaderMaterial = donor.get_node(input.material_node).material_override
	component.material = original.duplicate(true)
	var code: String = original.shader.code.replace("TIME", "body_flow_clock")
	assert(not code.contains("ALPHA_SCISSOR_THRESHOLD"), "Spatial strands require real smooth alpha, not scissor coverage")
	assert(not code.contains("MODELVIEW_MATRIX ="), "Selected source must retain true spatial vertices")
	code = code.replace("shader_type spatial;", "shader_type spatial;\nuniform float body_flow_clock=0.0;\nuniform float body_flow_envelope=0.0;\n")
	code = SourceMaterials.stable_proximity(code)
	code = SourceMaterials.finish_fragment(code,"\nALPHA*=body_flow_envelope*"+str(float(input.get("alpha_gain",.7)))+";\n")
	var shader := Shader.new()
	shader.code = code
	SourceMaterials.replace_shader(component.material,shader)
	for parameter in input.get("uniforms",{}):
		component.material.set_shader_parameter(parameter,Values.uniform_value(input.uniforms[parameter]))
	component.material.render_priority = 0
	for definition in input.curves:
		var piece := MeshInstance3D.new()
		piece.name = "ReceivingFlow"+str(component.pieces.size())
		# Measured points arrive before attachment placement, including while
		# paused. Own world alignment so parent movement is never applied twice.
		piece.top_level = true
		piece.mesh = ArrayMesh.new()
		piece.material_override = component.material
		piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		piece.hide()
		component.add_child(piece)
		component.pieces.append(piece)
	donor.free()
	return component

func set_entity_geometry(value: Dictionary) -> void:
	surface = value
	if surface.get("points",[]).is_empty():
		_hide()
	elif envelope > .0001:
		_fit_curves()

func sample(seconds: float) -> void:
	local_clock = seconds
	var lifetime := float(settings.seconds)
	envelope = smoothstep(0.0,.28,seconds)*(1.0-smoothstep(lifetime-.5,lifetime,seconds))
	material.set_shader_parameter("body_flow_clock",seconds)
	material.set_shader_parameter("body_flow_envelope",envelope)
	if envelope <= .0001 or surface.get("points",[]).is_empty():
		_hide()
	else:
		_fit_curves()

func _hide() -> void:
	for piece in pieces: piece.hide()

func _measure_frame() -> bool:
	measured.clear()
	fit_origin = surface.origin
	fit_height = 0.0
	for point in surface.points:
		fit_height = maxf(fit_height,point.position.y-fit_origin.y)
	if fit_height < .1: return false
	var average_normal := Vector3.ZERO
	fit_centre = Vector3.ZERO
	for point in surface.points:
		var h: float = (point.position.y-fit_origin.y)/fit_height
		if not ["body","chest","belt","cloak"].has(point.slot) or h < .4 or h > .87: continue
		measured.append(point)
		fit_centre += point.position
		average_normal += point.normal
	if measured.size() < 8: return false
	fit_centre /= float(measured.size())
	var outward := Vector3(average_normal.x,0,average_normal.z).normalized()
	if outward.is_zero_approx(): outward=Vector3.FORWARD
	fit_side = Vector3.UP.cross(outward).normalized()
	fit_half_width = .04
	for point in measured:
		fit_half_width = maxf(fit_half_width,absf((point.position-fit_centre).dot(fit_side)))
	# The actual current support, not an arbitrary sphere radius or screen UV.
	for index in measured.size():
		var point: Dictionary = measured[index].duplicate()
		point.across = (point.position-fit_centre).dot(fit_side)
		point.height = point.position.y-fit_origin.y
		measured[index] = point
	return true

func _support(across: float,height: float) -> Dictionary:
	var closest := []
	for point in measured:
		var distance: float = pow(point.across-across,2)+pow(point.height-height,2)
		if closest.size() < 4 or distance < closest.back().distance:
			closest.append({"point":point,"distance":distance})
			closest.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return a.distance<b.distance)
			if closest.size()>4:closest.pop_back()
	var position := Vector3.ZERO
	var normal := Vector3.ZERO
	var weight := 0.0
	for entry in closest:
		var w := 1.0/(float(entry.distance)+.00015)
		position += entry.point.position*w
		normal += entry.point.normal*w
		weight += w
	return {"position":position/weight,"normal":normal.normalized()}

func _curve_value(controls: Array,u: float) -> Vector3:
	var at: float = u*float(controls.size()-1)
	var index: int = mini(int(at),controls.size()-2)
	var a: Array=controls[maxi(index-1,0)]
	var b: Array=controls[index]
	var c: Array=controls[index+1]
	var d: Array=controls[mini(index+2,controls.size()-1)]
	return Vector3(b[0],b[1],b[2]).cubic_interpolate(Vector3(c[0],c[1],c[2]),Vector3(a[0],a[1],a[2]),Vector3(d[0],d[1],d[2]),at-float(index))

func _fit_curves() -> void:
	if not _measure_frame():
		_hide()
		return
	paths.clear()
	for index in pieces.size():
		var definition: Dictionary = settings.curves[index]
		var supported := []
		var phase := float(definition.get("phase",0.0))
		# Twelve receiving samples support a smooth 49-station spatial curve.
		for station in 13:
			var u := float(station)/12.0
			var control := _curve_value(definition.controls,u)
			var fit := _support(control.x*fit_half_width,control.y*fit_height)
			var movement := sin(local_clock*1.65+u*TAU+phase)
			var normal: Vector3 = fit.normal
			var position: Vector3 = fit.position + normal*(control.z+.015*movement)
			position += fit_side*(sin(local_clock*1.15+u*PI+phase)*.012)
			supported.append({"position":position-fit_origin,"normal":normal})
		var points: Array[Vector3] = []
		var widths: Array[float] = []
		var normals: Array[Vector3] = []
		for station in 49:
			var u := float(station)/48.0
			var at := u*12.0
			var sample_index := mini(int(at),11)
			var a: Vector3 = supported[maxi(sample_index-1,0)].position
			var b: Vector3 = supported[sample_index].position
			var c: Vector3 = supported[sample_index+1].position
			var d: Vector3 = supported[mini(sample_index+2,12)].position
			points.append(b.cubic_interpolate(c,a,d,at-float(sample_index)))
			normals.append(supported[sample_index].normal.slerp(supported[sample_index+1].normal,at-float(sample_index)).normalized())
			var pulse := .72+.28*sin(u*TAU-local_clock*3.1+phase)
			widths.append(float(definition.width_cells)*pow(maxf(0.0,sin(PI*u)),.8)*pulse)
		var piece: MeshInstance3D = pieces[index]
		piece.global_transform=Transform3D(Basis.IDENTITY,fit_origin)
		piece.mesh = PathRibbon.build(points,widths) if settings.shape == "strands" else _petal(points,widths,normals)
		piece.show()
		paths.append({"points":points,"widths":widths})

func _petal(points:Array[Vector3],widths:Array[float],receiving_normals:Array[Vector3])->ArrayMesh:
	var arrays:=[]
	arrays.resize(Mesh.ARRAY_MAX)
	var vertices:=PackedVector3Array()
	var normals:=PackedVector3Array()
	var uv:=PackedVector2Array()
	var colours:=PackedColorArray()
	var indices:=PackedInt32Array()
	var colour:=Color.html(str(settings.colour)).srgb_to_linear()
	colour.a=float(settings.get("source_dissolve",.18))
	for index in points.size():
		var u:=float(index)/float(points.size()-1)
		var tangent:Vector3=(points[mini(index+1,points.size()-1)]-points[maxi(index-1,0)]).normalized()
		var side:Vector3=tangent.cross(receiving_normals[index]).normalized()
		if side.is_zero_approx():side=fit_side
		var normal:=side.cross(tangent).normalized()
		for edge in [-1.0,0.0,1.0]:
			# Cambered leaf surface with a real raised centre; no facing matrix.
			vertices.append(points[index]+side*widths[index]*edge+normal*(1.0-absf(edge))*.018*sin(PI*u))
			normals.append(normal)
			uv.append(Vector2((edge+1.0)*.5,u))
			colours.append(colour)
		if index>0:
			var a:=(index-1)*3
			indices.append_array(PackedInt32Array([a,a+3,a+1,a+1,a+3,a+4,a+1,a+4,a+2,a+2,a+4,a+5]))
	arrays[Mesh.ARRAY_VERTEX]=vertices
	arrays[Mesh.ARRAY_NORMAL]=normals
	arrays[Mesh.ARRAY_TEX_UV]=uv
	arrays[Mesh.ARRAY_COLOR]=colours
	arrays[Mesh.ARRAY_INDEX]=indices
	var mesh:=ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh

func capture_observation()->Dictionary:
	var bounds:=AABB()
	var count:=0
	var visible:=false
	for piece in pieces:
		if piece.mesh.get_surface_count()>0:
			count+=piece.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()
			var box:AABB=piece.mesh.get_aabb()
			bounds=box if bounds.size.is_zero_approx() else bounds.merge(box)
		visible=visible or piece.is_visible_in_tree()
	return {"receiving_flow":{"shape":settings.shape,"actor":surface.get("actor"),"clock":local_clock,
		"envelope":envelope,"curves":pieces.size(),"vertices":count,"bounds":bounds,"world_origin":fit_origin,
		"visible_in_tree":visible,"layers":pieces[0].layers,"receiving_points":measured.size(),"lights":0}}

const VfxPackageIO_4373fef562 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
