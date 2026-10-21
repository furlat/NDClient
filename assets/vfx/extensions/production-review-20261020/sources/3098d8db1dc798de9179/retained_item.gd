extends "res://assets/vfx/extensions/production-review-20261020/sources/c6e201dbffbdead64da9/payload_item.gd"
## Existing retained payload artwork. Private power is optional visual input.
const SourceMaterials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
var owner_bound := false


static func make_component(input: Dictionary) -> Node3D:
	if input.get("kind", "") not in ["freezing", "delayed_fire"]:
		return null
	var result: Node3D = VfxPackageIO_3098d8db1d.resource("res://assets/vfx/extensions/production-review-20261020/sources/3098d8db1dc798de9179/retained_item.gd").new()
	result.specification = input.duplicate(true)
	var supplied := 0
	for key in ["item_uuid", "lifetime_uuid", "original_caster_uuid"]:
		result.specification[key] = str(input.get(key, ""))
		if not result.specification[key].is_empty():
			supplied += 1
	if supplied != 0 and supplied != 3:
		result.free()
		return null
	result.owner_bound = supplied == 3
	result.set_payload_state(input.get("state", {}))
	return result


func set_payload_state(value: Dictionary) -> bool:
	for draw: MeshInstance3D in draws:
		draw.hide()
	state.clear()
	visible_owner = false
	rejection = "payload_identity"
	for key in ["item_uuid", "lifetime_uuid", "original_caster_uuid"]:
		if str(value.get(key, "")).is_empty():
			return false
		if owner_bound and str(value[key]) != str(specification[key]):
			return false
	if str(value.get("kind", "")) != str(specification.kind):
		return false
	var expected_item := "spell_payload.freezing_sphere" if specification.kind == "freezing" else "spell_payload.delayed_fireball"
	if str(value.get("item_id", "")) != expected_item:
		return false
	if value.has("dice_count"):
		if typeof(value.dice_count) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value.dice_count)) or float(value.dice_count) < 0.0:
			rejection = "invalid_supplied_power"
			return false
	if value.has("effect_uuid") and str(value.effect_uuid).is_empty():
		return false
	if specification.has("effect_uuid") and str(value.get("effect_uuid", "")) != str(specification.effect_uuid):
		return false
	if not owner_bound:
		for key in ["item_uuid", "lifetime_uuid", "original_caster_uuid"]:
			specification[key] = value[key]
		owner_bound = true
	# Constructor-bound item/lifetime/caster identities may receive the actual
	# optional effect identity only on their first observed state packet.
	if value.has("effect_uuid") and not specification.has("effect_uuid"):
		specification.effect_uuid = value.effect_uuid
	# Do not populate missing power, save DC, presence or suppression facts.
	state = value.duplicate(true)
	rejection = ""
	return true


func payload_radius_cells() -> float:
	if specification.kind == "freezing":
		return .055
	if not state.has("dice_count"):
		return .035
	return .035 + .001 * clampf(float(state.dice_count) - float(specification.get("base_power", 12)), 0.0, 10.0)


func prepare() -> void:
	super.prepare()
	if specification.kind != "delayed_fire" or not specification.get("readable_retained_fire", true):
		return
	# Exact existing payload_item_readable material finish, without a new light.
	for material: ShaderMaterial in materials:
		var shader := Shader.new()
		shader.code = SourceMaterials.finish_fragment(material.shader.code, "\nALBEDO *= 4.0; EMISSION *= 4.0;\n")
		SourceMaterials.replace_shader(material, shader)


func sample(seconds: float) -> void:
	if draws.is_empty():
		prepare()
	for index in draws.size():
		draws[index].hide()
		Native.clock(materials[index], seconds, 0.0)
	visible_owner = false
	if not Native.observed(state) or bool(state.get("retired", true)) or not bool(state.get("lifetime_present", false)) or endpoints.is_empty():
		return
	if str(state.get("location_kind", "")) not in ["exposed_hand", "floor", "exposed_container"]:
		return
	var binding: Dictionary = specification.get("anchor_binding", {})
	if str(binding.get("item_uuid", "")) != str(state.item_uuid) or not bool(binding.get("observed", false)):
		rejection = "exact_item_anchor_missing"
		return
	if str(binding.get("location_owner_uuid", "")) != str(state.get("location_owner_uuid", "")):
		rejection = "current_location_owner"
		return
	if str(binding.get("location_kind", "")) != str(state.location_kind):
		rejection = "current_location_kind"
		return
	var alpha: float = Native.envelope(specification, seconds)
	var point: Vector3 = endpoints[0].point
	if state.location_kind == "floor":
		point += Vector3(0, .11, 0)
	var radius := payload_radius_cells()
	for index in draws.size():
		var size := radius * 2.0 * (1.14 if index == 1 else 1.0)
		draws[index].global_transform = Transform3D(Basis(Vector3.UP, seconds * .35) * Basis.from_scale(Vector3.ONE * size), point)
		draws[index].visible = alpha > .001
		if specification.kind == "delayed_fire":
			Native.fire_clock(materials[index], seconds, alpha * .8, .30 + .03 * sin(seconds * 3.0))
		else:
			Native.clock(materials[index], seconds, alpha * (.6 if index == 1 else .9))
	visible_owner = alpha > .001
	rejection = ""


func capture_observation() -> Dictionary:
	var result := super.capture_observation()
	result.public_power_supplied = state.has("dice_count")
	result.owner_bound = owner_bound
	result.visual_size_basis = "supplied_dice_count" if state.has("dice_count") else "source_authored_baseline"
	result.radius_cells = payload_radius_cells()
	return result

const VfxPackageIO_3098d8db1d = preload("res://assets/vfx/extensions/production-review-20261020/scoped_resource_io.gd")
