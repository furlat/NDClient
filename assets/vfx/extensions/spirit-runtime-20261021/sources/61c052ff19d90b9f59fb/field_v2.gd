extends "res://assets/vfx/extensions/spirit-runtime-20261021/sources/fd3e02b7364f9a922e02/field.gd"
## Same admitted source age/orbit; unchanged owner input does not repeat pure draw writes.
var sampled_input := false
var sampled_age := 0.0
var sampled_anchor := Vector3.ZERO
var sampled_world := Transform3D()


static func preparation_resources(input: Dictionary) -> Array:
	return preload("res://assets/vfx/extensions/spirit-runtime-20261021/sources/aa6d31e0db538a4bab5e/assembly.gd").preparation_resources(input)


static func make_component(input: Dictionary) -> Node3D:
	if str(input.get("owner_uuid", "")).is_empty():
		return null
	var node: Node3D = VfxPackageIO_61c052ff19.resource("res://assets/vfx/extensions/spirit-runtime-20261021/sources/61c052ff19d90b9f59fb/field_v2.gd").new()
	node.owner_uuid = input.owner_uuid
	node.selections = input.entries.duplicate(true)
	node.opacity_control = input.get("opacity_control", false)
	return node


func sample(seconds: float) -> void:
	if not prepared:
		_prepare()
	visible = is_finite(seconds) and seconds >= 0.0 and anchor_world != null and ZoneInput.admitted(owner_state)
	if not visible:
		sampled_input = false
		return
	var age := float(owner_state.owner_age_seconds)
	if sampled_input and sampled_age == age and sampled_anchor == anchor_world and sampled_world == global_transform:
		return
	global_position = anchor_world
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
		var world: Transform3D = entry.root.global_transform
		if not entry.has("last_transform") or entry.last_transform != world:
			entry.last_transform = world
			# The captured Spirit shaders use local VERTEX; retain the actual
			# world-space path if a declared source material ever needs it.
			if not entry.source_materials.is_empty():
				var inverse: Transform3D = world.affine_inverse()
				for material: ShaderMaterial in entry.source_materials:
					material.set_shader_parameter("factory_world_to_source", inverse)
	sampled_age = age
	sampled_anchor = anchor_world
	sampled_world = global_transform
	sampled_input = true

const VfxPackageIO_61c052ff19 = preload("res://assets/vfx/extensions/spirit-runtime-20261021/scoped_resource_io.gd")
