extends Node3D
## Existing v41 native source, explicitly attached to one disclosed actual item.
const NativeComposition = preload("res://assets/vfx/extensions/production-review-20261020/sources/0738ff2d24aa41b1b963/native_review_composition.gd")
const NativeOpacity = preload("res://assets/vfx/sources/39f30ee3f172ac269cd6/native_opacity.gd")
const FinishResponse = preload("res://assets/vfx/sources/ac0498530fe3f2aa918a/item_flame_source_finish.gd")
var settings: Dictionary = {}
var packet: Dictionary = {}
var source: Node3D
var source_seconds := 0.0
var occurrence_alpha := 0.0
var rejection := "unbound_actual_item"
var materials: Array = []
var item_particle_bindings: Array = []


static func make_component(input: Dictionary) -> Node3D:
	for field in ["item_uuid", "effect_uuid", "behavior_id", "holder_uuid", "source_definition"]:
		assert(input.has(field))
	var instance := preload("res://assets/vfx/extensions/production-review-20261020/sources/63efbe77094fc90312ab/item_flame.gd").new()
	instance.settings = input.duplicate(true)
	return instance


func set_item_snapshot(value: Dictionary) -> void:
	packet = value.duplicate(true)
	if source != null:
		refresh_item_binding()


func refresh_item_binding() -> void:
	# A paused source may keep its age while the disclosed owner/visibility or
	# actual item transform changes. Update only placement/visibility uniforms.
	occurrence_alpha = 1.0 if admitted() else 0.0
	for material: ShaderMaterial in materials:
		material.set_shader_parameter(NativeOpacity.UNIFORM, occurrence_alpha)
	for material: ShaderMaterial in source.source_materials:
		material.set_shader_parameter("factory_world_to_source", Projection(source.global_transform.affine_inverse()))


static func normalized_item_transform(source_world: Transform3D, emitter_world: Transform3D) -> Transform3D:
	# The original world-particle renderer normalized these display axes. Local
	# attachment must retain that same source-relative basis without inheriting
	# intrinsic donor scale a second time. Preserve the exact emission origin.
	var relative: Basis = source_world.basis.inverse() * emitter_world.basis
	return Transform3D(source_world.basis * relative.orthonormalized(), emitter_world.origin)


func _prepare() -> void:
	if source != null:
		return
	var definition: Dictionary = settings.source_definition.duplicate(true)
	definition.opacity_control = true
	source = NativeComposition.make_component(definition)
	add_child(source)
	source.sample(0.0)
	# Item-clump binding: particles follow this retained real item, including
	# existing particles born before its genuine movement/cover transition.
	# This precedes the outer native sampler's ParticleUnits preparation.
	for emitter: GPUParticles3D in source.find_children("*", "GPUParticles3D", true, false):
		var original: Transform3D = emitter.global_transform
		var relative: Transform3D = source.global_transform.affine_inverse() * original
		emitter.global_transform = normalized_item_transform(source.global_transform, original)
		emitter.local_coords = true
		item_particle_bindings.append({"path": str(source.get_path_to(emitter)),
			"source_relative_before": relative, "local_transform_after": emitter.transform,
			"normalized_once_at_source_tick": 0, "root_registration_not_folded_into_source": true})
	for component in source.composition.components.values():
		materials.append_array(component.materials)
	for material: ShaderMaterial in materials:
		FinishResponse.apply(material, settings.finish_response)
	# The source scene has no Light3D. Fail rather than inventing item light.
	assert(source.find_children("*", "Light3D", true, false).is_empty())


func admitted() -> bool:
	rejection = "actual_item_identity"
	for field in ["item_uuid", "effect_uuid", "behavior_id", "actor_id"]:
		var expected: String = str(settings.holder_uuid) if field == "actor_id" else str(settings[field])
		if str(packet.get(field, "")) != expected:
			return false
	var raw_facts: Variant = packet.get("facts", {})
	rejection = "invalid_fact_container"
	if not raw_facts is Dictionary:
		return false
	var facts: Dictionary = raw_facts
	rejection = "invalid_fact_boolean"
	for field in ["observed", "admitted", "condition_present", "covered", "suppressed", "item_visible"]:
		if facts.has(field) and typeof(facts[field]) != TYPE_BOOL:
			return false
	rejection = "unobserved_item_condition"
	if not bool(facts.get("observed", false)) or not bool(facts.get("admitted", false)):
		return false
	if str(facts.get("item_uuid", "")) != str(settings.item_uuid) or str(facts.get("effect_uuid", "")) != str(settings.effect_uuid):
		return false
	if not bool(facts.get("condition_present", false)):
		rejection = "owner_removed"
		return false
	if bool(facts.get("covered", false)) or bool(facts.get("suppressed", false)) or not bool(facts.get("item_visible", false)):
		rejection = "covered_suppressed_or_unseen"
		return false
	if not bool(packet.get("socket_found", false)) or int(packet.get("normal_support_points", 0)) <= 0:
		rejection = "actual_item_socket_or_support_missing"
		return false
	rejection = ""
	return true


func sample(seconds: float) -> void:
	_prepare()
	source_seconds = maxf(0.0, seconds)
	# Keep the original source advancing while covered/suppressed. Visibility
	# changes never rebuild particles, replace the owning item or reset its clock.
	source.sample(source_seconds)
	refresh_item_binding()


func capture_observation() -> Dictionary:
	var flame: Node = source.composition.components.effect if source != null else null
	return {"owner_kind": "actual_existing_item", "item_uuid": settings.item_uuid, "effect_uuid": settings.effect_uuid,
		"behavior_id": settings.behavior_id, "holder_uuid": settings.holder_uuid,
		"actual_renderer_item_uuid": packet.get("item_uuid", ""), "facts": packet.get("facts", {}),
		"socket_found": packet.get("socket_found", false), "socket_reason": packet.get("reason", ""),
		"socket_world": packet.get("point", Vector3.ZERO), "socket_screen": packet.get("screen", Vector2.ZERO),
		"socket_source_pixel": packet.get("pixel", Vector2.ZERO), "socket_source_box": packet.get("box", Rect2i()),
		"source_paths": packet.get("source_paths", []), "actual_item_optical_depth": packet.get("actual_item_optical_depth", false),
		"normal_support_points": packet.get("normal_support_points", 0), "rejection": rejection,
		"source_seconds": source_seconds, "occurrence_alpha": occurrence_alpha,
		"native_source_tick": flame.tick if flame != null else -1, "native_source_settings": flame.settings if flame != null else {},
		"source_frame_not_reset_on_visibility": true, "particle_binding_normalizations": item_particle_bindings, "physical_item_replaced": false,
		"heatless": true, "combustion_or_damage": false, "new_light_or_gameplay_rules": false,
		"new_item_or_floor_proxy": false, "source_scale_retained": true, "source_finish_response": settings.finish_response, "post_raster_finish_parity": false}
