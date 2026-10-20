extends "res://assets/vfx/extensions/followup-20261020/sources/2a457ce5caa83a1c9dfb/receiving_effect.gd"
## Native counterflow runes on actual-brow eyelids and ordered temporal ticks.


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/extensions/followup-20261020/sources/f572a404958a45a068d5/foresight.gd", input)


func _paths() -> Array:
	var result := []
	var centre: Vector3 = frame.centre
	if settings.part == "windup":
		var palm: Dictionary = endpoint(str(settings.geometry_actor),"cast_hand")
		if palm.is_empty():
			return result
		centre = palm.point
	var width: float = minf(.24,maxf(.115,float(frame.half_width)*1.8))
	var height: float = minf(.085,maxf(.045,float(frame.height)*.40))
	var opening: float = smoothstep(.0,.5,local_clock) if settings.mode == "apply" else 1.0
	for lid in 2:
		var parity := -1.0 if lid == 0 else 1.0
		var points: Array[Vector3] = []
		var normals: Array[Vector3] = []
		for row in 41:
			var u := float(row)/40.0
			var across := (u*2.0-1.0)*width
			var elevation := sin(u*PI)*height*parity*opening
			var support: Dictionary = Frame.support(frame,across,centre.y+elevation)
			var point: Vector3 = support.position+support.normal*(.045+float(lid)*.012)
			# Restore the requested measured tangent coordinates at sparse brow
			# samples while preserving actual normal-space receiving depth.
			point += frame.side*(across-(point-centre).dot(frame.side))
			point += frame.up*(elevation-(point-centre).dot(frame.up))
			if settings.part == "windup":
				point = centre+frame.side*across+frame.up*elevation+frame.normal*.04
			points.append(point)
			normals.append(support.normal)
		result.append(ribbon(points,normals,float(settings.width_cells)))
	for tick in 3:
		var points: Array[Vector3] = []
		var normals: Array[Vector3] = []
		for row in 9:
			var u := float(row)/8.0
			points.append(centre+frame.side*(width+.035+float(tick)*.028)+frame.up*((u-.5)*.05)+frame.normal*.055)
			normals.append(frame.normal)
		result.append(ribbon(points,normals,float(settings.width_cells)*.65))
	return result
