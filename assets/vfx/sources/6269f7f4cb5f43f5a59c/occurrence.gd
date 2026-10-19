extends Node3D
## Complete phase constructor seam. Only input/clock updates happen at runtime;
## the source component remains the owner of geometry/material equations.
const Source = preload("res://assets/vfx/sources/19d3ab4a81370ca2150c/source_bridge.gd")
const Clock = preload("res://assets/vfx/sources/c0017ad639184b208deb/occurrence_clock.gd")
var handle: Dictionary = {}
var clock: RefCounted
var previous_age := 0.0
var construction_error := ""
var parameters: Dictionary = {}
var materials_dirty := false
var input_receivers: Dictionary = {}
var inputs_dirty := true


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = VfxPackageIO_6269f7f4cb.resource("res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd").new()
	instance.parameters = input.duplicate(true)
	return instance


func _enter_tree() -> void:
	get_tree().node_added.connect(_node_added)


func _ready() -> void:
	# Source components with _ready-created condition layers must complete
	# their normal tree lifecycle before the source sampler discovers bindings.
	handle = Source.make(self, construction_clip(), int(parameters.get("layer_mask", 2)))
	construction_error = handle.error
	if not construction_error.is_empty():
		return
	var materials := []
	var seen := {}
	for node in handle.root.find_children("*", "Node", true, false):
		_collect_materials(node, seen, materials)
	clock = Clock.new()
	clock.prepare(materials)
	materials_dirty = false
	refresh_input_bindings()
	handle.root.show()


func construction_clip() -> Dictionary:
	var phase: Resource = VfxPackageIO_6269f7f4cb.resource(parameters.phase_path)
	return phase.to_clip()


func _node_added(node: Node) -> void:
	if is_ancestor_of(node):
		materials_dirty = true
		inputs_dirty = true


func refresh_input_bindings() -> void:
	# Resolve receiver identities once, never traverse the hierarchy on every
	# disclosed owner-state tick. Late-created body layers invalidate this map.
	input_receivers.clear()
	for node in handle.root.find_children("*", "Node", true, false):
		var script: Script = node.get_script()
		if script == null:
			continue
		while script != null:
			for method in script.get_script_method_list():
				var method_name: String = method.name
				if method_name.begins_with("set_") or method_name == "body_surface_sample":
					if not input_receivers.has(method_name):
						input_receivers[method_name] = []
					if node not in input_receivers[method_name]:
						input_receivers[method_name].append(node)
			script = script.get_base_script()
	inputs_dirty = false


func refresh_material_bindings() -> void:
	var materials := []
	var seen := {}
	for node in handle.root.find_children("*", "Node", true, false):
		_collect_materials(node, seen, materials)
	clock.prepare(materials)
	materials_dirty = false


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
	Source.sample(handle, seconds, maxf(0.0, seconds - previous_age), seconds)
	if materials_dirty:
		refresh_material_bindings()
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


func set_targets(value: Array) -> void:
	forward("set_live_endpoints", value)


func set_live_endpoints(value: Array) -> void:
	set_targets(value)


func set_recipient_geometry(value: Dictionary) -> void:
	forward("set_entity_geometry", value)
	# Body components can create their material on the first measured pose.
	# Bind those shaders to the existing occurrence slot, never a second slot.
	refresh_material_bindings()


func set_entity_geometry(value: Dictionary) -> void:
	set_recipient_geometry(value)


func set_owner_state(value: Dictionary) -> void:
	forward("set_lifecycle_context", value)
	forward("set_owner_state", value)


func set_lifecycle_context(value: Dictionary) -> void:
	set_owner_state(value)


func set_delivery_timing(launch: float, travel: float) -> void:
	for node in handle.root.find_children("*", "Node", true, false):
		if node.has_method("set_delivery_timing"):
			node.set_delivery_timing(launch, travel)


func set_root_path(value: Transform3D) -> void:
	global_transform = value


func _exit_tree() -> void:
	if get_tree().node_added.is_connected(_node_added):
		get_tree().node_added.disconnect(_node_added)
	if clock != null:
		clock.release()

const VfxPackageIO_6269f7f4cb = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
