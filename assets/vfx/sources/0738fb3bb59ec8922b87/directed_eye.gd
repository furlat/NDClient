extends "res://assets/vfx/sources/c20c9bb74249d40950f7/eyebite_directed.gd"
## Preserved eye/link materials with live recipient and actual camera geometry.
var live_endpoints: Array = []
var link_draw: MeshInstance3D
var last_start: Vector3 = Vector3.ZERO
var last_target: Vector3 = Vector3.ZERO

static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/0738fb3bb59ec8922b87/directed_eye.gd",input)

func set_live_endpoints(value: Array) -> void:
	live_endpoints = value

func apply_scene_edits(node: Node) -> void:
	super.apply_scene_edits(node)
	# Pygame's owner plane and native units are explicit authored registration,
	# independent of the caster's animated hand and of the camera quarter.
	eye.mesh.size = Vector2(settings.eye_size_cells[0], settings.eye_size_cells[1])
	eye.position.y = float(settings.owner_height_world)
	for child in node.get_children():
		if child is MeshInstance3D and child!=eye:
			link_draw = child

func sample(seconds: float) -> void:
	super.sample(seconds)
	if live_endpoints.size()<2 or not is_instance_valid(link_draw):
		return
	var inverse := subject.global_transform.affine_inverse()
	eye.position = inverse * live_endpoints[0].point + Vector3.UP * float(settings.owner_height_world)
	target = inverse*live_endpoints[1].point
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera!=null:
		viewdir = (inverse.basis*camera.global_basis.z).normalized()
	var start: Vector3 = eye.position
	var tangent := (target-start).normalized()
	var across := tangent.cross(viewdir).normalized()
	if across.is_zero_approx():
		across = Vector3.RIGHT
	_write_link(start,target,across)
	var toward := (target-start).normalized()
	var normal := viewdir.lerp(toward,.32*smoothstep(0.,.32,seconds)).normalized()
	eye.look_at(eye.global_position+subject.global_basis*normal,Vector3.UP,true)
	last_start = eye.global_position
	last_target = subject.to_global(target)

func capture_observation() -> Dictionary:
	return {"eye_world": [last_start.x, last_start.y, last_start.z],
		"target_world": [last_target.x, last_target.y, last_target.z],
		"native_tick": tick}

func _write_link(start: Vector3,recipient: Vector3,across: Vector3) -> void:
	var vertices := PackedVector3Array()
	var uv := PackedVector2Array()
	var indices := PackedInt32Array()
	for index in 129:
		var u := float(index)/128.
		var centre := start.lerp(recipient,u)+Vector3.UP*sin(u*PI)*float(settings.arc_height_world)
		for sign_value in [-1.,1.]:
			vertices.append(centre+across*sign_value*float(settings.width_cells)*.5)
			uv.append(Vector2(u,(sign_value+1.)*.5))
	for index in 128:
		var a := index*2
		indices.append_array(PackedInt32Array([a,a+1,a+2,a+1,a+3,a+2]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	link_draw.mesh = mesh
