extends Node3D
## Prepared condition scene. Source constructors and shader graph discovery run
## offline. Owner updates are a dictionary assignment and one clock texel.
const Clock = preload("res://assets/vfx/sources/c0017ad639184b208deb/occurrence_clock.gd")
const Surface = preload("res://assets/vfx/conditions/surface.gd")
const Cells = preload("res://assets/vfx/conditions/cells.gd")
const Measured = preload("res://assets/vfx/conditions/measured.gd")
const BodyReceiver = preload("res://assets/vfx/conditions/body_receiver.gd")
const Contour = preload("res://assets/vfx/conditions/contour.gd")
const WebBody = preload("res://assets/vfx/conditions/web_body.gd")
const LivePose = preload("res://assets/vfx/conditions/live_pose.gd")
const FlameBlade = preload("res://assets/vfx/conditions/flame_blade.gd")
const FlyAppearance = preload("res://assets/vfx/conditions/fly_appearance.gd")
const ActorHistory = preload("res://assets/vfx/conditions/actor_history.gd")
const CompoundSurface = preload("res://assets/vfx/conditions/compound_surface.gd")
static var scenes: Dictionary = {}
var parameters: Dictionary = {}
var handle: Dictionary = {}
var construction_error := ""
var context: Dictionary = {}
var slot := -1
var particle_materials: Array[ShaderMaterial] = []
var receiving: RefCounted
var cells: RefCounted
var body_treatment: RefCounted
var standard_geometry: Array = []
var event_state: Dictionary = {}
var event_binding: Dictionary = {}
var event_admitted := false
var event_ages: Dictionary = {}
var event_cursor := -1
var current_event_key := ""
var current_event_serial := ""
var appearance: RefCounted
var actor_history: RefCounted
var live_pose: RefCounted


func _ready() -> void:
	Clock.ensure_pool()
	if Clock.free_slots.is_empty():
		construction_error = "Condition clock capacity exceeded"
		return
	slot = Clock.free_slots.pop_back()
	if not scenes.has(parameters.scene):
		scenes[parameters.scene] = VfxPackageIO_9a96cad58c.resource(parameters.scene)
	var scene: PackedScene = scenes[parameters.scene]
	var visual: Node3D = scene.instantiate()
	add_child(visual)
	handle = {"root": visual, "geometry": [], "emitters": [], "light_units": {},
		"opacity_bindings": [], "players": [], "error": "", "clip": {}, "initialized": true}
	for path in parameters.geometry:
		var node: GeometryInstance3D = visual.get_node(path)
		if node.material_override is ShaderMaterial:
			# PackedScene duplicates these small private materials automatically;
			# shaders/textures/meshes remain shared. A borrowed body material
			# retains the same clock slot when attached to the recipient surface.
			node.material_override.set_shader_parameter("vfx_condition_slot", slot)
		elif node.material_override is BaseMaterial3D:
			standard_geometry.append({"node":node,"transparency":node.transparency})
		handle.geometry.append({"node": node, "path": path, "selected": node.visible,
			"layer_enabled": node.layers != 0})
		if node.layers != 0:
			node.layers = int(parameters.get("layer_mask", 2))
	for path in parameters.emitters:
		var node: GPUParticles3D = visual.get_node(path)
		var material: ShaderMaterial = node.process_material
		material.set_shader_parameter("clock_slot", slot)
		node.process_material = material
		particle_materials.append(material)
		node.one_shot = false
		node.emitting = true
		handle.emitters.append(node)
	if not parameters.get("adaptive_surface", {}).is_empty():
		if parameters.adaptive_surface.kind == "flame_blade":
			receiving = FlameBlade.new()
		elif parameters.adaptive_surface.kind == "measured":
			receiving = Measured.new()
		elif parameters.adaptive_surface.kind == "contour":
			receiving = Contour.new()
		elif parameters.adaptive_surface.kind == "web_body":
			receiving = WebBody.new()
		elif parameters.adaptive_surface.kind == "compound":
			receiving = CompoundSurface.new()
		else:
			receiving = Surface.new()
		receiving.configure(visual, parameters.adaptive_surface, handle.geometry)
	if parameters.get("cell_mask", false):
		cells = Cells.new()
		cells.configure(handle.geometry)
	if parameters.has("actor_operation"):
		body_treatment = BodyReceiver.new()
		body_treatment.configure(parameters.actor_operation, slot, get_instance_id(), self)
	if parameters.has("live_pose"):
		live_pose = LivePose.new()
		live_pose.configure(visual,parameters.live_pose)
	if parameters.has("actor_history"):
		actor_history = ActorHistory.new()
		var history_settings: Dictionary = parameters.actor_history.duplicate(false)
		history_settings.layer_mask = int(parameters.get("layer_mask",2))
		actor_history.configure(self,history_settings,slot)
	sample(0.0)


func set_owner_state(value: Dictionary) -> void:
	# No node/resource discovery, duplicate(true), phase rebuilding or replay.
	context = value
	if value.has("created_item_identity") and receiving != null and receiving.has_method("set_created_item_identity"):
		receiving.set_created_item_identity(value.created_item_identity)


func set_lifecycle_context(value: Dictionary) -> void:
	set_owner_state(value)


func sample(seconds: float) -> void:
	if slot < 0:
		return
	# Never display an offline recipient or a full unsuppressed net when
	# its actual body/cell input has not been supplied. Outer owner/display
	# selection remains the client's responsibility.
	handle.root.visible = (receiving == null or receiving.admitted_geometry) and (cells == null or cells.admitted) and (live_pose == null or live_pose.admitted)
	var phase: String = context.get("phase", parameters.get("phase", "application"))
	var phase_age: float = context.get("phase_age_seconds", seconds)
	var application: float = parameters.application_seconds
	var period: float = parameters.loop_seconds
	var held_age := maxf(0.0, seconds - application)
	var sustain_gain: float = parameters.get("sustain_gain", 1.0)
	var opacity := sustain_gain
	if phase == "application":
		opacity = smoothstep(0.0, application, phase_age) * lerpf(1.0, sustain_gain, smoothstep(application * .4, application, phase_age))
		# Continue the captured source motion during onset and meet the hold
		# at phase zero; the particles/materials never become a faded still.
		held_age = (clampf(phase_age / application, 0.0, 1.0) - 1.0) * minf(.4, application)
	elif phase == "removal":
		# Keep the actual held loop phase, including on a seek/rebuild. There
		# is no return to phase zero and no application/removal scene swap.
		held_age = maxf(0.0, float(context.get("removal_started_at_owner_age_seconds", seconds - phase_age)) - application + phase_age)
		opacity = sustain_gain * (1.0 - smoothstep(0.0, float(parameters.removal_seconds), phase_age))
	var loop_age := fposmod(held_age, period)
	if parameters.has("event_gate"):
		var gate: Dictionary = parameters.event_gate
		var allowed := event_admitted
		var age := float(event_state.get("phase_age_seconds",INF))+seconds-float(event_state.get("owner_age_seconds",seconds))
		if gate.get("kind","event") != "readiness":
			var duration := float(gate.get("accent_seconds",.35))
			allowed = allowed and age >= 0.0 and age < duration
			opacity *= smoothstep(0.0,float(gate.get("envelope",{}).get("attack_seconds",.03)),age)*(1.0-smoothstep(duration-float(gate.get("envelope",{}).get("release_seconds",.09)),duration,age)) if allowed else 0.0
			loop_age = fposmod(age,period) if allowed else 0.0
		elif not allowed:
			opacity = 0.0
	Clock.image.set_pixel(slot, 0, Color(loop_age, opacity,
		clampf(phase_age / application, 0.0, 1.0) if phase == "application" else 1.0,
		0.0 if phase == "application" else 1.0))
	if appearance != null: appearance.sample(opacity)
	handle.root.visible = handle.root.visible and opacity > (1.0/255.0)
	Clock.dirty = true
	if actor_history != null:
		actor_history.sample(seconds)
	# StandardMaterial3D's original PBR program is retained. The native instance
	# transparency is a bounded cached-property update, never a material/tree
	# search or source simulation. Its actual cost is measured in the bench.
	for geometry in standard_geometry:
		geometry.node.transparency = 1.0-(1.0-float(geometry.transparency))*opacity


func set_entity_geometry(value: Dictionary) -> void:
	if receiving != null:
		receiving.update(value)
		if parameters.has("event_gate"): set_event_state(event_state)


func set_admitted_cells(value: Array) -> bool:
	return cells.update(value) if cells != null else false


func set_created_item_identity(value: Dictionary) -> void:
	if receiving != null and receiving.has_method("set_created_item_identity"):
		receiving.set_created_item_identity(value)


func set_weapon_binding(value: Dictionary) -> void:
	if receiving != null and receiving.has_method("set_weapon_binding"):
		receiving.set_weapon_binding(value)
		if parameters.has("event_gate"): set_event_state(event_state)


func set_appearance_provider(value: Dictionary) -> bool:
	if not parameters.has("appearance_operation"): return false
	if appearance == null: appearance = FlyAppearance.new()
	return appearance.configure(value.get("provider"),get_instance_id(),str(value.get("actor_uuid","")))


func set_event_binding(value: Dictionary) -> void:
	if value != event_binding:
		event_ages.clear()
		event_cursor = -1
		current_event_key = ""
		current_event_serial = ""
		event_state = {}
		event_admitted = false
	event_binding = value
	set_event_state(event_state)


func set_event_state(value: Dictionary) -> void:
	event_state = value
	event_admitted = false
	if not parameters.has("event_gate"): return
	var gate: Dictionary = parameters.event_gate
	if not value.get("observed") is bool or not value.observed or not value.get("active") is bool: return
	for name in ["condition_uuid","source_actor_uuid"]:
		if str(event_binding.get(name,"")).is_empty() or event_binding[name] != value.get(name): return
	if not value.get("observation_revision") is int: return
	var revision := int(value.observation_revision)
	if revision < 0 or revision < event_cursor: return
	if not value.active:
		# Retirement may clear action/item/region fields. Admit only an exact
		# observed current-event tombstone, never an arbitrary false packet.
		if current_event_serial.is_empty() or value.get("event_serial") != current_event_serial: return
		event_cursor = revision
		event_ages[current_event_key] = INF
		return
	for name in gate.get("required_fields",[]):
		if not value.has(name): return
		var item: Variant = value[name]
		if item == null or (item is String and item.is_empty()) or (item is Array and item.is_empty()): return
	for name in gate.get("match",{}):
		var expected: Variant = gate.match[name]
		var actual: Variant = value.get(name)
		if expected is String and expected == "nonempty":
			if actual == null or str(actual).is_empty(): return
		elif expected is Array:
			if actual not in expected: return
		elif actual != expected: return
	if "item_uuid" in gate.get("required_fields",[]):
		if receiving == null or receiving.weapon_binding.get("item_uuid") != value.item_uuid: return
		if receiving.weapon_binding.get("holder_uuid") != value.get("holder_uuid"): return
		if value.get("holder_uuid") != value.get("source_actor_uuid"): return
	if receiving != null and receiving.get("current_surface") is Dictionary:
		var expected_actor: String = str(value.get("recipient_uuid","")) if gate.kind == "committed_miss_damage" else str(value.source_actor_uuid)
		if receiving.current_surface.get("actor") != expected_actor: return
	var owner_age: Variant = value.get("owner_age_seconds")
	if (not owner_age is float and not owner_age is int) or not is_finite(float(owner_age)): return
	var age_value: Variant = value.get("phase_age_seconds")
	if not age_value is float and not age_value is int: return
	if receiving != null and receiving.get("current_surface") is Dictionary:
		var surface: Dictionary = receiving.current_surface
		var expected_region := "mouth" if gate.kind == "readiness" else "damage_contact" if gate.kind == "committed_miss_damage" else "weapon"
		if gate.kind in ["readiness","committed_miss_damage"]:
			if surface.get("region_id") != expected_region: return
			var revision_name := "mouth_surface_revision" if gate.kind == "readiness" else "contact_surface_revision"
			if value.get(revision_name) != surface.get("region_revision",surface.get("gpu_geometry_key")): return
	var age := float(age_value)
	if not is_finite(age) or age < 0.0: return
	var serial := str(value.get("event_serial",""))
	if gate.has("deduplicate_by"):
		serial = ""
		for name in str(gate.deduplicate_by).split("+"):
			serial += str(value.get(name.strip_edges(),""))+":"
	if not current_event_key.is_empty() and serial != current_event_key and revision <= event_cursor: return
	if serial != current_event_key and event_ages.has(serial): return
	if event_ages.has(serial) and age < float(event_ages[serial])-.00001: return
	if gate.kind == "committed_miss_damage" and float(value.get("damage_amount",0.0)) <= 0.0: return
	event_ages[serial] = age
	if event_ages.size()>32: event_ages.erase(event_ages.keys()[0])
	event_cursor = revision
	current_event_key = serial
	current_event_serial = str(value.get("event_serial",""))
	event_admitted = true


func set_actor_context(value: Dictionary) -> bool:
	return actor_history.set_actor_context(value) if actor_history != null else false


func prepare_actor_context(value: Dictionary) -> Dictionary:
	return actor_history.prepare_actor_context(value) if actor_history != null else {"ready": true}


func set_history_state(value: Dictionary) -> void:
	if actor_history != null: actor_history.set_history_state(value)


func set_actor_layers(value: Dictionary) -> bool:
	return body_treatment.set_actor_layers(value) if body_treatment != null else false


func set_pose_provider(value: Dictionary) -> bool:
	return body_treatment.set_pose_provider(value) if body_treatment != null else false


func set_treatment_state(value: Dictionary) -> void:
	if body_treatment != null:
		body_treatment.set_treatment_state(value)


func set_targets(value: Array) -> void:
	if receiving == null:
		return
	var surface := {}
	var recipient := ""
	for target in value:
		if target is Dictionary and target.has("surface"):
			var supplied: Dictionary = target.surface
			var identity := str(supplied.get("entity_uuid", supplied.get("actor_uuid", supplied.get("actor", ""))))
			if not surface.is_empty() and (identity.is_empty() or identity != recipient):
				# A condition occurrence has one recipient. An ambiguous cast
				# target array must not quietly choose another creature's body.
				receiving.update({})
				return
			surface = supplied
			recipient = identity
	set_entity_geometry(surface)


func set_live_endpoints(value: Array) -> void:
	if live_pose != null:
		live_pose.update(value)
	set_targets(value)


func set_root_path(value: Transform3D) -> void:
	global_transform = value
	if live_pose != null and not live_pose.last_endpoints.is_empty():
		live_pose.update(live_pose.last_endpoints)


func _exit_tree() -> void:
	if appearance != null: appearance.clear()
	if actor_history != null: actor_history.close()
	if body_treatment != null:
		body_treatment.clear()
	if slot >= 0:
		Clock.free_slots.append(slot)
		slot = -1

const VfxPackageIO_9a96cad58c = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
