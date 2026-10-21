extends Node3D
## Explicit supplied cast/recipient/condition owners around preserved source art.
## This fixture never computes HP, saves, death, conditions or game admission.
const DIVINE = preload("res://assets/vfx/extensions/source-preparation-20261020/sources/eedda20055dc5e56e110/divine.gd")
const OPACITY = preload("res://assets/vfx/extensions/source-preparation-20261020/sources/90ab1e201f20b54152c8/native_opacity.gd")
const EFFECTIVE_OUTCOMES := ["deafened", "blinded_deafened", "blinded_deafened_stunned", "death"]
var settings: Dictionary = {}
var observation: Dictionary = {}
var endpoints: Array = []
var source: Node3D
var source_materials: Array[ShaderMaterial] = []
var source_zero_transforms: Dictionary = {}
var source_zero_emitters: Dictionary = {}
var source_zero_shaders: Array = []
var age_seconds: float = -1.0
var removed_at: float = -1.0
var envelope: float = 0.0
var reset_count: int = 0
var ground_world: Vector3 = Vector3.ZERO
var measured_head_points: int = 0

static func make_component(input: Dictionary) -> Node3D:
	var component: Node3D = VfxPackageIO_48a058cfc0_edb4416ff0.resource("res://assets/vfx/extensions/source-preparation-20261020/sources/48a058cfc078db3bd334/divine_word_source_v196.gd").new()
	component.settings = input.duplicate(true)
	component.observation = input.observation.duplicate(true)
	return component

func matches(value: Dictionary) -> bool:
	for key in ["event_uuid", "cast_uuid", "source_entity_uuid", "target_entity_uuid"]:
		if str(value.get(key, "")).is_empty() or str(value.get(key, "")) != str(settings.owner[key]):
			return false
	return typeof(value.get("admitted")) == TYPE_BOOL and value.admitted \
		and typeof(value.get("canceled")) == TYPE_BOOL and not value.canceled

func admitted() -> bool:
	if not matches(observation):
		return false
	if settings.role == "proclamation":
		return observation.get("phase", "") == "completion"
	if settings.role == "recipient":
		return observation.get("phase", "") == "effect" \
			and typeof(observation.get("affected")) == TYPE_BOOL and observation.affected \
			and EFFECTIVE_OUTCOMES.has(observation.get("outcome", ""))
	var lease: Dictionary = observation.get("condition", {})
	return observation.get("phase", "") == "effect" and lease.get("condition_uuid", "") == settings.owner.condition_uuid \
		and lease.get("content_id", "") == settings.owner.condition_id \
		and typeof(lease.get("effective")) == TYPE_BOOL and lease.effective \
		and typeof(lease.get("suppression_provider_uuids")) == TYPE_ARRAY and lease.suppression_provider_uuids.is_empty()

func set_observation(value: Dictionary) -> bool:
	if not matches(value):
		return false
	observation = value.duplicate(true)
	sample(age_seconds)
	return true

func remove_owner(owner_uuid: String, source_seconds: float) -> bool:
	if owner_uuid != str(settings.owner.owner_uuid):
		return false
	removed_at = source_seconds
	sample(age_seconds)
	return true

func set_live_endpoints(value: Array) -> void:
	endpoints = value

func _build() -> void:
	source = DIVINE.make_component(settings.source)
	source.name = "PreservedDivineSource"
	add_child(source)
	source.sample(0.0)
	# Exact equation at the uncaptured zero boundary; no .85-scale proclamation
	# birth flash before its original envelope/scale equation's first144Hz tick.
	source.tick = -1
	source.advance_lifecycle(0.0)
	for light in source.find_children("*", "Light3D", true, false):
		# Retained donor geometry fill cannot become new actor/floor illumination.
		light.set_meta("factory_light_role", "geometry_only")
	for node in source.find_children("*", "Node3D", true, false):
		source_zero_transforms[str(source.get_path_to(node))] = node.transform
		if node is GPUParticles3D:
			source_zero_emitters[str(source.get_path_to(node))] = node.emitting
	for material in source.materials:
		source_zero_shaders.append(material.shader.code)
	OPACITY.apply(source)
	source_materials = source.materials

func _reset() -> void:
	for path in source_zero_transforms:
		source.get_node(path).transform = source_zero_transforms[path]
	for player in source.find_children("*", "AnimationPlayer", true, false):
		if not str(source.settings.animation).is_empty() and player.has_animation(source.settings.animation):
			player.play(source.settings.animation)
			player.seek(0.0, true, true)
	for path in source_zero_emitters:
		var emitter: GPUParticles3D = source.get_node(path)
		emitter.emitting = source_zero_emitters[path]
		emitter.restart(true)
	source.tick = -1
	source.advance_lifecycle(0.0)
	reset_count += 1

func _anchor() -> bool:
	if endpoints.is_empty():
		return false
	ground_world = endpoints[0].point
	if settings.role != "condition":
		return true
	if endpoints.size() < 2:
		return false
	var head: Vector3 = endpoints[1].point
	var head_surface: Dictionary = endpoints[1].get("surface", {})
	var points: Array = head_surface.get("points", [])
	measured_head_points = points.size()
	if points.is_empty():
		return false
	var top: float = head.y
	for point in points:
		top = maxf(top, point.position.y)
	var stack: Array = settings.stack_offset_world
	# Pose socket supplies head centre; real current head/helmet support supplies
	# top clearance. Explicit fixture stack vector comes from accepted32px gap.
	var anchor := Vector3(head.x, top + float(settings.head_clearance_cells), head.z) + Vector3(stack[0], stack[1], stack[2])
	source.position = to_local(anchor)
	return true

func sample(seconds: float) -> void:
	if source == null:
		_build()
	if seconds < age_seconds - .0000001:
		_reset()
	age_seconds = seconds
	envelope = 1.0
	var removal: float = float(settings.remove_at_seconds)
	if removed_at >= 0.0:
		removal = minf(removal, removed_at)
	if settings.role == "condition":
		envelope = clampf(1.0 - (seconds - removal) / float(settings.clear_seconds), 0.0, 1.0)
	elif removed_at >= 0.0:
		envelope = 0.0 if seconds >= removed_at else 1.0
	var bound: bool = _anchor()
	visible = admitted() and bound and seconds >= 0.0 and seconds < float(settings.seconds) and envelope > 0.0
	source.visible = visible
	if visible:
		source.sample(seconds)
	for material in source_materials:
		material.set_shader_parameter(OPACITY.UNIFORM, envelope)

func capture_observation() -> Dictionary:
	return {"family": "original_divine_word_source", "role": settings.role, "owner": settings.owner.duplicate(true),
		"admitted": admitted(), "visible": visible, "visible_in_tree": is_visible_in_tree(), "source_seconds": age_seconds,
		"source_tick": source.tick if source != null else 0, "occurrence_alpha": envelope,
		"source_visible": source != null and source.is_visible_in_tree(), "reset_count": reset_count,
		"ground_world": [ground_world.x, ground_world.y, ground_world.z], "head_support_points": measured_head_points,
		"source_world": [source.global_position.x, source.global_position.y, source.global_position.z] if source != null else [],
		"outcome": observation.get("outcome", ""), "condition_id": settings.owner.get("condition_id", ""),
		"independent_parent_lifetime": true, "HP_or_save_solver": false, "damage_applied": false,
		"source_materials": source_materials.size(), "source_raw_shader_programs": source_zero_shaders.size()}

const VfxPackageIO_48a058cfc0_edb4416ff0 = preload("res://assets/vfx/extensions/source-preparation-20261020/sources/249140d21848f6d0bd2b/resource_io.gd")
