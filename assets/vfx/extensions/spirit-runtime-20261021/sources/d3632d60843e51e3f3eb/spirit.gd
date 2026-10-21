extends "res://assets/vfx/extensions/spirit-runtime-20261021/sources/8086f5cea73028bb1c00/path_assembly.gd"
## Original orbit and native sixteen-frame wing cycle continue at actual owner age.
const ZoneInput = preload("res://assets/vfx/extensions/cell-validation-20261021/sources/bbfe0c8c2a4fd1b29e8d/input.gd")
const OwnerGraph = preload("res://assets/vfx/sources/1d02b6d800655ef86df2/resource_graph.gd")
var owner_uuid := ""
var owner_state := {}
var state_error := ""
var anchor_world: Variant


static func preparation_resources(input: Dictionary) -> Array:
	var result: Array = preload("res://assets/vfx/extensions/spirit-runtime-20261021/sources/aa6d31e0db538a4bab5e/assembly.gd").preparation_resources(input)
	result.append("res://assets/vfx/extensions/spirit-runtime-20261021/sources/4358fe542e97279c061c/owner_release_spirit_radiant.gd")
	result.append("res://assets/vfx/extensions/spirit-runtime-20261021/sources/89af03b3b463a89cdcf8/owner_release_spirit_necrotic.gd")
	return result


static func make_component(input: Dictionary) -> Node3D:
	if str(input.get("owner_uuid", "")).is_empty():
		return null
	var node: Node3D = VfxPackageIO_d3632d6084.resource("res://assets/vfx/extensions/spirit-runtime-20261021/sources/d3632d60843e51e3f3eb/spirit.gd").new()
	node.owner_uuid = input.owner_uuid
	node.selections = input.entries.duplicate(true)
	node.opacity_control = input.get("opacity_control", false)
	return node


func set_owner_state(value: Dictionary) -> bool:
	state_error = ZoneInput.owner_state(value, owner_uuid)
	owner_state = value.duplicate(true) if state_error.is_empty() else {}
	if not ZoneInput.admitted(owner_state):
		hide()
	return state_error.is_empty()


func set_targets(value: Array) -> void:
	anchor_world = ZoneInput.point(value)
	if anchor_world == null:
		hide()


func set_live_endpoints(value: Array) -> void:
	set_targets(value)


func refresh_live_inputs(seconds: float) -> void:
	sample(seconds)


func sample(seconds: float) -> void:
	if not prepared:
		_prepare()
	visible = is_finite(seconds) and seconds >= 0.0 and anchor_world != null and ZoneInput.admitted(owner_state)
	if not visible:
		return
	global_position = anchor_world
	var age := float(owner_state.owner_age_seconds)
	for entry: Dictionary in entries:
		var selected: Dictionary = entry.definition
		entry.root.visible = age >= float(selected.get("begin", 0.0))
		if not entry.root.visible:
			continue
		if selected.has("orbit"):
			var orbit: Dictionary = selected.orbit
			var angle := float(orbit.phase) + age * float(orbit.speed)
			entry.root.position = entry.origin + Vector3(cos(angle) * float(orbit.radius), 0.0, sin(angle) * float(orbit.radius))
			entry.root.rotation.y = -angle + PI
		OwnerGraph.native_sampler_scopes += 1
		entry.composition.sample((age - float(selected.get("begin", 0.0))) * float(selected.get("rate", 1.0)))
		OwnerGraph.native_sampler_scopes -= 1
		if not entry.has("last_transform") or entry.last_transform != entry.root.global_transform:
			entry.last_transform = entry.root.global_transform
			var inverse: Transform3D = entry.root.global_transform.affine_inverse()
			for material: ShaderMaterial in entry.source_materials:
				material.set_shader_parameter("factory_world_to_source", inverse)


func capture_observation() -> Dictionary:
	return {"owner_uuid": owner_uuid, "state_error": state_error, "source_age": owner_state.get("owner_age_seconds"),
		"finite_review_expiry": false, "original_orbit_parameters": true, "visible": visible}

const VfxPackageIO_d3632d6084 = preload("res://assets/vfx/extensions/spirit-runtime-20261021/scoped_resource_io.gd")
