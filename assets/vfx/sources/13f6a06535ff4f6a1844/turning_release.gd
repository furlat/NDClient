extends "res://assets/vfx/sources/b732021946795f4bbdbc/turning.gd"
## Bounded alternate release. The source wave reaches the supplied radius;
## the original true Turned marker and hand preparation remain independent.

static func make_component(input: Dictionary) -> Node3D:
	return create("res://assets/vfx/sources/13f6a06535ff4f6a1844/turning_release.gd", input)

func _paths() -> Array:
	var result: Array = []
	var centre: Vector3 = frame.origin + Vector3.UP * .045
	var radius: float = float(settings.presentation_radius_cells) * smoothstep(.0, .88, local_clock)
	var oath: bool = bool(settings.get("oath_release", false))
	# Open radial plumes, never a maintained wall or enclosing shell. Different
	# cleric/oath spoke spacing retains two cast identities around one condition.
	var spoke_count: int = 16 if oath else 20
	for spoke in spoke_count:
		var angle: float = TAU * float(spoke) / float(spoke_count) + (.13 if oath else .0)
		var radial := Vector3(cos(angle), .0, sin(angle))
		var tangent := Vector3(-sin(angle), .0, cos(angle))
		var points: Array[Vector3] = []
		for index in 33:
			var progress: float = float(index) / 32.0
			var reach: float = radius * (.10 + .90 * progress)
			var curl: float = sin(progress * PI) * (.12 if oath else .20)
			points.append(centre + radial * reach + tangent * curl
				+ Vector3.UP * (.025 + sin(progress * PI) * (.14 if oath else .22)))
		result.append(line(points, .13 if oath else .16, Vector3.UP))
	return result

func _mesh(path: Dictionary) -> ArrayMesh:
	var base: ArrayMesh = super._mesh(path)
	var arrays: Array = base.surface_get_arrays(0)
	var coordinates: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	# Spatial wave UVs use the retained native plume's active fragment interval.
	# Mesh endpoints still feather, while visible artwork reaches the area edge.
	for index in coordinates.size():
		coordinates[index].y = .28 + coordinates[index].y * .54
	arrays[Mesh.ARRAY_TEX_UV] = coordinates
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func gpu_longitude_bounds() -> Vector2:
	return Vector2(.28,.82)
