extends "res://assets/vfx/extensions/speed-completion-20261021/sources/ed9721fee057f6041013/wind.gd"
## Every original child name is explicit and unique in the actual constructor.
## The flag is published only after that exact full constructor completes.
var stable_paths_verified := false


static func preparation_resources(input: Dictionary) -> Array:
	return [str(input.wind_bank)]


static func make_component(input: Dictionary) -> Node3D:
	var context := WallInput.construction(input, "wind")
	var prepared: Resource = Readiness.resources.get(str(input.get("wind_bank", "")))
	if not context.error.is_empty() or prepared == null or not prepared.get("interface_ready"):
		return null
	if prepared.get("debris_material") == null:
		return null
	var node: Node3D = VfxPackageIO_8cd20a21e4.resource("res://assets/vfx/extensions/speed-completion-20261021/sources/8cd20a21e46d5895373d/wind.gd").new()
	node.wall_context = context
	node.bank = prepared
	node.parameters = input.duplicate(true)
	node.settings = {"path_points": []}
	for point: Vector2 in context.points:
		node.settings.path_points.append([point.x, point.y])
	node._build()
	for index in range(2, CONTACT_SLOTS * 2):
		node.hit_meshes.append(node._draw(prepared.hit_mesh, node.hit_mats[index % 2], "ActualContact%02d" % index))
	for draw: MeshInstance3D in node.hit_meshes:
		draw.set_instance_shader_parameter("live_contact_envelope", 0.)
	for material: ShaderMaterial in node.mats:
		material.set_shader_parameter("live_wall_height", context.height)
		var offset: float = material.get_shader_parameter("wind_sheet_offset")
		material.set_shader_parameter("wind_sheet_offset", offset * context.width / (CELL / 5.))
	for index in node.flow_draws.size():
		var draw: MeshInstance3D = node.flow_draws[index]
		var segment: Dictionary = node.modules[index]
		var first: Vector3 = segment.start
		var second: Vector3 = segment.end
		var margin: float = maxf(1.3, context.width + .5)
		var minimum := Vector3(minf(first.x, second.x) - margin, -.8, minf(first.z, second.z) - margin)
		var maximum := Vector3(maxf(first.x, second.x) + margin, context.height + .8, maxf(first.z, second.z) + margin)
		draw.custom_aabb = AABB(minimum, maximum - minimum)
	node.stable_paths_verified = true
	node.hide()
	return node



func has_verified_stable_paths() -> bool:
	return stable_paths_verified

const VfxPackageIO_8cd20a21e4 = preload("res://assets/vfx/extensions/speed-completion-20261021/scoped_resource_io.gd")
