extends "res://assets/vfx/extensions/production-review-20261020/sources/8cae7b7f38ac851d8084/wind.gd"
## Same live wall controller and native writer, with maskable debris display.
## Coverage stays owned by the existing external observed-cell mask.


static func preparation_resources(input: Dictionary) -> Array:
	return [str(input.wind_bank)]


static func make_component(input: Dictionary) -> Node3D:
	var context := WallInput.construction(input, "wind")
	var prepared: Resource = Readiness.resources.get(str(input.get("wind_bank", "")))
	if not context.error.is_empty() or prepared == null or not prepared.get("interface_ready"):
		return null
	if prepared.get("debris_material") == null:
		return null
	var node: Node3D = VfxPackageIO_ed9721fee0.resource("res://assets/vfx/extensions/speed-completion-20261021/sources/ed9721fee057f6041013/wind.gd").new()
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
	node.hide()
	return node


var initial_display: ShaderMaterial


func _draw(mesh: Mesh, material: Material, label: String) -> MeshInstance3D:
	# Preserve every native draw/order. Avoid the unused intermediate native
	# StandardMaterial assignment; the same private Shader is displayed first.
	if material == feed_mat:
		if initial_display == null:
			initial_display = bank.debris_material.duplicate(false)
		return super._draw(mesh, initial_display, label)
	return super._draw(mesh, material, label)


func _mirror_native_albedo() -> bool:
	# Original live sample writes this native Color property directly. The
	# native gate compares its exact Variant bytes against the original RID
	# operand before source qualification; no gamma/type conversion is added.
	var value: Variant = feed_mat.albedo_color
	if value == null:
		state_error = "Actual native Wind debris albedo operand is missing"
		hide()
		return false
	var previous: ShaderMaterial
	for draw: MeshInstance3D in debris:
		var material: Material = draw.material_override
		if not material is ShaderMaterial or material.shader == null:
			state_error = "Current Wind debris display is not maskable"
			hide()
			return false
		if material != previous:
			material.set_shader_parameter(bank.albedo_uniform, value)
			previous = material
	return true


func sample(seconds: float) -> void:
	super.sample(seconds)
	if not is_finite(seconds):
		return
	_mirror_native_albedo()


func source_bindings() -> Dictionary:
	var current: Array[ShaderMaterial] = []
	current.assign(source_materials)
	for draw: MeshInstance3D in debris:
		var material: Material = draw.material_override
		if material is ShaderMaterial and material not in current:
			current.append(material)
	return {"geometry": geometry, "materials": current, "static_material_topology": true}


func capture_observation() -> Dictionary:
	var result := super.capture_observation()
	result.debris_display = "exact_native_spatial_shader_private_maskable_material"
	result.current_coverage_owner = "existing_external_observed_cell_mask"
	result.additional_source_setter_required = false
	return result

const VfxPackageIO_ed9721fee0 = preload("res://assets/vfx/extensions/speed-completion-20261021/scoped_resource_io.gd")
