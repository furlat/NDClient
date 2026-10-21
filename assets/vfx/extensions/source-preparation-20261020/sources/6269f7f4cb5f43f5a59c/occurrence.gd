extends Node3D
## Complete phase constructor seam. Only input/clock updates happen at runtime;
## the source component remains the owner of geometry/material equations.
const Source = preload("res://assets/vfx/extensions/source-preparation-20261020/sources/19d3ab4a81370ca2150c/source_bridge.gd")
const Clock = preload("res://assets/vfx/sources/c0017ad639184b208deb/occurrence_clock.gd")
const Profile = preload("res://assets/vfx/sources/5e6062cb1efe781a65b7/construction_profile.gd")
const Bindings = preload("res://assets/vfx/sources/dabf568b4506db4883ad/occurrence_bindings.gd")
var handle: Dictionary = {}
var clock: RefCounted
var previous_age := 0.0
var construction_error := ""
var parameters: Dictionary = {}
var materials_dirty := false
var input_receivers: Dictionary = {}
var inputs_dirty := true
var construction_profile: Dictionary = {}
var material_sites: Array = []
var material_signature: Array = []
var topology_dirty := true
var supplied_material_revision: Variant
var binding_stats := {"material_scans": 0, "slot_probes": 0, "input_scans": 0}


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = VfxPackageIO_6269f7f4cb.resource("res://assets/vfx/extensions/source-preparation-20261020/sources/6269f7f4cb5f43f5a59c/occurrence.gd").new()
	instance.parameters = input.duplicate(true)
	return instance


func _enter_tree() -> void:
	# Initial Source.make performs a complete synchronous discovery. Its tree
	# notifications can only dirty maps that _construct immediately replaces.
	# Re-entered owners already have a handle and still observe tree changes.
	if not handle.is_empty():
		_subscribe_tree()


func _subscribe_tree() -> void:
	if not get_tree().node_added.is_connected(_node_added):
		get_tree().node_added.connect(_node_added)
	if not get_tree().node_removed.is_connected(_node_removed):
		get_tree().node_removed.connect(_node_removed)


func _ready() -> void:
	var previous: RefCounted = Profile.current
	var profiling: bool = parameters.get("profile_construction", false)
	if profiling:
		Profile.current = Profile.new()
	Profile.begin("occurrence_ready")
	_construct()
	_subscribe_tree()
	Profile.end("occurrence_ready")
	if profiling:
		construction_profile = Profile.current.report()
	Profile.current = previous


func _construct() -> void:
	# Source components with _ready-created condition layers must complete
	# their normal tree lifecycle before the source sampler discovers bindings.
	Profile.begin("phase_resolution")
	var clip: Dictionary = construction_clip()
	Profile.end("phase_resolution")
	handle = Source.make(self, clip, int(parameters.get("layer_mask", 2)))
	construction_error = handle.error
	if not construction_error.is_empty():
		return
	var materials := []
	var seen := {}
	Profile.begin("occurrence_material_discovery")
	if handle.has("materials"):
		materials = handle.materials
	else:
		for node in handle.root.find_children("*", "Node", true, false):
			_collect_materials(node, seen, materials)
	Profile.end("occurrence_material_discovery")
	clock = Clock.new()
	Profile.begin("clock_preparation")
	clock.prepare(materials)
	Profile.end("clock_preparation")
	materials_dirty = false
	material_sites = Bindings.sites(handle.root)
	if not handle.get("static_material_topology", false):
		material_signature = Bindings.signature(material_sites)
	topology_dirty = false
	Profile.begin("input_receiver_binding")
	refresh_input_bindings()
	Profile.end("input_receiver_binding")
	handle.root.show()


func construction_clip() -> Dictionary:
	var phase: Resource = VfxPackageIO_6269f7f4cb.resource(parameters.phase_path)
	return phase.to_clip()


func _node_added(node: Node) -> void:
	if is_ancestor_of(node):
		if handle.has("live_geometry_bindings"):
			Source.note_live_geometry_change(handle,node)
		materials_dirty = true
		inputs_dirty = true
		topology_dirty = true


func _node_removed(node: Node) -> void:
	if node in material_sites or is_ancestor_of(node):
		if handle.has("live_geometry_bindings"):
			Source.note_live_geometry_change(handle,node)
		notify_topology_changed()


func refresh_input_bindings() -> void:
	# Resolve receiver identities once, never traverse the hierarchy on every
	# disclosed owner-state tick. Late-created body layers invalidate this map.
	input_receivers.clear()
	binding_stats.input_scans += 1
	for node in handle.root.find_children("*", "Node", true, false):
		var script: Script = node.get_script()
		if script == null:
			continue
		for method_name in Bindings.methods(script):
			if not input_receivers.has(method_name):
				input_receivers[method_name] = []
			input_receivers[method_name].append(node)
	inputs_dirty = false


func refresh_material_bindings() -> void:
	binding_stats.material_scans += 1
	var materials := []
	var seen := {}
	for node in handle.root.find_children("*", "Node", true, false):
		_collect_materials(node, seen, materials)
	clock.prepare(materials)
	clock.retain_materials(materials)
	materials_dirty = false
	if topology_dirty:
		material_sites = Bindings.sites(handle.root)
		topology_dirty = false
	material_signature = Bindings.signature(material_sites)


func _refresh_declared_live_materials() -> void:
	# Called only after LiveGeometry.refresh validated every actual mesh slot,
	# owner claim and prepared interface and replaced the exact native roster.
	# Unknown/mixed conservative sources retain the original recursive path.
	if not handle.get("static_material_topology", false):
		refresh_material_bindings()
		return
	binding_stats.material_scans += 1
	clock.prepare(handle.materials)
	clock.retain_materials(handle.materials)
	materials_dirty = false
	material_sites = handle.geometry.map(func(entry: Dictionary) -> Node: return entry.node)
	topology_dirty = false
	# This exact declared topology never probes a material identity signature.
	material_signature = []


func set_material_revision(value: Variant) -> void:
	if value != supplied_material_revision:
		supplied_material_revision = value
		materials_dirty = true


func notify_topology_changed() -> void:
	topology_dirty = true
	materials_dirty = true
	inputs_dirty = true


func _ensure_material_bindings() -> void:
	if not materials_dirty and not handle.get("static_material_topology", false):
		binding_stats.slot_probes += 1
		materials_dirty = Bindings.signature(material_sites) != material_signature
	if materials_dirty:
		refresh_material_bindings()


static func _collect_materials(value: Object, seen: Dictionary, materials: Array) -> void:
	if seen.has(value):
		return
	seen[value] = true
	if value is Material:
		materials.append(value)
	for property in value.get_property_list():
		if int(property.usage) & PROPERTY_USAGE_STORAGE:
			var child: Variant = value.get(property.name)
			if child is Resource and not child is Script:
				_collect_materials(child, seen, materials)
	if value is Mesh:
		for surface in value.get_surface_count():
			var material: Material = value.surface_get_material(surface)
			if material != null:
				_collect_materials(material, seen, materials)


func sample(seconds: float) -> void:
	if not construction_error.is_empty():
		return
	# Exact opt-in mesh sources can replace supplied topology. Register their
	# private materials on THIS owner clock before their callback displays them.
	# Default sources perform no new discovery or interface reflection here.
	if handle.has("live_geometry_bindings") and Source.refresh_live_geometry(handle):
		_refresh_declared_live_materials()
		Source.acknowledge_live_geometry(handle,clock)
	if not handle.get("error","").is_empty():
		construction_error = handle.error
		return
	Source.sample(handle, seconds, maxf(0.0, seconds - previous_age), seconds)
	if not handle.get("error","").is_empty():
		construction_error = handle.error
		return
	_ensure_material_bindings()
	clock.sample(seconds)
	previous_age = seconds


func forward(method: String, value: Variant) -> void:
	if handle.is_empty() or not is_instance_valid(handle.get("root")):
		return
	if inputs_dirty:
		refresh_input_bindings()
	for node in input_receivers.get(method, []):
		if is_instance_valid(node):
			node.call(method, value)
			# Some adaptive inputs are consumed by the following source sample.
			# A held display age must not silently discard that placement update.
			# Only explicit source refresh hooks consume this flag; native particle
			# time remains owned by the normal advancing sample/post-draw pair.
			handle.source_inputs_dirty = true


func set_actor_layers(value: Dictionary) -> void:
	forward("set_actor_layers", value)


func set_weapon_motion(value: Dictionary) -> void:
	forward("set_weapon_motion", value)


func set_weapon_hit(value: Dictionary) -> void:
	forward("set_weapon_hit", value)


func set_weapon_impact(value: Dictionary) -> void:
	forward("set_weapon_impact", value)


func set_weapon_binding(value: Dictionary) -> void:
	forward("set_weapon_binding", value)


func set_targets(value: Array) -> void:
	forward("set_live_endpoints", value)


func set_live_endpoints(value: Array) -> void:
	set_targets(value)


func set_recipient_geometry(value: Dictionary) -> void:
	forward("set_entity_geometry", value)
	# Body components can create their material on the first measured pose.
	# Bind those shaders to the existing occurrence slot, never a second slot.
	if clock != null:
		_ensure_material_bindings()


func set_entity_geometry(value: Dictionary) -> void:
	set_recipient_geometry(value)


func set_owner_state(value: Dictionary) -> void:
	forward("set_lifecycle_context", value)
	forward("set_owner_state", value)


func set_lifecycle_context(value: Dictionary) -> void:
	set_owner_state(value)


func set_delivery_timing(launch: float, travel: float) -> void:
	if inputs_dirty:
		refresh_input_bindings()
	for node in input_receivers.get("set_delivery_timing", []):
		if is_instance_valid(node):
			node.set_delivery_timing(launch, travel)
			handle.source_inputs_dirty = true


func set_root_path(value: Transform3D) -> void:
	global_transform = value
	forward("set_root_path", value)


func _exit_tree() -> void:
	if get_tree().node_added.is_connected(_node_added):
		get_tree().node_added.disconnect(_node_added)
	if get_tree().node_removed.is_connected(_node_removed):
		get_tree().node_removed.disconnect(_node_removed)
	if clock != null:
		clock.release()

const VfxPackageIO_6269f7f4cb = preload("res://assets/vfx/extensions/source-preparation-20261020/scoped_resource_io.gd")
