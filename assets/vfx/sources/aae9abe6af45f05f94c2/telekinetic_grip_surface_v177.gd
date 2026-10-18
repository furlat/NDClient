extends RefCounted
## Exact visible vertices weighted to the original distal thumb/index bones.
## This is source-mesh sampling, not anatomical or collision certification.
var mesh: MeshInstance3D
var skeleton: Skeleton3D
var source_root: Node3D
var vertices: PackedVector3Array
var joints: PackedInt32Array
var weights: PackedFloat32Array
var bindings: Array = []
var pad_vertices: Dictionary = {}

func prepare(root: Node3D) -> void:
	source_root = root
	mesh = root.find_children("*", "MeshInstance3D", true, false)[0]
	skeleton = mesh.get_node(mesh.skeleton)
	var arrays: Array = mesh.mesh.surface_get_arrays(0)
	vertices = arrays[Mesh.ARRAY_VERTEX]
	joints = arrays[Mesh.ARRAY_BONES]
	weights = arrays[Mesh.ARRAY_WEIGHTS]
	for index in mesh.skin.get_bind_count():
		var bone: int = mesh.skin.get_bind_bone(index)
		if bone < 0:
			bone = skeleton.find_bone(mesh.skin.get_bind_name(index))
		bindings.append({"bone":bone,"pose":mesh.skin.get_bind_pose(index)})
	for name in ["thumb3.r", "index3.r"]:
		var bone: int = skeleton.find_bone(name)
		var candidates := []
		var low := INF
		var high := -INF
		for index in vertices.size():
			for influence in 4:
				var offset: int = index * 4 + influence
				var binding: Dictionary = bindings[joints[offset]]
				if binding.bone == bone and weights[offset] >= 0.5:
					var local: Vector3 = binding.pose * vertices[index]
					candidates.append({"vertex":index,"along":local.y})
					low = minf(low, local.y)
					high = maxf(high, local.y)
		var selected := []
		for candidate in candidates:
			if candidate.along >= lerpf(low, high, 0.6):
				selected.append(candidate.vertex)
		pad_vertices[name] = selected

func position(index: int) -> Vector3:
	var posed := Vector3.ZERO
	for influence in 4:
		var offset: int = index * 4 + influence
		if weights[offset] <= 0.0:
			continue
		var binding: Dictionary = bindings[joints[offset]]
		posed += (skeleton.get_bone_global_pose(binding.bone) * binding.pose * vertices[index]) * weights[offset]
	return source_root.to_local(skeleton.global_transform * posed)

func closest_pair() -> Dictionary:
	var best := INF
	var result := {}
	for thumb in pad_vertices["thumb3.r"]:
		var thumb_point: Vector3 = position(thumb)
		for index in pad_vertices["index3.r"]:
			var index_point: Vector3 = position(index)
			var distance: float = thumb_point.distance_squared_to(index_point)
			if distance < best:
				best = distance
				result = {"thumb_vertex":thumb,"index_vertex":index,
					"thumb":thumb_point,"index":index_point,"distance":sqrt(distance)}
	return result
