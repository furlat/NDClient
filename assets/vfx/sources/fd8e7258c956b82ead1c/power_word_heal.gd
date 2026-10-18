extends "res://assets/vfx/sources/2a457ce5caa83a1c9dfb/receiving_effect.gd"
## Verbal source syllables and actual positive-heal restoration. Cures and
## standing use committed external facts; this component changes no actor pose.


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/fd8e7258c956b82ead1c/power_word_heal.gd", input)


func phase_admitted() -> bool:
	if settings.part == "word":
		return event_admitted()
	var fact: Dictionary = event_input.get("heal_fact", {})
	return event_admitted() and int(fact.get("actual_healing",0)) > 0 and not bool(fact.get("was_blocked",true)) \
		and str(fact.get("source_entity_uuid","")) == str(settings.source_entity_uuid) \
		and str(fact.get("target_entity_uuid","")) == str(settings.recipient_entity_uuid)


func _paths() -> Array:
	var result := []
	if settings.part == "word":
		var face: Dictionary = endpoint(str(settings.geometry_actor),"face")
		var recipient: Dictionary = endpoint(str(settings.voice_recipient_actor),"body_center")
		if face.is_empty() or recipient.is_empty():
			return result
		var direction: Vector3 = (recipient.point-face.point).normalized()
		if direction.is_zero_approx():
			return result
		for syllable in 3:
			var points: Array[Vector3] = []
			var normals: Array[Vector3] = []
			var radius: float = .075+float(syllable)*.035+.035*smoothstep(.10,.60,local_clock)
			for row in 25:
				var u := float(row)/24.0
				var angle := (u-.5)*PI*.9
				var advance: float = .06+float(syllable)*.045+.045*smoothstep(.10,.60,local_clock)
				points.append(face.point+direction*advance+frame.side*sin(angle)*radius+frame.up*(cos(angle)-.75)*radius*.62)
				normals.append(frame.normal)
			result.append(ribbon(points,normals,float(settings.width_cells)))
		return result
	if settings.part == "cross":
		var chest: Array = frame.points.filter(func(point:Dictionary)->bool:return str(point.get("slot",""))=="chest")
		if chest.size()<8:
			chest = frame.points.filter(func(point:Dictionary)->bool:return str(point.get("slot",""))=="body")
		var measured: Dictionary = Frame.measure({"points":chest,"actor":surface.actor,"origin":surface.origin})
		if measured.is_empty():
			return result
		result.append({"kind":"surface_patch","frame":measured,"centre":measured.centre,"half_size":.072})
		return result
	for seam in 6:
		var parity := -1.0 if seam%2 == 0 else 1.0
		var tier := float(seam/2)
		var points: Array[Vector3] = []
		var normals: Array[Vector3] = []
		for row in 41:
			var u := float(row)/40.0
			var join := smoothstep(.0,.72,local_clock)
			var across: float = parity*frame.half_width*(.90-.72*u)*(.75+.25*(1.0-join))
			var elevation: float = frame.bottom+frame.height*(.24+tier*.18+u*.18)
			var support: Dictionary = Frame.support(frame,across,elevation)
			var clearance := .028+.03*sin(u*PI)*(1.0-join)
			points.append(support.position+support.normal*clearance)
			normals.append(support.normal)
		result.append(ribbon(points,normals,float(settings.width_cells)))
	return result
