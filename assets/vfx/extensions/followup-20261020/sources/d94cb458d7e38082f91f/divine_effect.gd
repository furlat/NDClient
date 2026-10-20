extends "res://assets/vfx/extensions/followup-20261020/sources/2a457ce5caa83a1c9dfb/receiving_effect.gd"
## Presentation projections only. Study contracts select art, not native IDs.
## The owner and accepted outcome are supplied; no game-rule evaluation occurs.
const DivineMaterial = preload("res://assets/vfx/sources/17297e9c25b2f4d4c625/native_material.gd")

static func create(path: String, input: Dictionary) -> Node3D:
	var instance: Node3D = VfxPackageIO_d94cb458d7.resource(path).new()
	instance.settings = input.duplicate(true)
	instance.material = DivineMaterial.make(input.material)
	instance._prepare_pieces(int(input.get("piece_capacity", 0)))
	instance.set_lease_input(input.get("lease", {}))
	instance.set_event_input(input.get("event", {}))
	return instance

func owner_admitted() -> bool:
	for identity in ["owner_uuid", "source_entity_uuid", "recipient_entity_uuid"]:
		if str(settings.get(identity, "")).is_empty():
			return false
	return str(lease.get("owner_uuid", "")) == str(settings.owner_uuid) \
		and str(lease.get("source_entity_uuid", "")) == str(settings.source_entity_uuid) \
		and str(lease.get("target_entity_uuid", "")) == str(settings.recipient_entity_uuid) \
		and str(lease.get("study_contract", "")) == str(settings.study_contract) \
		and bool(lease.get("observed", false)) and bool(lease.get("present", false)) \
		and bool(lease.get("contribution_active", false)) and not bool(lease.get("suppressed", true))


func event_admitted() -> bool:
	for identity in ["event_uuid", "source_entity_uuid", "recipient_entity_uuid"]:
		if str(settings.get(identity, "")).is_empty():
			return false
	return super.event_admitted()


func endpoint(actor: String, socket: String) -> Dictionary:
	# Keep actual packet identity intact. Only the authored role lookup resolves.
	var roles: Dictionary = settings.get("actor_roles", {})
	return super.endpoint(str(roles.get(actor, actor)), socket)

func phase_admitted() -> bool:
	if settings.mode == "hold":
		return owner_admitted()
	if settings.mode in ["retire", "condition_retire"]:
		return event_admitted() and str(event_input.get("removed_owner_uuid", "")) == str(settings.owner_uuid)
	if not event_admitted() or not bool(event_input.get("effect_admitted", false)):
		return false
	if str(settings.get("part", "")) == "revival_dead":
		# Native dead revival commits a life change independently of HealFact.
		return bool(event_input.get("revival_observed", false)) \
			and str(event_input.get("life_before", "")) == "dead" \
			and str(event_input.get("life_after", "")) == "alive" \
			and str(event_input.get("revived_entity_uuid", "")) == str(settings.recipient_entity_uuid) \
			and not str(event_input.get("life_change_event_uuid", "")).is_empty()
	if settings.has("item_owner_uuid"):
		if str(event_input.get("item_uuid", "")) != str(settings.item_owner_uuid) \
			or str(event_input.get("current_wielder_uuid", "")) != str(settings.source_entity_uuid) \
			or not bool(event_input.get("item_contribution_active", false)):
			return false
	match str(settings.get("outcome_kind", "cast")):
		"heal":
			return float(event_input.get("actual_healing", 0.0)) > 0.0 and not bool(event_input.get("blocked", true))
		"damage":
			return float(event_input.get("actual_damage", 0.0)) > 0.0 and not str(event_input.get("damage_component_uuid", "")).is_empty()
		"cure":
			return not event_input.get("removed_condition_uuids", []).is_empty()
		"membership":
			return str(event_input.get("membership_owner_uuid", "")) == str(settings.owner_uuid) \
				and str(event_input.get("membership_feature", "")) == str(settings.study_contract)
		"creation":
			return bool(event_input.get("ordinary_item_admitted", false)) and not str(event_input.get("item_uuid", "")).is_empty()
	return true

func line(points: Array[Vector3], width: float, normal: Vector3 = Vector3.ZERO) -> Dictionary:
	var normals: Array[Vector3] = []
	for point in points:
		normals.append(frame.normal if normal.is_zero_approx() else normal)
	return ribbon(points, normals, width)

func capture_observation() -> Dictionary:
	var result: Dictionary = super.capture_observation()
	result.divine_study = {"study_contract": settings.study_contract, "plan_only": settings.get("plan_only", true),
		"owner_uuid": settings.owner_uuid, "phase_admitted": phase_admitted(),
		"actual_healing": event_input.get("actual_healing", 0), "actual_damage": event_input.get("actual_damage", 0),
		"native_behavior_id": settings.get("native_behavior_id", ""), "rules_evaluated": false}
	return result

const VfxPackageIO_d94cb458d7 = preload("res://assets/vfx/extensions/followup-20261020/scoped_resource_io.gd")
