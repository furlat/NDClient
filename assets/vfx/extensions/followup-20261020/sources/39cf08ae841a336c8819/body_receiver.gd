extends RefCounted
const Stack = preload("res://assets/vfx/extensions/followup-20261020/sources/5aa749322157f338b67c/body_stack.gd")
var settings: Dictionary = {}
var slot := -1
var owner := 0
var materials: Array[ShaderMaterial] = []
var actor := ""
var strength := 1.0
var uploads := 0
var root: Node3D
var pose_provider: Object
var logical_capture := false


func configure(specification: Dictionary, clock_slot: int, identity: int, parent: Node3D) -> void:
	settings = specification
	slot = clock_slot
	owner = identity
	root = parent
	strength = float(specification.get("strength", 1.0))


func set_actor_layers(packet: Dictionary) -> bool:
	if settings.get("capture_pose", false) and not logical_capture:
		clear_materials()
		return false
	var incoming: Array = packet.get("layers", [])
	var recipient := str(packet.get("actor_uuid", ""))
	if recipient.is_empty():
		clear_materials()
		return false
	var selected: Array[ShaderMaterial] = []
	for layer in incoming:
		if layer.get("slot", "") in ["shadow", "aura", "weaponGlow", "effect", "effect2", "effect3", "slash"]:
			continue
		if layer.get("material") is ShaderMaterial and not layer.material in selected:
			selected.append(layer.material)
	if selected == materials and recipient == actor:
		return not materials.is_empty()
	clear_materials()
	actor = recipient
	materials = selected
	refresh()
	return not materials.is_empty()


func set_treatment_state(value: Dictionary) -> void:
	var next := float(value.get("strength", settings.get("strength", 1.0)))
	if settings.get("stage_strengths") is Array:
		var failures := int(value.get("failures", -1))
		if failures < 0 or failures >= settings.stage_strengths.size():
			next = 0.0
		else:
			next = float(settings.stage_strengths[failures])
	if is_equal_approx(next, strength):
		return
	strength = clampf(next, 0.0, 1.0)
	refresh()


func refresh() -> void:
	for material in materials:
		Stack.bind(material, owner, actor, {"slot": slot, "kind": settings.kind, "strength": strength,
			"data": settings.data, "period": settings.loop_seconds})
	uploads += 1


func set_pose_provider(packet: Dictionary) -> bool:
	if not settings.get("capture_pose",false): return false
	var provider: Object = packet.get("provider")
	if provider == null or not provider.has_method("acquire_condition_pose") or not provider.has_method("release_condition_pose"): return false
	if pose_provider != null and pose_provider != provider: pose_provider.call("release_condition_pose",owner)
	pose_provider = provider
	logical_capture = bool(provider.call("acquire_condition_pose",owner,packet))

	return logical_capture


func clear() -> void:
	clear_materials()
	if is_instance_valid(pose_provider): pose_provider.call("release_condition_pose",owner)
	pose_provider = null
	logical_capture = false


func clear_materials() -> void:
	for material in materials:
		Stack.unbind(material, owner)
	materials.clear()
	actor = ""
