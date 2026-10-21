extends "res://assets/vfx/extensions/material-runtime-20261021/sources/4e25b68ea00e63a2559b/field.gd"
## Existing native material/geometry, with exact private-operand write elision.
const IndexedInput = preload("res://assets/vfx/extensions/material-runtime-20261021/sources/13b8400c141979446d41/input.gd")
var section_indices := {}
var uniform_values: Array[Dictionary] = []
var mask_data := PackedByteArray()
var mask_size := Vector2i.ONE
var sampled_transform: Transform3D
var has_sampled_transform := false
var sampled_inverse: Projection
var sampled_age := NAN
var sampled_opacity := NAN


static func preparation_resources(input: Dictionary) -> Array:
	return [str(input.get("observed_cage_bank", ""))]


static func make_component(input: Dictionary) -> Node3D:
	var prepared: Resource = Readiness.resources.get(str(input.get("observed_cage_bank", "")))
	if prepared == null or not prepared.interface_ready:
		return null
	var construction := CageInput.construction(input, prepared.form)
	if not construction.error.is_empty():
		return null
	var node: Node3D = VfxPackageIO_3277012ae9.resource("res://assets/vfx/extensions/material-runtime-20261021/sources/3277012ae9c8174aaf96/field.gd").new()
	node.bank = prepared
	node.actual = construction
	node.section_indices = IndexedInput.module_index(construction)
	node.mask_data.resize(1)
	node.mask = ImageTexture.create_from_image(Image.create_empty(1, 1, false, Image.FORMAT_R8))
	# Same actual8/4 side objects, native immutable meshes, private material
	# aliases and exact transforms as the original prepared source.
	for index in construction.modules.size():
		var module: Dictionary = construction.modules[index]
		var piece: GeometryInstance3D
		if prepared.form == "cage":
			var bars := MultiMeshInstance3D.new()
			bars.multimesh = prepared.multimesh
			piece = bars
		else:
			var panel := MeshInstance3D.new()
			panel.mesh = prepared.mesh
			piece = panel
		piece.name = "ActualSide%02d" % index
		node.add_child(piece)
		piece.position = Vector3(module.first.x - construction.anchor.x, 0.0, module.first.y - construction.anchor.y)
		var horizontal := Vector3(module.last.x - module.first.x, 0.0, module.last.y - module.first.y).normalized()
		piece.basis = Basis(horizontal, Vector3.UP, horizontal.cross(Vector3.UP))
		piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material: ShaderMaterial = prepared.material.duplicate(false)
		material.set_shader_parameter("cage_cells", node.mask)
		piece.material_override = material
		piece.set_instance_shader_parameter("forcecage_section_opacity", 0.0)
		node.materials.append(material)
		node.uniform_values.append({})
		node.pieces.append(piece)
		piece.hide()
	node.hide()
	return node


func _uniform(index: int, key: String, value: Variant) -> void:
	if not uniform_values[index].has(key) or uniform_values[index][key] != value:
		materials[index].set_shader_parameter(key, value)
		uniform_values[index][key] = value


func set_zone_geometry(value: Dictionary) -> bool:
	var evaluated := IndexedInput.observation(value, actual, section_indices)
	current = evaluated.observation
	input_error = current.error
	if not input_error.is_empty():
		current = {}
		hide()
		return false
	var bytes := PackedByteArray()
	bytes.resize(current.size.x * current.size.y)
	for cell: Vector2i in current.cells:
		var pixel: Vector2i = cell - current.minimum
		bytes[pixel.y * current.size.x + pixel.x] = 255
	if mask_size != current.size or mask_data != bytes:
		mask.set_image(Image.create_from_data(current.size.x, current.size.y, false, Image.FORMAT_R8, bytes))
		mask_data = bytes
		mask_size = current.size
	for index in pieces.size():
		var section: Dictionary = evaluated.matching[index]
		pieces[index].visible = not section.is_empty()
		var cuts := PackedVector4Array()
		if not section.is_empty():
			for cut: Dictionary in section.get("removed_sections", []):
				cuts.append(Vector4(float(cut.minimum_position[0]) - actual.anchor.x - 0.5,
					float(cut.base_height_steps) - float(actual.area.base_height_steps),
					float(cut.minimum_position[1]) - actual.anchor.y - 0.5, 0.0))
		var count := cuts.size()
		cuts.resize(SolidInput.MAX_CUTS)
		_uniform(index, "cage_cut_count", count)
		_uniform(index, "cage_cuts", cuts)
		_uniform(index, "cage_mask_origin", Vector2(current.minimum))
		_uniform(index, "cage_mask_size", Vector2(current.size))
	return true


func set_live_endpoints(value: Array) -> void:
	placement_valid = not value.is_empty() and value[0] is Dictionary and value[0].get("point") is Vector3 and value[0].point.is_finite()
	if placement_valid:
		if global_position != value[0].point:
			global_position = value[0].point
	else:
		hide()


func sample(seconds: float) -> void:
	visible = is_finite(seconds) and seconds >= 0.0 and placement_valid and not current.is_empty() and not current.cells.is_empty() \
		and not state.is_empty() and state.present and state.observed and not state.suppressed
	if not visible:
		return
	var age: float = float(state.owner_age_seconds)
	var envelope: float = smoothstep(0.0, bank.apply_seconds, age) * bank.opacity
	var transform := global_transform
	var moved := not has_sampled_transform or sampled_transform != transform
	if moved:
		sampled_inverse = Projection(transform.affine_inverse())
		sampled_transform = transform
		has_sampled_transform = true
	for index in materials.size():
		if sampled_age != age:
			materials[index].set_shader_parameter("field_clock", age + bank.phase_offset_seconds)
		if moved:
			materials[index].set_shader_parameter("cage_world_to_local", sampled_inverse)
		if sampled_opacity != envelope:
			pieces[index].set_instance_shader_parameter("forcecage_section_opacity", envelope)
	sampled_age = age
	sampled_opacity = envelope

const VfxPackageIO_3277012ae9 = preload("res://assets/vfx/extensions/material-runtime-20261021/scoped_resource_io.gd")
