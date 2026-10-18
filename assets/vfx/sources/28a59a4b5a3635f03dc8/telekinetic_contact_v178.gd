extends "res://assets/vfx/sources/fe7cf3f5da5d199ca45a/telekinetic_contact_v177.gd"
## V177 is frozen. This revision locks the admitted rigid contact basis and
## exposes the original shader's final alpha to the existing occurrence owner.
const NativeOpacity = preload("res://assets/vfx/sources/39f30ee3f172ac269cd6/native_opacity.gd")
const SourceMaterials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
var admitted_basis := Basis.IDENTITY
var orientation_admitted: bool = false
var source_material_equations_preserved: bool = false

static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/28a59a4b5a3635f03dc8/telekinetic_contact_v178.gd", input)

func apply_scene_edits(node: Node) -> void:
	super.apply_scene_edits(node)
	var source_codes: Array[String] = []
	for material in mats:
		source_codes.append(SourceMaterials.expand_shader(material.shader.code, material.shader.resource_path.get_base_dir()))
	NativeOpacity.apply(subject)
	source_material_equations_preserved = not source_codes.is_empty()
	for index in mats.size():
		var recovered: String = mats[index].shader.code.replace("\nuniform float factory_occurrence_alpha=1.0;\n", "")
		recovered = recovered.replace("\nALPHA *= factory_occurrence_alpha;\n", "")
		source_material_equations_preserved = source_material_equations_preserved and recovered == source_codes[index]

func _fit() -> void:
	super._fit()
	contact_observation.orientation_locked_at_admission = orientation_admitted
	if not contact_observation.get("fit_valid", false):
		return
	if not orientation_admitted:
		admitted_basis = subject.global_basis
		orientation_admitted = true
	var midpoint: Vector3 = (contact_observation.thumb_target + contact_observation.index_target) * 0.5
	var reference_midpoint: Vector3 = (reference.thumb + reference.index) * 0.5
	subject.global_transform = Transform3D(admitted_basis, midpoint - admitted_basis * reference_midpoint)
	var actual_thumb: Vector3 = subject.global_transform * grip_surface.position(reference.thumb_vertex)
	var actual_index: Vector3 = subject.global_transform * grip_surface.position(reference.index_vertex)
	contact_observation.merge({"orientation_locked_at_admission":true,
		"admitted_basis":str(admitted_basis),"measured_midpoint":midpoint,
		"actual_thumb_pad":actual_thumb,"actual_index_pad":actual_index,
		"thumb_gap_cells":actual_thumb.distance_to(contact_observation.thumb_target),
		"index_gap_cells":actual_index.distance_to(contact_observation.index_target)},true)
	var thumb_nearest := INF
	var index_nearest := INF
	for point in endpoints[0].surface.points:
		if point.get("slot", "") not in ["head", "helmet"]:
			continue
		thumb_nearest = minf(thumb_nearest, actual_thumb.distance_to(point.position))
		index_nearest = minf(index_nearest, actual_index.distance_to(point.position))
	contact_observation.thumb_nearest_named_head_support_cells = thumb_nearest
	contact_observation.index_nearest_named_head_support_cells = index_nearest
	set_meta("telekinetic_contact_v178",contact_observation)

func capture_observation() -> Dictionary:
	var result: Dictionary = contact_observation.duplicate(true)
	result.material_occurrence_alpha = float(mats[0].get_shader_parameter(NativeOpacity.UNIFORM)) if not mats.is_empty() else 0.0
	result.source_material_equations_preserved = source_material_equations_preserved
	result.render_visible = subject.is_visible_in_tree() if subject != null else false
	return {"telekinetic_contact_v178":result}
