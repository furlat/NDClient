extends RefCounted
## Presentation admission only. The caller supplies disclosed ownership/state;
## this object neither discovers equipment nor decides a gameplay contribution.
var owner_kind := ""
var owner_uuid := ""
var effect_uuid := ""
var state: Dictionary = {}
var rejection := "unbound"

func configure(input: Dictionary) -> void:
	owner_kind = str(input.owner_kind)
	owner_uuid = str(input.owner_uuid)
	effect_uuid = str(input.effect_uuid)
	assert(owner_kind in ["item", "caster"] and not owner_uuid.is_empty() and not effect_uuid.is_empty())
	if input.has("binding"):
		bind(input.binding)

func bind(value: Dictionary) -> bool:
	# An invalid transfer must retire the old geometry immediately. Keeping the
	# previous valid state would leave an enchantment on the former holder.
	state.clear()
	rejection = "identity_mismatch"
	for key in ["owner_kind", "owner_uuid", "effect_uuid"]:
		if str(value.get(key, "")) != str(get(key)):
			return false
	for key in ["item_uuid", "holder_uuid", "equipment_slot", "render_slot"]:
		if str(value.get(key, "")).is_empty():
			rejection = "missing_" + key
			return false
	if owner_kind == "item" and str(value.item_uuid) != owner_uuid:
		return false
	if owner_kind == "caster" and str(value.holder_uuid) != owner_uuid:
		return false
	if not str(value.equipment_slot) in ["MELEE_MAIN", "MELEE_OFF", "RANGED_MAIN", "RANGED_OFF"]:
		rejection = "invalid_equipment_slot"
		return false
	if not str(value.render_slot) in ["weapon", "offhand"]:
		rejection = "invalid_render_slot"
		return false
	state = value.duplicate(true)
	rejection = ""
	return true

func visible() -> bool:
	return not state.is_empty() and bool(state.get("present", false)) and bool(state.get("equipped", false)) \
		and bool(state.get("observed", false)) and bool(state.get("contribution_active", false)) \
		and not bool(state.get("suppressed", true)) and bool(state.get("decoration_admitted", false))

func matches_surface(value: Dictionary) -> bool:
	if not visible() or str(value.get("actor", "")) != str(state.holder_uuid):
		return false
	# Authoring's existing measured-surface seam omits item UUID. Explicit fixture
	# binding is disclosed; production can provide the UUID and gets strict checks.
	if value.has("item_uuid") and str(value.item_uuid) != str(state.item_uuid):
		return false
	if value.has("equipment_slot") and str(value.equipment_slot) != str(state.equipment_slot):
		return false
	return true

func admits_hit(value: Dictionary) -> bool:
	# Native DamageRollResult.attack_kind is not a universal public fact. The
	# presentation adapter must explicitly disclose the actual applied rider and
	# eligible equipped-weapon classification. Absence never guesses eligibility.
	return owner_kind == "caster" and visible() \
		and str(value.get("owner_uuid", "")) == owner_uuid \
		and str(value.get("effect_uuid", "")) == effect_uuid \
		and str(value.get("item_uuid", "")) == str(state.item_uuid) \
		and str(value.get("source_kind", "")) == "equipped" \
		and str(value.get("attack_kind", "")) == "weapon" \
		and str(value.get("outcome", "")) in ["hit", "critical"] \
		and bool(value.get("rider_component_applied", false)) \
		and not str(value.get("damage_component_uuid", "")).is_empty()
