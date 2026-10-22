extends Node3D
## Original bark patches at actual disclosed cells. No stored nine-cell layout.
const ZoneInput = preload("res://assets/vfx/extensions/cell-validation-20261021/sources/bbfe0c8c2a4fd1b29e8d/input.gd")
const Leaf = preload("res://assets/vfx/extensions/spike-readiness-20261022/sources/3f7c4d0944341cd9d43c/spike_leaf.gd")
const CONTENT := "spatial_effect.spell.spike_growth"
var owner_uuid := ""
var source_cells: Array[Vector2i] = []
var patches: Dictionary = {}
var state := {}
var current := {}
var state_error := ""
var anchor_world: Variant
var geometry: Array[GeometryInstance3D] = []
var materials: Array[Material] = []


static func preparation_resources(input: Dictionary) -> Array:
	var result: Array = []
	for patch: Dictionary in input.get("patch_sources", []):
		result.append(patch.prepared_recipient_bank)
	result.append("res://assets/vfx/extensions/spike-readiness-20261022/sources/071cb5dfbf5ba3bf7019/owner_release_spike.gd")
	return result


static func make_component(input: Dictionary) -> Node3D:
	var cells := ZoneInput.cells(input.get("cells"))
	if str(input.get("owner_uuid", "")).is_empty() or not cells.error.is_empty() or cells.cells.is_empty():
		return null
	if input.get("patch_sources", []).size() != 9:
		return null
	var node: Node3D = VfxPackageIO_4e595f448d.resource("res://assets/vfx/extensions/spike-readiness-20261022/sources/4e595f448d0154a0b4a2/spike.gd").new()
	node.owner_uuid = input.owner_uuid
	node.source_cells.assign(cells.cells)
	for cell: Vector2i in node.source_cells:
		# These are the nine existing authored variants. Coordinate membership
		# makes a cell retain its variant when observation order changes.
		var variant := posmod(cell.x + 1, 3) + 3 * posmod(cell.y + 1, 3)
		var leaf: Node3D = Leaf.make_component(input.patch_sources[variant])
		leaf.name = "Patch_%s_%s" % [cell.x, cell.y]
		node.add_child(leaf)
		node.patches[cell] = leaf
		var bindings: Dictionary = leaf.source_bindings()
		node.geometry.append_array(bindings.geometry)
		for material: Material in bindings.materials:
			if material not in node.materials:
				node.materials.append(material)
	node.hide()
	return node


func prepare_source_layer_mask(mask: int) -> void:
	for draw: GeometryInstance3D in geometry:
		if draw.layers != 0:
			draw.layers = mask


func source_bindings() -> Dictionary:
	return {"geometry": geometry, "materials": materials, "players": [], "lights": [],
		"static_material_topology": true, "static_geometry_layers": true}


func set_zone_geometry(value: Dictionary) -> bool:
	var actual := ZoneInput.geometry(value, owner_uuid, CONTENT)
	state_error = actual.error
	if state_error.is_empty():
		for cell: Vector2i in actual.cells:
			if cell not in source_cells:
				state_error = "Observed cells exceed this actual constructed topology"
				break
	if not state_error.is_empty():
		current = {}
		hide()
		return false
	current = actual
	return true


func set_owner_state(value: Dictionary) -> bool:
	state_error = ZoneInput.owner_state(value, owner_uuid)
	state = value.duplicate(true) if state_error.is_empty() else {}
	if not ZoneInput.admitted(state):
		hide()
	return state_error.is_empty()


func set_targets(value: Array) -> void:
	anchor_world = ZoneInput.point(value)
	if anchor_world == null:
		hide()


func set_live_endpoints(value: Array) -> void:
	set_targets(value)


func refresh_live_inputs(seconds: float) -> void:
	sample(seconds)


func sample(seconds: float) -> void:
	visible = is_finite(seconds) and seconds >= 0.0 and anchor_world != null and not current.is_empty() and ZoneInput.admitted(state)
	if not visible:
		return
	var age := float(state.owner_age_seconds)
	for cell: Vector2i in source_cells:
		var leaf: Node3D = patches[cell]
		leaf.visible = cell in current.cells
		if not leaf.visible:
			continue
		# Current client grid is one world unit per cell. Convert actual world
		# placement through the real occurrence root; cue scale is not topology.
		leaf.global_transform = Transform3D(Basis.IDENTITY, anchor_world + Vector3(cell.x, 0.0, cell.y))
		leaf.sample(age)
		var inverse := leaf.global_transform.affine_inverse()
		for material: ShaderMaterial in leaf.get_meta("prepared_world_source_materials"):
			material.set_shader_parameter("factory_world_to_source", inverse)


func capture_observation() -> Dictionary:
	return {"owner_uuid": owner_uuid, "state_error": state_error, "source_cells": source_cells,
		"current_cells": current.get("cells", []), "source_age": state.get("owner_age_seconds"),
		"actual_patch_count": patches.size(), "finite_review_expiry": false, "visible": visible}

const VfxPackageIO_4e595f448d = preload("res://assets/vfx/extensions/spike-readiness-20261022/scoped_resource_io.gd")
