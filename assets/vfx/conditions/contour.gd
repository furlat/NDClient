extends RefCounted
## Original Faerie Fire pixel-union topology and source UV arc length. Shared
## immutable quads reconstruct the strip on GPU; only changed poses upload.
const Boundary = preload("res://assets/vfx/sources/2a27d065b490c7cfdfe2/pixel_boundary.gd")
var entries: Array = []
var settings: Dictionary = {}
var texture: ImageTexture
var uploads := 0
var admitted_geometry := false
var last_key: Array = []


func configure(visual: Node3D, specification: Dictionary, geometry: Array) -> void:
	settings = specification.settings
	for entry in geometry:
		if entry.node.has_meta("condition_contour_template"):
			entries.append({"node": entry.node, "material": entry.node.material_override, "visual": visual, "kind": "contour"})
			entry.node.hide()
	assert(entries.size() == 1)


func update(surface: Dictionary) -> void:
	var key: Array = surface.get("gpu_geometry_key", [])
	if admitted_geometry and not key.is_empty() and key == last_key:
		return
	admitted_geometry = false
	entries[0].node.hide()
	last_key = []
	var points: Array = surface.get("points", []).filter(func(point: Dictionary) -> bool: return point.get("pixel") is Vector2i)
	if points.size() < 8:
		return
	var frame := Boundary.frame(points)
	var chains := Boundary.chains(points)
	var segments := []
	var inverse: Transform3D = entries[0].visual.global_transform.affine_inverse()
	for chain in chains:
		var path: Array = chain.map(func(corner: Vector2i) -> Dictionary: return Boundary.corner(corner, frame))
		var arc := 0.0
		for index in path.size() - 1:
			var start: Dictionary = path[index]
			var end: Dictionary = path[index + 1]
			var after: float = arc + start.position.distance_to(end.position)
			segments.append({"start": inverse * start.position, "end": inverse * end.position,
				"normal_start": (inverse.basis * start.normal).normalized(), "normal_end": (inverse.basis * end.normal).normalized(),
				"before": inverse * path[maxi(0,index-1)].position, "after": inverse * path[mini(index+2,path.size()-1)].position,
				"arc_start": arc, "arc_end": after})
			arc = after
	if segments.is_empty() or segments.size() > int(settings.get("capacity", 8192)):
		return
	var image := Image.create_empty(segments.size(), 6, false, Image.FORMAT_RGBAF)
	for index in segments.size():
		var segment: Dictionary = segments[index]
		var vectors := [segment.start,segment.end,segment.normal_start,segment.normal_end,segment.before,segment.after]
		for row in vectors.size():
			var vector: Vector3 = vectors[row]
			var scalar: float = segment.arc_start if row == 0 else segment.arc_end if row == 1 else 0.0
			image.set_pixel(index,row,Color(vector.x,vector.y,vector.z,scalar))
	if texture != null and texture.get_size() == Vector2(image.get_size()):
		texture.update(image)
	else:
		texture = ImageTexture.create_from_image(image)
	entries[0].material.set_shader_parameter("vfx_contour_segments", texture)
	entries[0].material.set_shader_parameter("vfx_contour_count", segments.size())
	entries[0].node.show()
	admitted_geometry = true
	last_key = key.duplicate()
	uploads += 1
