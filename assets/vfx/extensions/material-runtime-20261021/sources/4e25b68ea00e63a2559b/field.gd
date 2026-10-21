extends Node3D
## Only the actual backend side sections, with original prepared force finish.
const CageInput = preload("res://assets/vfx/extensions/owner-fields-v2-20261021/sources/85d97d458c33910ca580/input.gd")
const SolidInput = preload("res://assets/vfx/extensions/owner-fields-v2-20261021/sources/04632730a28d130e2df3/input.gd")
const Readiness = preload("res://assets/vfx/extensions/production-review-20261020/sources/7dd1897cdd5ee8a903b9/source_readiness.gd")
var bank: Resource
var actual := {}
var current := {}
var state := {}
var input_error := ""
var placement_valid := false
var pieces: Array[GeometryInstance3D] = []
var materials: Array[ShaderMaterial] = []
var mask: ImageTexture

static func preparation_resources(input: Dictionary) -> Array:
	return [str(input.get("observed_cage_bank", ""))]

static func make_component(input: Dictionary) -> Node3D:
	var prepared: Resource = Readiness.resources.get(str(input.get("observed_cage_bank", "")))
	if prepared == null or not prepared.interface_ready:
		return null
	var construction := CageInput.construction(input, prepared.form)
	if not construction.error.is_empty():
		return null
	var node: Node3D = VfxPackageIO_4e25b68ea0.resource("res://assets/vfx/extensions/material-runtime-20261021/sources/4e25b68ea00e63a2559b/field.gd").new()
	node.bank = prepared
	node.actual = construction
	node.mask = ImageTexture.create_from_image(Image.create_empty(1, 1, false, Image.FORMAT_R8))
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
		node.pieces.append(piece)
		piece.hide()
	node.hide()
	return node

func source_bindings() -> Dictionary:
	return {"geometry":pieces, "materials":materials, "lights":[], "players":[], "static_material_topology":true, "static_geometry_layers":true}

func prepare_source_layer_mask(value: int) -> void:
	for piece: GeometryInstance3D in pieces:
		piece.layers = value

func set_zone_geometry(value: Dictionary) -> bool:
	current = CageInput.observation(value, actual)
	input_error = current.error
	if not input_error.is_empty():
		current = {}
		hide()
		return false
	var image := Image.create_empty(current.size.x, current.size.y, false, Image.FORMAT_R8)
	for cell: Vector2i in current.cells:
		var pixel: Vector2i = cell - current.minimum
		image.set_pixel(pixel.x, pixel.y, Color.WHITE)
	mask.set_image(image)
	for index in pieces.size():
		var section := SolidInput.section_for(actual.modules[index], current.sections)
		pieces[index].visible = not section.is_empty()
		var cuts := PackedVector4Array()
		if not section.is_empty():
			for cut: Dictionary in section.get("removed_sections", []):
				cuts.append(Vector4(float(cut.minimum_position[0]) - actual.anchor.x - 0.5,
					float(cut.base_height_steps) - float(actual.area.base_height_steps),
					float(cut.minimum_position[1]) - actual.anchor.y - 0.5, 0.0))
		var count := cuts.size()
		cuts.resize(SolidInput.MAX_CUTS)
		materials[index].set_shader_parameter("cage_cut_count", count)
		materials[index].set_shader_parameter("cage_cuts", cuts)
		materials[index].set_shader_parameter("cage_mask_origin", Vector2(current.minimum))
		materials[index].set_shader_parameter("cage_mask_size", Vector2(current.size))
	return true

func set_owner_state(value: Dictionary) -> bool:
	input_error = SolidInput.owner_state(value, actual.owner)
	if not input_error.is_empty():
		state = {}
		hide()
		return false
	state = value.duplicate(true)
	if not state.present or not state.observed or state.suppressed:
		hide()
	return true

func set_live_endpoints(value: Array) -> void:
	placement_valid = not value.is_empty() and value[0] is Dictionary and value[0].get("point") is Vector3 and value[0].point.is_finite()
	if placement_valid:
		global_position = value[0].point
	else:
		hide()

func refresh_live_inputs(seconds: float) -> void:
	sample(seconds)

func sample(seconds: float) -> void:
	visible = is_finite(seconds) and seconds >= 0.0 and placement_valid and not current.is_empty() and not current.cells.is_empty() \
		and not state.is_empty() and state.present and state.observed and not state.suppressed
	if not visible:
		return
	var age: float = float(state.owner_age_seconds)
	var envelope: float = smoothstep(0.0, bank.apply_seconds, age) * bank.opacity
	var inverse := Projection(global_transform.affine_inverse())
	for index in materials.size():
		materials[index].set_shader_parameter("field_clock", age + bank.phase_offset_seconds)
		materials[index].set_shader_parameter("cage_world_to_local", inverse)
		pieces[index].set_instance_shader_parameter("forcecage_section_opacity", envelope)

func capture_observation() -> Dictionary:
	return {"owner_uuid":actual.owner, "form":bank.form, "actual_side_draws":pieces.size(),
		"visible_sides":pieces.filter(func(piece: GeometryInstance3D) -> bool: return piece.visible).size(),
		"roof_draws":0, "floor_draws":0, "vertical_review_splits":0, "section_uuids_required":false,
		"owner_age_seconds":state.get("owner_age_seconds"), "active":visible, "error":input_error}

const VfxPackageIO_4e25b68ea0 = preload("res://assets/vfx/extensions/material-runtime-20261021/scoped_resource_io.gd")
