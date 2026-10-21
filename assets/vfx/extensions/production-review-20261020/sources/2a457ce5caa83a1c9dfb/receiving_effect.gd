extends Node3D
## Passive visual lease adapter and cambered mesh builder. Subclasses own all
## visible paths. Inputs are documented presentation projections, not wire APIs.
const SourceMaterial = preload("res://assets/vfx/sources/fab3b2fc2c95a74d1a47/source_material.gd")
const GpuPath = preload("res://assets/vfx/extensions/production-review-20261020/sources/e6f9d428eabf74ab814c/cambered_path.gd")
const Frame = preload("res://assets/vfx/sources/02d90ce9caaa3a5e1100/receiving_frame.gd")

var settings: Dictionary = {}
var lease: Dictionary = {}
var event_input: Dictionary = {}
var surface: Dictionary = {}
var endpoints: Array = []
var frame: Dictionary = {}
var material: ShaderMaterial
var pieces: Array[MeshInstance3D] = []
var local_clock := .0
var envelope := .0
var owner_visibility := 1.0
var measured_pose: Array=[]
var measured_origin:=Vector3.ZERO
var fitted_frame: Dictionary={}
var patch_meshes: Dictionary={}


static func construct(path: String, input: Dictionary) -> Node3D:
	var instance: Node3D = VfxPackageIO_2a457ce5ca.resource(path).new()
	instance.settings = input.duplicate(true)
	instance.material = SourceMaterial.make(input.material)
	instance._prepare_pieces(int(input.get("piece_capacity",0)))
	instance.set_lease_input(input.get("lease", {}))
	instance.set_event_input(input.get("event", {}))
	return instance


func set_lease_input(value: Dictionary) -> void:
	lease = value.duplicate(true)
	if material != null:
		sample(local_clock)


func set_event_input(value: Dictionary) -> void:
	event_input = value.duplicate(true)
	if material != null:
		sample(local_clock)


func set_entity_geometry(value: Dictionary) -> void:
	surface = value if str(value.get("actor", "")) == str(settings.geometry_actor) else {}
	_rebuild()


func set_live_endpoints(value: Array) -> void:
	endpoints = []
	var bindings: Array = settings.get("endpoint_bindings",[])
	for index in value.size():
		var supplied: Dictionary = value[index].duplicate(true)
		if not supplied.has("actor") or not supplied.has("socket"):
			if index>=bindings.size():
				continue
			supplied.merge(bindings[index],false)
		endpoints.append(supplied)
	_rebuild()


func set_owner_visibility(value: float) -> void:
	owner_visibility = clampf(value, 0.0, 1.0)
	sample(local_clock)


func owner_admitted() -> bool:
	if not bool(lease.get("observed", false)):
		return false
	var state: Dictionary = lease.get("condition_state", {})
	if settings.has("parent_owner_uuid") and str(lease.get("authoritative_parent_uuid", "")) != str(settings.parent_owner_uuid):
		return false
	return str(state.get("condition_uuid", "")) == str(settings.owner_uuid) \
		and str(state.get("behavior_id", "")) == str(settings.condition_id) \
		and state.get("suppression_provider_uuids", []).is_empty() \
		and str(lease.get("source_entity_uuid", "")) == str(settings.get("lease_source_entity_uuid",settings.source_entity_uuid)) \
		and str(lease.get("target_entity_uuid", "")) == str(settings.recipient_entity_uuid)


func event_admitted() -> bool:
	return str(event_input.get("uuid", "")) == str(settings.get("event_uuid", "")) \
		and not str(event_input.get("uuid", "")).is_empty() \
		and not bool(event_input.get("canceled", true)) \
		and str(event_input.get("source_entity_uuid", "")) == str(settings.source_entity_uuid) \
		and str(event_input.get("target_entity_uuid", "")) == str(settings.recipient_entity_uuid)


func phase_admitted() -> bool:
	if settings.mode in ["windup", "instant", "response"]:
		return event_admitted()
	if settings.mode == "retire":
		return event_admitted() and str(event_input.get("condition_uuid", "")) == str(settings.owner_uuid)
	return owner_admitted()


func sample(seconds: float) -> void:
	local_clock = seconds
	envelope = smoothstep(.0, float(settings.apply_seconds), seconds) * owner_visibility
	if settings.mode == "condition_retire":
		envelope = owner_visibility * (1.0-smoothstep(.0,float(settings.seconds),seconds))
	elif settings.mode != "hold":
		envelope *= 1.0 - smoothstep(float(settings.seconds) - float(settings.retire_seconds), float(settings.seconds), seconds)
	if not phase_admitted():
		envelope = .0
	material.set_shader_parameter("support_clock", seconds)
	material.set_shader_parameter("support_envelope", envelope)
	_rebuild()


func endpoint(actor: String, socket: String) -> Dictionary:
	for value in endpoints:
		if str(value.get("actor", "")) == actor and str(value.get("socket", "")) == socket:
			return value
	return {}


func _paths() -> Array:
	return []


func ribbon(points: Array[Vector3], normals: Array[Vector3], width_cells: float, colour: String = "") -> Dictionary:
	return {"points":points,"normals":normals,"width":width_cells,"colour":colour}


func _mesh(path: Dictionary) -> ArrayMesh:
	if path.get("kind","")=="surface_patch":
		return _patch_mesh(path)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var coordinates := PackedVector2Array()
	var colours := PackedColorArray()
	var indices := PackedInt32Array()
	var count: int = path.points.size()
	var colour := Color.html(str(path.colour) if not str(path.colour).is_empty() else str(settings.vertex_colour)).srgb_to_linear()
	colour.a = float(settings.get("vertex_alpha", 1.0))
	for row in count:
		var u := float(row) / float(count - 1)
		var tangent: Vector3 = (path.points[mini(count-1,row+1)] - path.points[maxi(0,row-1)]).normalized()
		var receiving_normal: Vector3 = path.normals[row]
		var across := receiving_normal.cross(tangent).normalized()
		if across.is_zero_approx():
			across = frame.side
		var width := float(path.width) * pow(maxf(.0, sin(u*PI)), .65)
		for column in 5:
			var fraction := float(column)/4.0
			var edge := fraction*2.0-1.0
			vertices.append(path.points[row] - surface.origin + across*edge*width + receiving_normal*(1.0-edge*edge)*width*.18)
			normals.append(receiving_normal)
			coordinates.append(Vector2(fraction,u))
			colours.append(colour)
			if row>0 and column>0:
				var first := (row-1)*5+column-1
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
	return mesh


func _patch_mesh(path: Dictionary) -> ArrayMesh:
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var coordinates: PackedVector2Array = PackedVector2Array()
	var colours: PackedColorArray = PackedColorArray()
	var indices: PackedInt32Array = PackedInt32Array()
	var colour: Color = Color.html(str(settings.vertex_colour)).srgb_to_linear()
	colour.a = float(settings.vertex_alpha)
	for row in 13:
		for column in 13:
			var uv: Vector2 = Vector2(float(column)/12.0,float(row)/12.0)
			var support: Dictionary = Frame.tangent_support(path.frame,path.centre,(uv.x*2.0-1.0)*float(path.half_size),(uv.y*2.0-1.0)*float(path.half_size))
			vertices.append(support.position+support.normal*.035-surface.origin)
			normals.append(support.normal)
			coordinates.append(uv)
			colours.append(colour)
			if row>0 and column>0:
				var first: int = (row-1)*13+column-1
				indices.append_array(PackedInt32Array([first,first+1,first+13,first+1,first+14,first+13]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices
	arrays[Mesh.ARRAY_NORMAL]=normals
	arrays[Mesh.ARRAY_TEX_UV]=coordinates
	arrays[Mesh.ARRAY_COLOR]=colours
	arrays[Mesh.ARRAY_INDEX]=indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh


func _prepare_pieces(capacity: int) -> void:
	while pieces.size()<capacity:
		var piece: MeshInstance3D = MeshInstance3D.new()
		piece.top_level = true
		piece.material_override = material
		piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		piece.hide()
		add_child(piece)
		pieces.append(piece)


func _rebuild() -> void:
	if material == null:
		return
	for piece in pieces:
		piece.hide()
	frame = _measured_frame()
	if frame.is_empty() or envelope <= .0001:
		return
	var paths := _paths()
	_prepare_pieces(paths.size())
	for index in paths.size():
		if paths[index].get("kind","")!="surface_patch" and paths[index].points.size() < 3:
			continue
		pieces[index].global_transform = Transform3D(Basis.IDENTITY, surface.origin)
		var path: Dictionary=paths[index]
		if path.get("kind","")=="surface_patch":
			var key: Array=[path.centre-surface.origin,path.half_size]
			if not patch_meshes.has(key):
				patch_meshes[key.duplicate()]=_patch_mesh(path)
			pieces[index].mesh=patch_meshes[key]
		elif not bool(settings.get("gpu_paths",false)):
			pieces[index].mesh=_mesh(path)
		else:
			var colour:=Color.html(str(path.colour) if not str(path.colour).is_empty() else str(settings.vertex_colour)).srgb_to_linear()
			colour.a=float(settings.get("vertex_alpha",1.))
			GpuPath.assign(pieces[index],path,surface.origin,frame.side,colour,gpu_longitude_bounds())
		pieces[index].show()


func gpu_longitude_bounds() -> Vector2:
	return Vector2(0,1)


func _measured_frame() -> Dictionary:
	if surface.get("points",[]).size()<8:
		return {}
	var pose:=preload("res://assets/vfx/sources/9c05cee00f7d74560348/geometry_key.gd").from_surface(surface)
	var origin: Vector3=surface.origin
	if pose.is_empty() or pose!=measured_pose or fitted_frame.is_empty():
		fitted_frame=Frame.measure(surface)
		patch_meshes.clear()
		measured_pose=pose.duplicate(true)
		measured_origin=origin
	elif measured_origin!=origin:
		var current:=Frame.measure(surface)
		if not current.is_empty():
			current._support_cache=fitted_frame.get("_support_cache",{})
			current._tangent_cache=fitted_frame.get("_tangent_cache",{})
		fitted_frame=current
		measured_origin=origin
	return fitted_frame


func capture_observation() -> Dictionary:
	var measured := frame.duplicate()
	measured.erase("points")
	return {"high_level_support":{"owner_uuid":settings.owner_uuid,"condition_id":settings.condition_id,
		"geometry_actor":settings.geometry_actor,"receiving_points":surface.get("points",[]).size(),
		"current_frame":measured,"mode":settings.mode,"clock":local_clock,"envelope":envelope,
		"owner_admitted":owner_admitted(),"event_admitted":event_admitted(),
		"visible_pieces":pieces.filter(func(piece:MeshInstance3D)->bool:return piece.is_visible_in_tree()).size(),
		"optical_lights":0,"rules_evaluated":false}}

const VfxPackageIO_2a457ce5ca = preload("res://assets/vfx/extensions/production-review-20261020/scoped_resource_io.gd")
