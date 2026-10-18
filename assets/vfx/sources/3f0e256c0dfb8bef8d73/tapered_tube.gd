extends RefCounted
## Curved physical branch geometry with transported rings, smooth outward
## normals and continuous bark UVs. No material, spell, actor or stage policy.


static func build(controls: Array[Vector3], control_radii: Array[float]) -> ArrayMesh:
	assert(controls.size() == control_radii.size() and controls.size() >= 2)
	var centres: Array[Vector3] = []
	var radii: Array[float] = []
	for index in range(controls.size()-1):
		for step in 5:
			var weight := float(step)/5.0
			centres.append(controls[index].cubic_interpolate(controls[index+1],
				controls[maxi(index-1,0)], controls[mini(index+2,controls.size()-1)],weight))
			radii.append(lerpf(control_radii[index],control_radii[index+1],weight))
	centres.append(controls.back())
	radii.append(control_radii.back())
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uv := PackedVector2Array()
	var indices := PackedInt32Array()
	var previous_tangent := Vector3.UP
	var radial_axis := Vector3.RIGHT
	var distance := 0.0
	const SIDES := 10
	for station in centres.size():
		var low := maxi(0,station-1)
		var high := mini(centres.size()-1,station+1)
		var tangent := (centres[high]-centres[low]).normalized()
		if station == 0:
			radial_axis=tangent.cross(Vector3.UP if absf(tangent.y)<.95 else Vector3.RIGHT).normalized()
		else:
			radial_axis=Quaternion(previous_tangent,tangent)*radial_axis
			radial_axis=(radial_axis-tangent*radial_axis.dot(tangent)).normalized()
			distance+=centres[station].distance_to(centres[station-1])
		var across := tangent.cross(radial_axis).normalized()
		var slope := (radii[high]-radii[low])/maxf(.00001,centres[high].distance_to(centres[low]))
		for side in range(SIDES+1):
			var angle := float(side)*TAU/float(SIDES)
			var radial := radial_axis*cos(angle)+across*sin(angle)
			vertices.append(centres[station]+radial*radii[station])
			normals.append((radial-tangent*slope).normalized())
			uv.append(Vector2(float(side)/float(SIDES),distance/.36))
			if station > 0 and side < SIDES:
				var start := (station-1)*(SIDES+1)+side
				indices.append_array(PackedInt32Array([start,start+1,start+SIDES+1,start+1,start+SIDES+2,start+SIDES+1]))
		previous_tangent=tangent
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices
	arrays[Mesh.ARRAY_NORMAL]=normals
	arrays[Mesh.ARRAY_TEX_UV]=uv
	arrays[Mesh.ARRAY_INDEX]=indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh
