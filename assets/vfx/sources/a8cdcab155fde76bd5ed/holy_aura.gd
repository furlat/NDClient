extends "res://assets/vfx/sources/2a457ce5caa83a1c9dfb/receiving_effect.gd"
## Fixed recipient feather rays, separate from the caster's cast-owned blinds.


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/a8cdcab155fde76bd5ed/holy_aura.gd", input)


func _paths() -> Array:
	var result := []
	if settings.part == "ground":
		for ray in 12:
			var angle := float(ray)*TAU/12.0
			var points: Array[Vector3] = []
			var normals: Array[Vector3] = []
			for row in 17:
				var u := float(row)/16.0
				var radius := .18+u*.18
				points.append(surface.origin+Vector3(cos(angle)*radius,.025,sin(angle)*radius))
				normals.append(Vector3.UP)
			result.append(ribbon(points,normals,float(settings.width_cells)))
		return result
	for feather in 6:
		var parity := -1.0 if feather%2 == 0 else 1.0
		var tier := float(feather/2)
		var points: Array[Vector3] = []
		var normals: Array[Vector3] = []
		for row in 33:
			var u := float(row)/32.0
			var root: Dictionary = Frame.support(frame,parity*frame.half_width*.65,frame.bottom+frame.height*(.72-tier*.06))
			var opening: float = smoothstep(.0,.45,local_clock) if settings.mode == "apply" else 1.0
			var reach := u*(.13+tier*.035)*opening
			var rise := u*(.17-tier*.04)*opening
			points.append(root.position+root.normal*(.035+.025*sin(u*PI))+frame.side*parity*reach+frame.up*rise)
			normals.append(root.normal)
		result.append(ribbon(points,normals,float(settings.width_cells)*(1.0-.12*tier)))
	return result
