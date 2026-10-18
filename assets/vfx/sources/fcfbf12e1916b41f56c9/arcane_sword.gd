extends Node3D
## Independently anchored real source blade. Supplied strike records own aim,
## hit entitlement and movement. No caster melee or inferred follow-up action.
const AuthoredBlade = preload("res://assets/vfx/sources/d833237419eecdcf8f8b/authored_blade.gd")
const FieldMaterial = preload("res://assets/vfx/sources/89da09bf4ca66175808e/field_material.gd")

var specification: Dictionary = {}
var endpoints: Array = []
var blade: MeshInstance3D
var material: ShaderMaterial
var local_clock := 0.0
var owner_state: Dictionary = {}
var visibility := 0.0
var contacts: Array[MeshInstance3D] = []

static func make_component(input: Dictionary) -> Node3D:
	assert(not str(input.owner_uuid).is_empty())
	var effect: Node3D = VfxPackageIO_fcfbf12e19.resource("res://assets/vfx/sources/fcfbf12e1916b41f56c9/arcane_sword.gd").new()
	effect.specification = input.duplicate(true)
	effect.material = FieldMaterial.build(input.material)
	effect.blade = MeshInstance3D.new()
	effect.blade.name = "IndependentArcaneSword"
	effect.blade.mesh = AuthoredBlade.mesh(input.geometry)
	effect.blade.material_override = effect.material
	effect.blade.top_level = true
	effect.blade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	effect.add_child(effect.blade)
	effect.blade.hide()
	for index in 3:
		var contact := MeshInstance3D.new()
		contact.name = "FactualForcePressure%d" % index
		contact.top_level = true
		contact.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var sphere := SphereMesh.new()
		sphere.radius = .1
		sphere.height = .2
		sphere.radial_segments = 24
		sphere.rings = 12
		contact.mesh = sphere
		contact.material_override = FieldMaterial.build(input.contact_material)
		effect.add_child(contact)
		contact.hide()
		effect.contacts.append(contact)
	return effect

func set_live_endpoints(value: Array) -> void:
	endpoints = value.duplicate(true)
	sample(local_clock)

func set_owner_state(value: Dictionary) -> bool:
	if str(value.get("owner_uuid", "")) != str(specification.owner_uuid):
		return false
	owner_state = value.duplicate(true)
	sample(local_clock)
	return true

static func strike_rotation(age: float, direction: Vector3) -> Quaternion:
	var aimed := Quaternion(Vector3.UP, direction.normalized())
	var anticipation := Quaternion(Vector3.FORWARD, -.7)
	if age < .18:
		return Quaternion.IDENTITY.slerp(anticipation, smoothstep(0.0, .18, age))
	if age < .42:
		return anticipation.slerp(aimed, smoothstep(.18, .42, age))
	return aimed.slerp(Quaternion.IDENTITY, smoothstep(.55, .9, age))

func sample(seconds: float) -> void:
	local_clock = seconds
	if endpoints.size() < 2:
		return
	var state: Dictionary = specification.state.duplicate(true)
	for row in specification.get("review_states", []):
		if seconds >= float(row.seconds):
			state.merge(row.state, true)
	if not owner_state.is_empty():
		state = owner_state.duplicate(true)
	var active: bool = str(state.get("owner_uuid", "")) == str(specification.owner_uuid)
	active = active and bool(state.get("present", false)) and bool(state.get("observed", false)) and not bool(state.get("suppressed", true))
	visibility = smoothstep(0.0, float(specification.apply_seconds), seconds) if active else 0.0
	if state.has("ending_started_at"):
		visibility *= 1.0 - smoothstep(0.0, float(specification.retire_seconds), seconds - float(state.ending_started_at))
	var anchor: Vector3 = endpoints[0].point + Vector3(0, .35, 0)
	var target: Vector3 = endpoints[1].point
	var rotation := Quaternion.IDENTITY
	var hit_age := -1.0
	var strike_age := -1.0
	for strike in state.get("strikes", []):
		var age: float = seconds - float(strike.started_at)
		if age >= 0.0 and age < .9:
			strike_age = age
			rotation = strike_rotation(age, target - anchor)
			if bool(strike.get("contact_admitted", false)):
				hit_age = age - .42
	var hilt := anchor
	if strike_age >= 0.0:
		var contact_hilt: Vector3 = target - rotation * Vector3.UP * float(specification.geometry.length_cells)
		var stroke := smoothstep(.18, .42, strike_age) * (1.0 - smoothstep(.55, .9, strike_age))
		hilt = anchor.lerp(contact_hilt, stroke)
	blade.global_transform = Transform3D(Basis(rotation), hilt)
	blade.visible = visibility > .0001
	material.set_shader_parameter("field_clock", seconds)
	material.set_shader_parameter("field_opacity", visibility * float(specification.opacity))
	for index in contacts.size():
		var contact := contacts[index]
		var age: float = hit_age - index * .045
		contact.visible = visibility > .0001 and age >= 0.0 and age < .26
		if contact.visible:
			var scale_factor := 1.0 + age * 4.0
			contact.global_transform = Transform3D(Basis.IDENTITY.scaled(Vector3(scale_factor, scale_factor, .3 * scale_factor)), target)
			contact.material_override.set_shader_parameter("field_clock", seconds)
			contact.material_override.set_shader_parameter("field_opacity", visibility * (1.0 - smoothstep(.04, .26, age)) * .35)

func capture_observation() -> Dictionary:
	return {"arcane_sword": {"owner_uuid": specification.owner_uuid, "hilt_world": blade.global_position,
		"logical_anchor_world": endpoints[0].point if not endpoints.is_empty() else Vector3.ZERO,
		"tip_world": blade.global_transform * (Vector3.UP * float(specification.geometry.length_cells)),
		"clock": local_clock, "visibility": visibility, "contact_draws": contacts.filter(func(piece: Node3D) -> bool: return piece.visible).size(),
		"optical_lights": 0, "movement_and_hits": "Supplied actual construct action after-values; caster remains separate"}}

const VfxPackageIO_fcfbf12e19 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
