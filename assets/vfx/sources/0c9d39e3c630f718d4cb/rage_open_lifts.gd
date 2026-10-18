extends "res://assets/vfx/sources/7c77eade22900392e0b5/accepted_class_source_v176.gd"
## Raging/Frenzied keep their own Flow material, body Film, owner contract,
## activation and motes. Short rising licks replace enclosing spiral coils.


static func make_component(input: Dictionary) -> Node3D:
	assert(str(input.kind) == "mantle")
	var instance: Node3D = VfxPackageIO_0c9d39e3c6.resource("res://assets/vfx/sources/0c9d39e3c630f718d4cb/rage_open_lifts.gd").new()
	instance.settings = input.duplicate(true)
	instance.kind = "mantle"
	instance.owner_projection = input.owner_projection.duplicate(true)
	instance.feedback_events = input.get("feedback_events", []).duplicate(true)
	instance._validate_projection(instance.owner_projection)
	instance._build()
	return instance


func _point(index: int, u: float, seconds: float) -> Vector3:
	var phase := TAU * seconds / 2.0
	var angle := float(index) * 2.399963 + u * 0.38 + 0.08 * sin(phase + u * PI + index)
	var radius := 0.25 + 0.045 * sin(u * PI) + 0.025 * cos(phase + index)
	var height := 0.10 + float(index % 3) * 0.15 + u * 0.63
	return Vector3(cos(angle) * radius, height, sin(angle) * radius)


func _strip(index: int, seconds: float) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array = []
	for station in 33:
		var u := float(station) / 32.0
		var point := _point(index, u, seconds)
		var tangent := (_point(index, minf(1.0, u + 0.005), seconds) - _point(index, maxf(0.0, u - 0.005), seconds)).normalized()
		var radial := Vector3(point.x, 0, point.z).normalized()
		var across := tangent.cross(radial).normalized()
		var width := 0.035 * pow(maxf(0.0, sin(PI*u)), 0.6)
		rings.append([point-across*width, point+radial*0.014*sin(PI*u), point+across*width])
	for station in 32:
		for edge in 2:
			for coordinate in [Vector2i(station,edge), Vector2i(station,edge+1), Vector2i(station+1,edge+1), Vector2i(station,edge), Vector2i(station+1,edge+1), Vector2i(station+1,edge)]:
				surface.set_uv(Vector2(float(coordinate.x)/32.0,float(coordinate.y)*0.5))
				surface.add_vertex(rings[coordinate.x][coordinate.y])
	surface.generate_normals()
	return surface.commit()


func capture_observation() -> Dictionary:
	var result: Dictionary = super.capture_observation()
	result.restoration = "Same original Flow material/clock/owner, deliberately revised open rising geometry; no raster or old coil-shape parity claim"
	result.open_lifts = {"pieces": pieces.size(), "source_uv_axes_preserved": true,
		"body_film_and_activation_changed": false, "new_optical_lights": 0}
	return result

const VfxPackageIO_0c9d39e3c6 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
