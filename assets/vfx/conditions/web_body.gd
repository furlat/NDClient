extends RefCounted
## Original lower LeLu mesh plus one continuous upper net. Nine measured
## silhouette slices upload only on a changed pose; GPU places upper vertices.
var entries: Array = []
var settings: Dictionary = {}
var visual: Node3D
var lower: Node3D
var texture: ImageTexture
var last_key: Array = []
var uploads := 0
var admitted_geometry := false


func configure(root: Node3D, specification: Dictionary, geometry: Array) -> void:
	settings = specification.settings
	visual = root
	lower = visual.get_node(settings.lower_path)
	for entry in geometry:
		if entry.node.has_meta("condition_web_body_template"):
			entries.append({"node":entry.node,"material":entry.node.material_override,"kind":"web_body"})
	assert(entries.size() == 4)
	visual.hide()


func update(surface: Dictionary) -> void:
	if surface.get("points", []).size() < 8:
		admitted_geometry = false
		visual.hide()
		last_key = []
		return
	var key: Array = surface.get("gpu_geometry_key", [])
	if admitted_geometry and not key.is_empty() and last_key == key:
		return
	var inverse := visual.global_transform.affine_inverse()
	var ground: Vector3 = inverse * surface.get("origin",Vector3.ZERO)
	var points: Array[Vector3] = []
	var height := 0.0
	var radius := 0.0
	var average := Vector3.ZERO
	for point in surface.points:
		var local: Vector3 = inverse * point.position
		points.append(local)
		average += local
		height = maxf(height,local.y-ground.y)
		radius = maxf(radius,Vector2(local.x-ground.x,local.z-ground.z).length())
	average /= float(points.size())
	var clearance: float = float(settings.clearance_cells) / absf(visual.global_basis.get_scale().x)
	radius = maxf(radius,.15/absf(visual.global_basis.get_scale().x)) + clearance
	var bounds: Array = settings.source_bounds
	var size := Vector3(bounds[3],bounds[4],bounds[5])
	var start := Vector3(bounds[0],bounds[1],bounds[2])
	lower.scale = Vector3(radius*1.45,height*.52+clearance,radius*1.45)/size
	lower.position = ground - Vector3(start.x+size.x*.5,start.y,start.z+size.z*.5)*lower.scale
	var covariance := Vector3.ZERO
	for point in points:
		var delta: Vector3 = point-average
		covariance += Vector3(delta.x*delta.x,delta.x*delta.z,delta.z*delta.z)
	var angle := .5*atan2(2.*covariance.y,covariance.x-covariance.z)
	var major := Vector3(cos(angle),0,sin(angle))
	var minor := Vector3(-major.z,0,major.x)
	var image := Image.create_empty(9,2,false,Image.FORMAT_RGBAF)
	for row in 9:
		var elevation := height*lerpf(.15,.86,float(row)/8.)
		var nearest := INF
		for point in points:
			nearest = minf(nearest,absf(point.y-ground.y-elevation))
		var band := maxf(height*.075,nearest+.0001)
		var minimum := Vector2(INF,INF)
		var maximum := -minimum
		for point in points:
			if absf(point.y-ground.y-elevation) <= band:
				var coordinate := Vector2(point.dot(major),point.dot(minor))
				minimum = minimum.min(coordinate)
				maximum = maximum.max(coordinate)
		var centre := major*((minimum.x+maximum.x)*.5)+minor*((minimum.y+maximum.y)*.5)
		var extent := ((maximum-minimum)*.5+Vector2.ONE*clearance).max(Vector2.ONE*clearance)
		image.set_pixel(row,0,Color(centre.x,centre.y,centre.z,ground.y+elevation))
		image.set_pixel(row,1,Color(extent.x,extent.y,0,0))
	if texture == null:
		texture = ImageTexture.create_from_image(image)
	else:
		texture.update(image)
	for entry in entries:
		entry.material.set_shader_parameter("vfx_web_body_slices",texture)
		entry.material.set_shader_parameter("vfx_web_body_major",major)
		entry.material.set_shader_parameter("vfx_web_body_minor",minor)
	admitted_geometry = true
	last_key = key.duplicate()
	uploads += 1
	visual.show()
