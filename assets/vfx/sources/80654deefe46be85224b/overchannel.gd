extends Node3D
## Optional accepted-cast hand adjunct and independently supplied Necrotic recoil.
## The original selected spell is retained by the caller, including later ticks.

const Geometry = preload("res://assets/vfx/sources/3a462df332f8b5fc50ce/study_geometry.gd")
var settings: Dictionary = {}
var live_state: Dictionary = {}
var endpoints: Array = []
var observed: Dictionary = {}
var hand: Node3D
var recipient: Node3D
var charge_blades: Array[MeshInstance3D] = []
var charge_materials: Array[ShaderMaterial] = []
var recoil_strokes: Array[MeshInstance3D] = []
var recoil_materials: Array[ShaderMaterial] = []
var age_seconds: float = 0.0


static func make_component(input: Dictionary) -> Node3D:
	var effect: Node3D = VfxPackageIO_80654deefe.resource("res://assets/vfx/sources/80654deefe46be85224b/overchannel.gd").new()
	effect.settings = input.duplicate(true)
	effect.prepare()
	return effect


func prepare() -> void:
	hand = Node3D.new()
	hand.name = "OriginalPaletteHandCharge"
	add_child(hand)
	recipient = Node3D.new()
	recipient.name = "SuppliedNecroticRecoil"
	add_child(recipient)
	var colors: Array = settings.original_spell_palette
	assert(colors.size() >= 3, "Overchannel study requires the selected spell's explicit palette")
	for index in 3:
		var material: ShaderMaterial = Geometry.ink(Color(colors[index]), 0.65)
		charge_materials.append(material)
		charge_blades.append(Geometry.piece(hand, "GatheredSheet" + str(index), ArrayMesh.new(), material))
	for index in 3:
		var material: ShaderMaterial = Geometry.ink(Color(settings.necrotic_palette[index]), 0.42)
		recoil_materials.append(material)
		recoil_strokes.append(Geometry.piece(recipient, "RecipientCrack" + str(index), ArrayMesh.new(), material))
	hand.visible = false
	recipient.visible = false


func set_live_endpoints(value: Array) -> void:
	endpoints = value


func set_cast_observation(value: Dictionary) -> bool:
	if str(value.get("cast_uuid", "")) != str(settings.cast_uuid) or str(value.get("source_uuid", "")) != str(settings.source_uuid):
		return false
	live_state = value.duplicate(true)
	sample(age_seconds)
	return true


func sample(seconds: float) -> void:
	age_seconds = seconds
	observed = Geometry.observation(settings, live_state, seconds)
	var accepted: bool = bool(observed.get("accepted_selected_cast", false))
	var owner_alpha: float = Geometry.visibility(observed)
	var charge_alpha: float = smoothstep(0.0, 0.16, seconds) * (1.0 - smoothstep(0.52, 0.82, seconds)) * owner_alpha
	if not accepted or not bool(settings.get("charge_enabled", false)):
		charge_alpha = 0.0
	if observed.has("retire_at_seconds"):
		charge_alpha *= 1.0 - smoothstep(float(observed.retire_at_seconds), float(observed.retire_at_seconds) + 0.24, seconds)
	if endpoints.is_empty():
		charge_alpha = 0.0
	else:
		hand.position = global_transform.affine_inverse() * endpoints[0].point
	hand.visible = charge_alpha > 0.001
	var gathered: float = smoothstep(0.06, 0.6, seconds)
	for index in charge_blades.size():
		charge_blades[index].mesh = charge_mesh(index, gathered)
		charge_materials[index].set_shader_parameter("opacity", charge_alpha)
		charge_materials[index].set_shader_parameter("source_seconds", seconds)
	# Recoil is never inferred from use count, elapsed time, HP or cast rank.
	var recoil_event: Dictionary = observed.get("recoil_event", {})
	var recoil_alpha: float = 0.0
	if accepted and not str(recoil_event.get("damage_event_uuid", "")).is_empty() and str(recoil_event.get("damage_type", "")) == "Necrotic" and bool(recoil_event.get("accepted", false)):
		var recoil_age: float = seconds - float(recoil_event.visual_begin_seconds)
		recoil_alpha = smoothstep(0.0, 0.08, recoil_age) * (1.0 - smoothstep(0.14, 0.48, recoil_age)) * owner_alpha
	if endpoints.size() < 2:
		recoil_alpha = 0.0
	else:
		recipient.position = global_transform.affine_inverse() * endpoints[1].point
	recipient.visible = recoil_alpha > 0.001
	for index in recoil_strokes.size():
		recoil_strokes[index].mesh = recoil_mesh(index)
		recoil_materials[index].set_shader_parameter("opacity", recoil_alpha)
		recoil_materials[index].set_shader_parameter("source_seconds", seconds)


func charge_mesh(index: int, gathered: float) -> ArrayMesh:
	var points := PackedVector3Array()
	var angle: float = float(index) * TAU / 3.0
	for step in 21:
		var along: float = float(step) / 20.0
		var reach: float = (1.0 - along) * lerpf(0.23, 0.12, gathered)
		var phase: float = angle + along * 0.9
		points.append(Vector3(cos(phase) * reach, sin(phase) * reach, (along - 0.5) * 0.11))
	return Geometry.ribbon(points, 0.045 * (1.0 - gathered * 0.32), Vector3.FORWARD)


func recoil_mesh(index: int) -> ArrayMesh:
	var points := PackedVector3Array()
	var phase: float = float(index) * TAU / 3.0 + 0.4
	for step in 8:
		var along: float = float(step) / 7.0
		var reach: float = 0.035 + along * 0.18
		var bend: float = 0.025 * (1.0 if step % 2 == 0 else -1.0) * sin(along * PI)
		points.append(Vector3(cos(phase) * reach + bend, sin(phase) * reach, 0.018 + sin(along * PI) * 0.025))
	return Geometry.ribbon(points, 0.025, Vector3.FORWARD)


func capture_observation() -> Dictionary:
	return {"study": "wizard_overchannel", "cast_uuid": settings.cast_uuid, "source_uuid": settings.source_uuid, "original_spell_id": settings.original_spell_id, "original_spell_palette": settings.original_spell_palette.duplicate(), "state": observed.duplicate(true), "source_hand_local": hand.position, "recoil_recipient_local": recipient.position, "charge_visible": hand.visible, "recoil_visible": recipient.visible, "live_endpoints": endpoints.size(), "native_charge_layers": charge_blades.size(), "native_recoil_layers": recoil_strokes.size(), "hp_mutation": false, "use_count_solver": false, "rank_solver": false, "optical_lights": 0}

const VfxPackageIO_80654deefe = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
