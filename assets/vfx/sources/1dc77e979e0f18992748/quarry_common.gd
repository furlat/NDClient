extends "res://assets/vfx/sources/43d964a5ab22cb82ad2d/retained_contact.gd"
## Exact caster sustain + current recipient child. Reapply changes the disclosed
## child while retaining the original sustain. No defeat/cost/rider rule solver.
var quarry_state: Dictionary = {}

func configure(input: Dictionary) -> void:
	super.configure(input)
	set_quarry_input(input.get("quarry_state",{}))

func set_quarry_input(value: Dictionary) -> void:
	_hide_all()
	quarry_state = {}
	condition = {}
	if str(value.get("sustain_uuid","")) != str(settings.owner_uuid) \
		or str(value.get("source_actor_uuid","")) != str(settings.source_actor_uuid) \
		or not bool(value.get("observed",false)):
		return
	var recipient := str(value.get("recipient_uuid",""))
	var child: Dictionary = value.get("condition",{})
	if recipient.is_empty() or str(child.get("recipient_uuid","")) != recipient \
		or str(child.get("source_actor_uuid","")) != str(settings.source_actor_uuid) \
		or str(child.get("condition_uuid","")).is_empty():
		return
	quarry_state = value.duplicate(true)
	settings.recipient_uuid = recipient
	settings.condition_uuid = child.condition_uuid
	set_condition_input(child)

func set_hit_input(value: Dictionary) -> void:
	set_strike_input(value)
	weapon = {}

func set_entity_geometry(value: Dictionary) -> void:
	weapon = value if str(value.get("actor","")) == str(settings.source_actor_uuid) else {}
	if value.has("item_uuid") and str(value.item_uuid) != str(strike.get("item_uuid","")):
		weapon = {}

func quarry_admitted() -> bool:
	return owner_admitted() and condition_admitted() \
		and str(quarry_state.get("sustain_uuid","")) == str(retained_owner.condition_uuid) \
		and str(quarry_state.get("recipient_uuid","")) == str(settings.recipient_uuid)

func rider_admitted() -> bool:
	return quarry_admitted() and not str(strike.get("attack_uuid","")).is_empty() \
		and str(strike.get("attack_uuid","")) == str(settings.get("attack_uuid","")) \
		and str(strike.get("sustain_uuid","")) == str(settings.owner_uuid) \
		and str(strike.get("quarry_condition_uuid","")) == str(condition.condition_uuid) \
		and str(strike.get("source_actor_uuid","")) == str(settings.source_actor_uuid) \
		and str(strike.get("recipient_uuid","")) == str(settings.recipient_uuid) \
		and str(strike.get("outcome","")) in ["hit","critical"] \
		and bool(strike.get("rider_applied",false)) \
		and not str(strike.get("damage_fact_uuid","")).is_empty()

func payload_admitted() -> bool:
	return rider_admitted()

func mark_envelope(seconds: float) -> float:
	var phase := str(settings.phase)
	var admitted := owner_admitted() if phase == "windup" else quarry_admitted()
	if phase == "hit":
		admitted = payload_admitted()
	var value := phase_envelope(seconds) if admitted else 0.0
	if phase == "condition":
		value *= .52
	_sample_materials(seconds,value)
	return value

func measured_mark(node: MeshInstance3D) -> bool:
	var hit := contact()
	if hit.is_empty():
		return false
	var patch := recipient_patch()
	var measured := MeasuredSurface.build(patch,"recipient_patch",hit.position,.012)
	if measured.cells == 0:
		return false
	node.global_transform = Transform3D(Basis.IDENTITY,patch.origin)
	node.mesh = measured.mesh
	node.show()
	return true

func capture_observation() -> Dictionary:
	var result := super.capture_observation()
	result["quarry"] = {"sustain_uuid":settings.get("owner_uuid"),"quarry_uuid":settings.get("recipient_uuid"),
		"quarry_condition_uuid":condition.get("condition_uuid"),"quarry_admitted":quarry_admitted(),
		"rider_admitted":payload_admitted(),"action_identity":settings.get("action_id"),
		"selected_ability":settings.get("selected_ability",""),
		"new_cast":str(settings.get("action_id","")).begins_with("spell."),"rule_solver":false}
	return result
