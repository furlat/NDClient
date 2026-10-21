extends "res://assets/vfx/extensions/spirit-runtime-20261021/sources/61c052ff19d90b9f59fb/field_v2.gd"
## Fixed authored one-leaf sample bindings are lowered once, not rediscovered per frame.
var direct_sampling := false
var sample_roots: Array[Node3D] = []
var sample_leaves: Array[Node3D] = []
var sample_origins: Array[Vector3] = []
var sample_begins: Array[float] = []
var sample_rates: Array[float] = []
var binding_rates: Array[float] = []
var binding_offsets: Array[float] = []
var orbit_enabled := PackedByteArray()
var orbit_phases: Array[float] = []
var orbit_speeds: Array[float] = []
var orbit_radii: Array[float] = []
var previous_world: Array[Transform3D] = []
var world_initialized := PackedByteArray()


static func preparation_resources(input: Dictionary) -> Array:
	return preload("res://assets/vfx/extensions/spirit-runtime-20261021/sources/aa6d31e0db538a4bab5e/assembly.gd").preparation_resources(input)


static func make_component(input: Dictionary) -> Node3D:
	if str(input.get("owner_uuid", "")).is_empty():
		return null
	var node: Node3D = VfxPackageIO_c2cdc14a17.resource("res://assets/vfx/extensions/spirit-runtime-20261021/sources/c2cdc14a1757aa6e9391/field_v3.gd").new()
	node.owner_uuid = input.owner_uuid
	node.selections = input.entries.duplicate(true)
	node.opacity_control = input.get("opacity_control", false)
	return node


func _prepare() -> void:
	super._prepare()
	for entry: Dictionary in entries:
		var bindings: Array = entry.composition.bindings
		if not entry.source_materials.is_empty() or bindings.size() != 1 or bindings[0].kind != "sample":
			return
	for entry: Dictionary in entries:
		var selected: Dictionary = entry.definition
		var binding: Dictionary = entry.composition.bindings[0]
		sample_roots.append(entry.root)
		sample_leaves.append(binding.node)
		sample_origins.append(entry.origin)
		sample_begins.append(float(selected.get("begin", 0.0)))
		sample_rates.append(float(selected.get("rate", 1.0)))
		binding_rates.append(float(binding.rate))
		binding_offsets.append(float(binding.offset_seconds))
		var orbit: Dictionary = selected.get("orbit", {})
		orbit_enabled.append(int(selected.has("orbit")))
		orbit_phases.append(float(orbit.get("phase", 0.0)))
		orbit_speeds.append(float(orbit.get("speed", 0.0)))
		orbit_radii.append(float(orbit.get("radius", 0.0)))
		previous_world.append(Transform3D())
		world_initialized.append(0)
	direct_sampling = true


func sample(seconds: float) -> void:
	if not prepared:
		_prepare()
	if not direct_sampling:
		super.sample(seconds)
		return
	visible = is_finite(seconds) and seconds >= 0.0 and anchor_world != null and ZoneInput.admitted(owner_state)
	if not visible:
		sampled_input = false
		return
	var age := float(owner_state.owner_age_seconds)
	if sampled_input and sampled_age == age and sampled_anchor == anchor_world and sampled_world == global_transform:
		return
	global_position = anchor_world
	for index: int in sample_roots.size():
		var entry_root: Node3D = sample_roots[index]
		entry_root.visible = age >= sample_begins[index]
		if not entry_root.visible:
			continue
		if orbit_enabled[index]:
			var angle: float = orbit_phases[index] + age * orbit_speeds[index]
			entry_root.position = sample_origins[index] + Vector3(cos(angle) * orbit_radii[index], 0.0, sin(angle) * orbit_radii[index])
			entry_root.rotation.y = -angle + PI
		OwnerGraph.native_sampler_scopes += 1
		# Keep both authored time transformations in their original order.
		var composition_time: float = (age - sample_begins[index]) * sample_rates[index]
		var local_time: float = composition_time * binding_rates[index] + binding_offsets[index]
		sample_leaves[index].sample(local_time)
		OwnerGraph.native_sampler_scopes -= 1
		var world: Transform3D = entry_root.global_transform
		if not world_initialized[index] or previous_world[index] != world:
			previous_world[index] = world
			world_initialized[index] = 1
			entries[index].last_transform = world
	sampled_age = age
	sampled_anchor = anchor_world
	sampled_world = global_transform
	sampled_input = true

const VfxPackageIO_c2cdc14a17 = preload("res://assets/vfx/extensions/spirit-runtime-20261021/scoped_resource_io.gd")
