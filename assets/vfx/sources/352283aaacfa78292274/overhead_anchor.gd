extends RefCounted
## Fit the existing symbolic mesh to supplied, current head support.
## Camera orientation is explicit input from the host; no camera is created.

var glyph: MeshInstance3D
var clearance_cells: float = 0.12
var observation: Dictionary = {}


func configure(subject: Node3D, settings: Dictionary) -> void:
	clearance_cells = float(settings.get("clearance_cells", 0.12))
	assert(clearance_cells >= 0.0)
	for child in subject.find_children("*", "MeshInstance3D", true, false):
		var material: Material = child.get_active_material(0)
		if material is ShaderMaterial and material.shader.code.contains("uniform int kind"):
			assert(glyph == null, "Overhead source must have exactly one symbolic glyph")
			glyph = child
	assert(glyph != null, "Selected overhead source has no symbolic glyph")


func follow(endpoints: Array) -> void:
	if glyph == null or endpoints.is_empty():
		return
	var endpoint: Dictionary = endpoints[0]
	var head: Vector3 = endpoint.point
	var top: float = head.y
	var surface: Dictionary = endpoint.get("surface", {})
	var points: Array = surface.get("points", [])
	for point in points:
		top = maxf(top, point.position.y)
	assert(endpoint.get("view_basis") is Basis, "Overhead glyph needs the supplied view basis")
	var view: Basis = endpoint.view_basis.orthonormalized()
	var axes: Basis = view.scaled(glyph.global_basis.get_scale())
	var size: Vector2 = glyph.mesh.size
	var half_height: float = (absf(axes.x.y) * size.x + absf(axes.y.y) * size.y) * 0.5
	var centre := Vector3(head.x, top + clearance_cells + half_height, head.z)
	glyph.global_transform = Transform3D(axes, centre)
	observation = {
		"measured_head_points": points.size(),
		"head_top_world_y_cells": top,
		"glyph_bottom_world_y_cells": centre.y - half_height,
		"clearance_cells": centre.y - half_height - top,
		"camera_facing_dot": axes.z.normalized().dot(view.z),
	}
