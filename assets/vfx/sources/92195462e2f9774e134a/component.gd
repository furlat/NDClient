extends Node3D
## A finite exact attack contact. Gameplay/event routing and target anchoring
## remain production-owned. This source creates no weapon, condition or lamp.
var style: Resource
var materials: Array[ShaderMaterial] = []
var optical_normal_materials: Array[ShaderMaterial] = []
var draws: Array[MeshInstance3D] = []
var impact: Dictionary = {}
var occurrence_key: Array = []
var placement_ready := false
var retired := false
var source_seconds := 0.0
var last_clock := -INF
var rejection := "weapon_impact_missing"
var surface: Dictionary = {}
var authored_root := Transform3D.IDENTITY
var frozen_root := Transform3D.IDENTITY
var anchor_locked := false
var clearance := "clearance_unqualified"
var clearance_reason := "contact_not_sampled"
var selected_optical_point: Dictionary = {}
var optical_points_examined := 0


static func preparation_resources(input: Dictionary) -> Array:
	return [str(input.style)]


static func make_component(input: Dictionary) -> Node3D:
	var definition: Resource = VfxPackageIO_92195462e2.resource(str(input.style))
	assert(definition != null and definition.validate().is_empty(), "Prepared weapon contact style must validate before publication")
	var component: Node3D = VfxPackageIO_92195462e2.resource("res://assets/vfx/sources/92195462e2f9774e134a/component.gd").new()
	component.style = definition
	return component


func _ready() -> void:
	for layer in style.layers:
		var material: ShaderMaterial = layer.material.duplicate(false)
		var draw := MeshInstance3D.new()
		draw.name = layer.layer_id
		draw.mesh = layer.mesh
		draw.material_override = material
		draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		draw.custom_aabb = AABB(Vector3.ONE * -.8, Vector3.ONE * 1.6)
		draw.hide()
		add_child(draw)
		materials.append(material)
		# Explicit prepared topology; never reflect shader source/uniforms in
		# occurrence construction or the contact sampling hot path.
		if bool(layer.material.get_meta("contact_optical_normal", false)):
			optical_normal_materials.append(material)
		draws.append(draw)


func set_weapon_impact(value: Dictionary) -> bool:
	impact = {}
	if retired or not _valid_packet(value):
		_hide("weapon_impact_unavailable")
		return false
	var key: Array = [value.operation_sequence, value.occurrence, value.lineage,
		value.source_item_uuid, value.source_item_id, value.weapon_slot,
		value.source_entity_uuid, value.target_entity_uuid]
	if not occurrence_key.is_empty() and occurrence_key != key:
		_hide("weapon_impact_occurrence_changed")
		return false
	occurrence_key = key.duplicate(true)
	impact = value.duplicate(true)
	# Two authored mirrored/rotated variants, deterministically selected from
	# the actual attack identity. No fabricated hit, random history or timer.
	var variant := float(abs(hash(occurrence_key)) % 2)
	for material in materials:
		material.set_shader_parameter("contact_variant", variant)
	rejection = "" if placement_ready else "root_path_missing"
	_update_visibility()
	return true


func _valid_packet(value: Dictionary) -> bool:
	if typeof(value.get("operation_sequence")) != TYPE_INT or int(value.operation_sequence) < 0:
		return false
	for field in ["occurrence", "lineage", "source_item_uuid", "source_item_id", "source_entity_uuid", "target_entity_uuid"]:
		if not value.get(field) is String or str(value[field]).is_empty():
			return false
	return value.get("attack_outcome") in ["Hit", "Crit"] \
		and value.get("weapon_slot") in ["MELEE_MAIN", "MELEE_OFF", "RANGED_MAIN", "RANGED_OFF"]


func set_root_path(value: Transform3D) -> void:
	placement_ready = value.origin.is_finite() and value.basis.x.is_finite() \
		and value.basis.y.is_finite() and value.basis.z.is_finite()
	if not placement_ready:
		_hide("root_path_non_finite")
		return
	authored_root = value
	global_transform = frozen_root if anchor_locked else value
	_update_visibility()


func set_entity_geometry(value: Dictionary) -> void:
	# A finite impact retains its original surface contact. Changed poses do not
	# attach an already emitted strike to a later body or request another scan.
	if not anchor_locked:
		surface = value


func _freeze_contact_anchor() -> void:
	anchor_locked = true
	frozen_root = authored_root
	clearance = "clearance_unqualified"
	clearance_reason = "optical_surface_not_requested"
	if not style.use_optical_surface:
		return
	clearance_reason = "recipient_geometry_missing"
	if surface.is_empty():
		return
	var actual_actor: String = str(surface.get("actor_uuid", surface.get("actor", "")))
	if actual_actor != impact.target_entity_uuid:
		clearance_reason = "recipient_geometry_owner_mismatch"
		return
	if not bool(surface.get("ready", true)):
		clearance_reason = "recipient_geometry_unavailable"
		return
	var closest := INF
	for point in surface.get("points", []):
		if not point is Dictionary:
			continue
		var position: Variant = point.get("position")
		var normal: Variant = point.get("normal")
		if not position is Vector3 or not normal is Vector3 \
			or not position.is_finite() or not normal.is_finite() or normal.length_squared() < .000001:
			continue
		optical_points_examined += 1
		var distance: float = position.distance_squared_to(authored_root.origin)
		if distance < closest:
			closest = distance
			selected_optical_point = {"position": position, "normal": normal.normalized(),
				"slot": point.get("slot", ""), "pixel": point.get("pixel"), "distance_squared": distance}
	if selected_optical_point.is_empty():
		clearance_reason = "recipient_geometry_has_no_valid_surface_point"
		return
	# One actual rendered optical point, not a centroid, averaged normal,
	# inferred physical hit or a camera-directed global front shift.
	frozen_root.origin = selected_optical_point.position + selected_optical_point.normal * .015
	global_transform = frozen_root
	# Only the prepared flame tongues opt in. Their geometric bend uses this
	# one real world normal, never a camera-facing guess or later actor pose.
	for material in optical_normal_materials:
		material.set_shader_parameter("contact_surface_normal_world", selected_optical_point.normal)
	clearance = "optical_surface_frozen"
	clearance_reason = ""


func sample(seconds: float) -> void:
	source_seconds = seconds
	if not anchor_locked and not retired and placement_ready and not impact.is_empty() \
		and is_finite(seconds) and seconds >= 0.0 and seconds < style.duration_seconds:
		_freeze_contact_anchor()
	if is_finite(seconds) and last_clock != seconds:
		for material in materials:
			material.set_shader_parameter("contact_seconds", seconds)
		last_clock = seconds
	_update_visibility()


func _update_visibility() -> void:
	var visible: bool = not retired and placement_ready and anchor_locked and not impact.is_empty() \
		and is_finite(source_seconds) and source_seconds >= 0.0 and source_seconds < style.duration_seconds
	for draw in draws:
		draw.visible = visible
	if visible:
		rejection = ""


func _hide(reason: String) -> void:
	rejection = reason
	for draw in draws:
		draw.hide()


func clear() -> void:
	retired = true
	impact.clear()
	_hide("retired")


func source_bindings() -> Dictionary:
	return {"geometry": draws, "materials": materials, "lights": [], "static_material_topology": true}


func capture_observation() -> Dictionary:
	return {"weapon_contact": {"element": style.element, "strength": style.strength,
		"source_seconds": source_seconds, "finite_seconds": style.duration_seconds,
		"packet": impact.duplicate(true), "rejection": rejection, "placement_ready": placement_ready,
		"clearance": clearance, "clearance_reason": clearance_reason, "anchor_locked": anchor_locked,
		"selected_optical_point": selected_optical_point.duplicate(true), "optical_points_examined": optical_points_examined,
		"authored_root": authored_root, "frozen_root": frozen_root,
		"visible_draws": draws.filter(func(draw: MeshInstance3D) -> bool: return draw.visible).size(),
		"source_layers": draws.size(), "optical_normal_layers": optical_normal_materials.size(),
		"surface_bend_qualified": clearance == "optical_surface_frozen" and not optical_normal_materials.is_empty(),
		"owns_gameplay_damage": false, "lights": 0,
		"per_frame_cpu_geometry": false, "art_status": style.art_status}}

const VfxPackageIO_92195462e2 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
