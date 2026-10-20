extends "res://assets/vfx/extensions/followup-20261020/sources/2a457ce5caa83a1c9dfb/receiving_effect.gd"
## Life field, admitted member buds and observed recovery have separate owners.


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/extensions/followup-20261020/sources/579fe4609d2e4f7aab1b/aura_of_life.gd", input)


func phase_admitted() -> bool:
	if settings.part == "recovery":
		var fact: Dictionary = event_input.get("heal_fact", {})
		return owner_admitted() and event_admitted() and int(fact.get("actual_healing",0)) > 0 and not bool(fact.get("was_blocked",true)) \
			and str(fact.get("target_entity_uuid","")) == str(settings.recipient_entity_uuid) \
			and str(event_input.get("attributed_benefit_uuid","")) == str(settings.get("benefit_uuid",""))
	return super.phase_admitted()


func _paths() -> Array:
	var result := []
	if settings.part == "field":
		var area: Dictionary = settings.public_area
		assert(str(area.uuid) == str(settings.area_uuid) and float(area.radius_cells) > 0.0)
		var radius := float(area.radius_cells)
		for petal in 6:
			var points: Array[Vector3] = []
			var normals: Array[Vector3] = []
			for row in 49:
				var u := float(row)/48.0
				var angle := float(petal)*TAU/6.0 + (u-.5)*.66
				var reach := radius*(.18+.80*sin(u*PI))
				var height := .024+.035*sin(u*PI)+.006*sin(local_clock*.7+float(petal)+u*PI)
				points.append(surface.origin+Vector3(cos(angle)*reach,height,sin(angle)*reach))
				normals.append(Vector3.UP)
			result.append(ribbon(points,normals,float(settings.width_cells)))
		return result
	if settings.part == "windup":
		var palm: Dictionary = endpoint(str(settings.geometry_actor),"cast_hand")
		if palm.is_empty():
			return result
		for number in 2:
			var points: Array[Vector3] = []
			var normals: Array[Vector3] = []
			for row in 25:
				var u := float(row)/24.0
				var angle := u*PI+float(number)*PI
				points.append(palm.point+frame.side*cos(angle)*.10+frame.up*sin(angle)*.13+frame.normal*.03)
				normals.append(frame.normal)
			result.append(ribbon(points,normals,float(settings.width_cells)))
		return result
	var recovery: bool = settings.part == "recovery"
	for branch in 4:
		var points: Array[Vector3] = []
		var normals: Array[Vector3] = []
		var parity := -1.0 if branch%2 == 0 else 1.0
		var tier := float(branch/2)
		for row in 33:
			var u := float(row)/32.0
			var elevation: float = frame.bottom+frame.height*(.18+.56*u+.055*tier)
			var across: float = frame.half_width*parity*(.30+.52*sin(u*PI))
			var support: Dictionary = Frame.support(frame,across,elevation)
			var bloom := sin(u*PI)*(.025 if not recovery else .07*smoothstep(.0,.4,local_clock))
			points.append(support.position+support.normal*(.025+bloom)+frame.side*parity*bloom*.35)
			normals.append(support.normal)
		result.append(ribbon(points,normals,float(settings.width_cells)))
	return result
