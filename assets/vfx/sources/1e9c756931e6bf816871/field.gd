extends "res://assets/vfx/sources/5727c50ba70a286b83d5/forcecage.gd"
## Exact source owner/section equations, with private per-instance envelopes.
const Bank = preload("res://assets/vfx/sources/4132372f553a42460672/bank.gd")
const Profile = preload("res://assets/vfx/sources/5e6062cb1efe781a65b7/construction_profile.gd")
var bank: Resource
var field_material: ShaderMaterial

static func preparation_resources(input: Dictionary) -> Array:
	return [str(input.forcecage_bank)]

static func make_component(input: Dictionary) -> Node3D:
	assert(input.form in ["cage", "box"] and not str(input.owner_uuid).is_empty())
	var prepared: Resource = VfxPackageIO_1e9c756931.resource(str(input.forcecage_bank))
	assert(prepared != null and prepared.material != null)
	assert(prepared.interface_ready, "Complete immutable section preparation before publishing an occurrence")
	assert(prepared.provenance.get("source_section_opacity_instance_uniform") == "forcecage_section_opacity",
		"Prepare the current exact section-instance material interface")
	assert(input.material == prepared.material_specification,
		"Changed native Forcecage donor finish needs explicit immutable preparation")
	var node: Node3D = VfxPackageIO_1e9c756931.resource("res://assets/vfx/sources/1e9c756931e6bf816871/field.gd").new()
	node.bank = prepared
	node.specification = input.duplicate(true)
	node.sections = node.specification.sections
	Profile.begin("forcecage_private_material_duplicate")
	node.field_material = prepared.material.duplicate(false)
	Profile.end("forcecage_private_material_duplicate")
	var identities := {}
	for section in node.sections:
		assert(not identities.has(section.uuid))
		identities[section.uuid] = true
		Profile.begin("forcecage_source_geometry_lookup")
		var key := Bank.section_key(str(input.form), section,
			float(input.bar_radius_cells), float(input.trace_spacing_cells))
		Profile.end("forcecage_source_geometry_lookup")
		assert(prepared.geometry.has(key),
			"Changed actual section geometry needs offline preparation; no synchronous donor fallback")
		var piece: GeometryInstance3D
		if input.form == "cage":
			var bars := MultiMeshInstance3D.new()
			bars.multimesh = prepared.published_geometry[key]
			piece = bars
		else:
			var face := MeshInstance3D.new()
			face.mesh = prepared.published_geometry[key]
			piece = face
		piece.name = str(section.uuid).validate_node_name()
		piece.material_override = node.field_material
		piece.set_instance_shader_parameter("forcecage_section_opacity", 0.0)
		piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		piece.top_level = true
		node.add_child(piece)
		piece.hide()
		node.pieces.append(piece)
		node.materials.append(node.field_material)
	return node

func sample(seconds: float) -> void:
	# Same state/clock/envelope equations as the original sample(). Only the
	# section envelope upload moves from24 materials to24 instance operands.
	local_clock = seconds
	if endpoints.is_empty():
		return
	var state: Dictionary = specification.state.duplicate(true)
	for row in specification.get("review_states", []):
		if seconds >= float(row.seconds):
			state.merge(row.state, true)
	if not owner_state.is_empty():
		state = owner_state.duplicate(true)
	var active: bool = str(state.get("owner_uuid", "")) == str(specification.owner_uuid)
	active = active and bool(state.get("present", false)) and bool(state.get("observed", false)) and not bool(state.get("suppressed", true))
	var envelope: float = smoothstep(0.0, float(specification.apply_seconds), seconds) if active else 0.0
	if state.has("ending_started_at"):
		envelope *= 1.0 - smoothstep(0.0, float(specification.retire_seconds), seconds - float(state.ending_started_at))
	field_material.set_shader_parameter("field_clock", seconds + float(specification.get("phase_offset_seconds", 0.0)))
	visible_sections.clear()
	for index in sections.size():
		var opacity := envelope
		var section: Dictionary = sections[index]
		for removal in state.get("section_removals", []):
			if str(removal.uuid) == str(section.uuid):
				opacity *= 1.0 - smoothstep(0.0, float(specification.retire_seconds), seconds - float(removal.started_at))
		pieces[index].global_transform = Transform3D(Basis.IDENTITY, endpoints[0].point)
		pieces[index].visible = opacity > .0001
		pieces[index].set_instance_shader_parameter("forcecage_section_opacity", opacity * float(specification.opacity))
		if pieces[index].visible:
			visible_sections.append(section.uuid)

func source_bindings() -> Dictionary:
	return {"geometry": pieces, "materials": [field_material], "lights": [], "static_material_topology": true}


const VfxPackageIO_1e9c756931 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
