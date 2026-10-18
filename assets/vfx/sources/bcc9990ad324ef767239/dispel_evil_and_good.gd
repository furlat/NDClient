extends "res://assets/vfx/sources/2a457ce5caa83a1c9dfb/receiving_effect.gd"
## Open six-stroke self ward. A supplied paid touch is a follow-up, not a cast.


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/bcc9990ad324ef767239/dispel_evil_and_good.gd", input)


func _paths() -> Array:
	var result := []
	if settings.part == "break":
		if event_input.get("removed_condition_uuids", []).is_empty() or str(event_input.get("ward_uuid", "")) != str(settings.ward_uuid):
			return result
		var palm: Dictionary = endpoint("caster","hand")
		var contact: Dictionary = endpoint(str(settings.geometry_actor),"body_center")
		if palm.is_empty() or contact.is_empty():
			return result
		for strand in 3:
			var points: Array[Vector3] = []
			var normals: Array[Vector3] = []
			for row in 33:
				var u := float(row)/32.0
				var arch: float = sin(u*PI)
				var bend: float = arch*(.035+float(strand)*.016)
				points.append(palm.point.lerp(contact.point,u)+frame.up*bend+frame.side*arch*.05*float(strand-1))
				normals.append(frame.normal)
			result.append(ribbon(points,normals,float(settings.width_cells)))
		return result
	for stroke in 6:
		var parity := -1.0 if stroke%2 == 0 else 1.0
		var tier := float(stroke/2)
		var points: Array[Vector3] = []
		var normals: Array[Vector3] = []
		for row in 25:
			var u := float(row)/24.0
			var across: float = parity*frame.half_width*(.95-.32*(1.0-absf(u*2.0-1.0)))
			var elevation: float = frame.bottom+frame.height*(.39+tier*.19+(u-.5)*.12)
			var support: Dictionary = Frame.support(frame,across,elevation)
			var separation := .03+.025*sin(u*PI)
			if settings.mode == "retire":
				separation += .05*smoothstep(.0,float(settings.seconds),local_clock)
			points.append(support.position+support.normal*separation+frame.side*parity*.035)
			normals.append(support.normal)
		result.append(ribbon(points,normals,float(settings.width_cells)))
	return result
