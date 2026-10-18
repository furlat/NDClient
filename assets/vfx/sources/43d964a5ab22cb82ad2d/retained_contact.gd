extends "res://assets/vfx/sources/397ef2a8907055317449/smite_common.gd"
## Shared measured surfaces and explicit result admission only. Spell artwork,
## qualified attack kind and caster/recipient ownership remain in each root.
const ContactMaterial = preload("res://assets/vfx/sources/77df0f04e1ac57bc4f5e/contact_material.gd")
var retained_owner: Dictionary = {}
var healing: Dictionary = {}
var body_paths: Dictionary = {}
var body_path_order: Array = []

func configure(input: Dictionary) -> void:
	super.configure(input)
	set_owner_input(input.get("owner",{}))
	set_healing_input(input.get("healing",{}))

func set_owner_input(value: Dictionary) -> void:
	retained_owner = value.duplicate(true)
	_hide_all()

func set_healing_input(value: Dictionary) -> void:
	healing = value.duplicate(true)
	_hide_all()

func owner_admitted() -> bool:
	return not str(retained_owner.get("condition_uuid","")).is_empty() \
		and str(retained_owner.get("condition_uuid","")) == str(settings.get("owner_uuid","")) \
		and str(retained_owner.get("condition_id","")) == str(settings.get("owner_id","")) \
		and str(retained_owner.get("source_actor_uuid","")) == str(settings.source_actor_uuid) \
		and str(retained_owner.get("recipient_uuid","")) == str(settings.source_actor_uuid) \
		and bool(retained_owner.get("present",false)) and bool(retained_owner.get("observed",false)) \
		and bool(retained_owner.get("contribution_active",false)) and not bool(retained_owner.get("suppressed",true))

func _sample_materials(seconds: float, value: float) -> void:
	local_clock = seconds
	envelope = value
	for material in materials:
		material.set_shader_parameter("owned_clock",seconds)
		material.set_shader_parameter("owned_envelope",value)

func nearest_surface_point(desired: Vector3, slots: Array) -> Dictionary:
	var best: Dictionary = {}
	var distance := INF
	for point in recipient_surface().get("points",[]):
		if not str(point.slot) in slots:
			continue
		var candidate: float = point.position.distance_squared_to(desired)
		if candidate < distance:
			best = point
			distance = candidate
	return best

func body_path(horizontal: Array, heights: Array, clearance: float) -> Array[Vector3]:
	var surface := recipient_surface()
	var result: Array[Vector3] = []
	var hit := contact()
	if surface.get("points",[]).is_empty() or hit.is_empty():
		return result
	var origin: Vector3 = surface.origin
	var pose := preload("res://assets/vfx/sources/9c05cee00f7d74560348/geometry_key.gd").from_surface(surface)
	var key: Array = [pose, hit.position-origin, hit.normal, horizontal, heights, clearance]
	if not pose.is_empty() and body_paths.has(key):
		for point in body_paths[key]:
			result.append(point+origin)
		return result
	var side: Vector3 = plane_axes(hit.normal)[0]
	var height := .01
	var left := INF
	var right := -INF
	for point in surface.points:
		if not str(point.slot) in ["body","chest","cloak","legs","shoes"]:
			continue
		height = maxf(height,point.position.y-origin.y)
		left = minf(left,(point.position-origin).dot(side))
		right = maxf(right,(point.position-origin).dot(side))
	if left == INF:
		return result
	for index in horizontal.size():
		var desired := origin+side*lerpf(left,right,float(horizontal[index]))+Vector3.UP*height*float(heights[index])
		var point := nearest_surface_point(desired,["body","chest","cloak","legs","shoes"])
		if point.is_empty():
			return []
		result.append(point.position+point.normal.normalized()*clearance)
	if not pose.is_empty():
		var relative: Array[Vector3] = []
		for point in result:
			relative.append(point-origin)
		body_paths[key.duplicate(true)] = relative
		body_path_order.append(key.duplicate(true))
		if body_path_order.size() > 32:
			body_paths.erase(body_path_order.pop_front())
	return result

func tube(points: Array[Vector3], radius: float, growth: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := maxi(2,ceili(float(points.size())*clampf(growth,.01,1.0)))
	for index in count-1:
		var tangent := (points[mini(index+1,count-1)]-points[maxi(index-1,0)]).normalized()
		if tangent.is_zero_approx():
			tangent = Vector3.UP
		var across := tangent.cross(Vector3.FORWARD).normalized()
		if across.is_zero_approx():
			across = Vector3.RIGHT
		var around := tangent.cross(across).normalized()
		for segment in 7:
			for corner in [Vector2i(0,0),Vector2i(0,1),Vector2i(1,1),Vector2i(0,0),Vector2i(1,1),Vector2i(1,0)]:
				var along: int = index+corner.x
				var angle := TAU*float(segment+corner.y)/7.0
				var normal := across*cos(angle)+around*sin(angle)
				var taper := .25+.75*sin(PI*float(along)/float(count))
				st.set_normal(normal)
				st.set_uv(Vector2(float(segment+corner.y)/7.0,float(along)/float(points.size()-1)))
				st.add_vertex(points[along]+normal*radius*taper)
	return st.commit()

func capture_observation() -> Dictionary:
	var result := super.capture_observation()
	result["retained_contact"] = {"owner_admitted":owner_admitted(),"owner_uuid":retained_owner.get("condition_uuid"),
		"healing_fact_uuid":healing.get("healing_fact_uuid"),"recipient_points":recipient_surface().get("points",[]).size()}
	return result
