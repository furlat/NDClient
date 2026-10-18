extends "res://assets/vfx/sources/43d964a5ab22cb82ad2d/retained_contact.gd"
const GpuRibbon = preload("res://assets/vfx/sources/34e0f9ed9a909885cd97/path_ribbon.gd")
## A melee spell drain and observed healing return. Retained caster marker
## survives a miss; repeats use their granted action identity without a new cast.
var tendons: Array[MeshInstance3D] = []
var hand_fold: MeshInstance3D

static func make_component(input: Dictionary) -> Node3D:
	var component: Node3D = VfxPackageIO_8d17316149.resource("res://assets/vfx/sources/8d17316149890f77c98b/vampiric_touch.gd").new()
	component.configure(input)
	var material := ContactMaterial.make(input.material,"\nALPHA=(.16+.84*clamp(ALPHA,0.0,1.0))*sin(UV.x*PI)*sin(UV.y*PI)*owned_envelope*.62;\n")
	for index in 2:
		component.tendons.append(component.make_mesh("RecipientToRealHandDrain"+str(index),material))
	component.hand_fold = component.make_mesh("CasterOwnedHandFold",material)
	return component

func payload_admitted() -> bool:
	var identity := str(strike.get("behavior_id",""))
	var repeat := identity == "action.spell.vampiric_touch.strike"
	return identity in ["spell.vampiric_touch","action.spell.vampiric_touch.strike"] \
		and (not repeat or owner_admitted()) \
		and str(strike.get("source_actor_uuid","")) == str(settings.source_actor_uuid) \
		and str(strike.get("recipient_uuid","")) == str(settings.recipient_uuid) \
		and str(strike.get("attack_uuid","")) == str(settings.attack_uuid) \
		and str(strike.get("attack_kind","")) == "spell" \
		and str(strike.get("outcome","")) in ["hit","critical"] \
		and bool(strike.get("payload_applied",false)) \
		and not str(strike.get("damage_fact_uuid","")).is_empty() \
		and str(strike.get("damage_type","")) == "necrotic"

func healing_admitted() -> bool:
	# Public HealFact already owns the amount. It is intentionally independent
	# of any private per-component damage ledger or total recipient HP loss.
	return bool(healing.get("observed",false)) and int(healing.get("actual_healing",0)) > 0 \
		and not bool(healing.get("was_blocked",true)) \
		and not str(healing.get("healing_fact_uuid","")).is_empty() \
		and str(healing.get("recipient_uuid","")) == str(settings.source_actor_uuid) \
		and str(healing.get("source_actor_uuid","")) == str(settings.source_actor_uuid) \
		and str(healing.get("parent_event_uuid","")) == str(settings.activation_event_uuid)

func sample(seconds: float) -> void:
	_hide_all()
	var phase := str(settings.phase)
	var admitted := owner_admitted() if phase in ["windup","activation","condition","retire"] else payload_admitted()
	if phase == "healing":
		admitted = healing_admitted()
	var value := phase_envelope(seconds) if admitted else 0.0
	if phase == "condition":
		value *= .26
	_sample_materials(seconds,value)
	if value <= .0001 or endpoints.size() < 2:
		return
	var hand: Vector3 = endpoints[0].point
	if phase in ["windup","activation","condition","retire"]:
		var fold: Array[Vector3] = []
		var fold_widths: Array[float] = []
		for vertex in 17:
			var along := float(vertex)/16.0
			fold.append(hand+Vector3(.018*sin(along*PI*1.6),.055*(along-.5),.016*cos(along*PI)))
			fold_widths.append(.010*sin(along*PI))
		hand_fold.global_transform = Transform3D.IDENTITY
		GpuRibbon.assign(hand_fold,fold,fold_widths)
		hand_fold.show()
		return
	var hit := contact()
	if hit.is_empty():
		return
	for index in 2:
		var points: Array[Vector3] = []
		var widths: Array[float] = []
		for vertex in 29:
			var along := float(vertex)/28.0
			var fraction := along if phase == "healing" else 1.0-along
			var bend := Vector3.UP*sin(along*PI)*(.06+float(index)*.025)
			points.append(hit.position.lerp(hand,fraction)+bend+hit.normal*sin(along*PI)*float(index)*.018)
			widths.append((.017 if phase == "healing" else .025)*sin(along*PI))
		tendons[index].global_transform = Transform3D.IDENTITY
		GpuRibbon.assign(tendons[index],points,widths)
		tendons[index].show()

func capture_observation() -> Dictionary:
	var result := super.capture_observation()
	result["vampiric_touch"] = {"healing_admitted":healing_admitted(),"healing_from_actual_heal_fact":true,
		"action_identity":strike.get("behavior_id"),"new_cast":str(strike.get("behavior_id")) == "spell.vampiric_touch"}
	return result

const VfxPackageIO_8d17316149 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
