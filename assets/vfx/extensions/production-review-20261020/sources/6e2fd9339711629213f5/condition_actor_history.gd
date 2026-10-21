extends RefCounted
## Live owner-held copies of real modular poses; immutable pose/material caches.
## Adaptive exception: bounded cached actor draw transforms, GPU composition.
## Offline copies of real modular poses. Compose each complete outfit before
## echo opacity, retaining source colour, slot order, equipment and geometry.
## No replacement character atlas, extra animation clock, receiver or game actor.
const SourceMaterials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
const Capture = preload("res://assets/vfx/extensions/production-review-20261020/sources/55cd7ae83a2e60843ea1/condition_history_capture.gd")
var SourceShader: Shader
var DepthShader: Shader

const EXCLUDED_SLOTS := ["shadow", "weaponGlow", "aura", "effect", "effect2", "effect3", "slash"]
## A prepared holder contains no body mesh/material references. Keep immutable
## compositor resources warm explicitly, rather than reloading/parsing them at
## every occurrence after the previous owner's last reference was released.
static var shared_resources: Dictionary = {}
var history: Dictionary = {}
var copies: Dictionary = {}
var preparing_copies: Dictionary = {}
var live_bodies: Dictionary = {}
var last_seconds: float = -1.0
var view_basis := Basis.IDENTITY
var owner: Node3D
var parameter_names: Dictionary = {}
var material_cache: Dictionary = {}
var depth_parameter_cache: Dictionary = {}
var pose_material_cache: Dictionary = {}
var packet: Dictionary = {}
var settings: Dictionary = {}
var parent: Node3D
var clock_slot := -1
var output_material: ShaderMaterial
var admitted := false
var captured_packet: Dictionary = {}
var departure_revision: Variant = null
var departure_capture_revision: Variant = null
var bound_actor_uuid := ""
var context: Context
var capture_serial := 0
var capture_error := ""
var capture_view_key: Array = []

class Context extends Node3D:
	var camera: Camera3D
	var elapsed := 0.0
	var release := 0.0
	var staging_spec: Dictionary = {}
	var visual_actors: Dictionary = {}
	var capture_size := Vector2i(960,640)
	var receiver_depth: Texture2D
	var actor_origin := Vector3.ZERO
	var actor_layers: Array = []
	var view_key: Array = []
	var pose_key: Variant
	var layer_mask := 2

func configure(node: Node3D, specification: Dictionary, slot: int) -> void:
	parent = node
	settings = specification
	clock_slot = slot
	output_material = shared_resource(specification.output_material)
	SourceShader = shared_resource(specification.source_shader)
	DepthShader = shared_resource(specification.depth_shader)
	context = Context.new()
	context.name = "ConditionActorHistoryContext"
	context.layer_mask = int(settings.get("layer_mask",2))
	context.staging_spec = {"review_actor_echoes": settings.specifications.duplicate(true)}
	parent.add_child(context)


static func shared_resource(path: String) -> Resource:
	if not shared_resources.has(path):
		shared_resources[path] = VfxPackageIO_6e2fd93397.resource(path)
	return shared_resources[path]


static func prepare_immutable_resources(specification: Dictionary) -> Dictionary:
	# Optional pre-publication Resource work. A real private actor/pass/history
	# is deliberately absent; the first actor binding must not pay for lazy
	# ShaderMaterial uniform reflection. Full pipeline warm drawing is separate.
	var rows := []
	# Colour uses the actual renderer's supplied layer material. The preserved
	# legacy source_shader is not displayed and must not incur warm-up work.
	for field in ["output_material", "depth_shader"]:
		var started := Time.get_ticks_usec()
		var value: Resource = shared_resource(str(specification[field]))
		var material: ShaderMaterial
		if value is ShaderMaterial:
			material = value
		elif value is Shader:
			material = ShaderMaterial.new()
			material.shader = value
		else:
			assert(false, "Actor compositor preparation requires an explicit material or shader")
		material.get_property_list()
		rows.append({"field": field, "path": specification[field], "us": Time.get_ticks_usec() - started})
	return {"steps": rows, "scope": "Immutable Resource/interface preparation only; no actor, Node, clock, history or sampled occurrence"}

func set_actor_context(value: Dictionary) -> bool:
	var actor_uuid := str(value.get("actor_uuid", ""))
	var departure: bool = settings.get("capture_departure",false)
	var same_actor := actor_uuid == bound_actor_uuid
	var held_departure := departure and same_actor and not captured_packet.is_empty()
	var capture_changed: bool = value.has("departure_capture_revision") and value.departure_capture_revision != departure_capture_revision
	var departure_layers: Array = value.get("departure_layers", [])
	admitted = value.get("camera") is Camera3D and value.get("receiver_depth") is Texture2D and value.get("depth_encoding", "") == "rgb24_reversed_z" and not actor_uuid.is_empty() and (not value.get("layers",[]).is_empty() or (departure and not departure_layers.is_empty()) or held_departure) and value.has("pose_key")
	# A new view of an absent actor must be supplied by its departure-pose
	# provider. Never replace the logical departure with a current live pose.
	if held_departure and capture_changed and departure_layers.is_empty():
		admitted = false
	if not admitted:
		packet = {}
		if is_instance_valid(owner):
			owner.hide()
			_suspend_passes()
		return false
	if not bound_actor_uuid.is_empty() and not same_actor:
		close()
		captured_packet.clear()
		departure_revision = null
		departure_capture_revision = null
	bound_actor_uuid = actor_uuid
	var logical_changed: bool = departure and value.has("departure_revision") and value.departure_revision != departure_revision
	if departure and (logical_changed or capture_changed):
		var held_origin: Variant = captured_packet.get("origin")
		var held_seconds: Variant = captured_packet.get("seconds")
		var held_clock: Variant = captured_packet.get("capture",{}).get("clock_image")
		close()
		captured_packet.clear()
		# A camera/material recapture changes optical layers, not admission
		# position. An explicit origin still allows the provider to rebase it.
		if not logical_changed:
			value = value.duplicate(false)
			if held_origin is Vector3 and not value.has("departure_origin"):
				value.departure_origin = held_origin
			if held_seconds is float:
				value.departure_source_seconds = held_seconds
			if held_clock is Image and not value.has("history_clock_image"):
				value.history_clock_image = held_clock
		departure_revision = value.get("departure_revision", departure_revision)
		departure_capture_revision = value.get("departure_capture_revision", departure_capture_revision)
	packet = value
	return true

func set_history_state(value: Dictionary) -> void:
	var count := clampi(int(value.get("duplicate_count",value.get("duplicates",3))),0,3)
	for index in context.staging_spec.review_actor_echoes.size():
		context.staging_spec.review_actor_echoes[index]["enabled"] = not settings.get("mirror",false) or index < count

func _suspend_passes() -> void:
	for poses: Array in history.values():
		for pose: Dictionary in poses:
			if pose.has("capture"): Capture.suspend(pose.capture)
	for group in copies.values():
		group.colour.viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		group.depth.viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	for pass_data in live_bodies.values():
		pass_data.viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	for group in preparing_copies.values():
		for channel in ["colour", "depth"]:
			if group.has(channel):
				group[channel].viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

func sample(seconds: float) -> void:
	if not admitted: return
	_bind_packet(seconds)
	if settings.get("capture_departure",false) and settings.get("mirror",false):
		if captured_packet.is_empty():
			captured_packet = _snapshot(context,"recipient")
		context.actor_layers = []
	_sample(context)
	if is_instance_valid(owner): owner.show()


func _bind_packet(seconds: float) -> void:
	context.camera = packet.camera
	context.receiver_depth = packet.receiver_depth
	context.capture_size = packet.get("capture_size", Vector2i(960,640))
	context.elapsed = seconds
	context.actor_origin = packet.get("departure_origin",packet.origin) if settings.get("capture_departure",false) else packet.origin
	context.pose_key = [packet.pose_key, packet.get("material_revision",0), departure_capture_revision]
	context.actor_layers = packet.get("departure_layers",packet.get("layers",[])) if settings.get("capture_departure",false) else packet.layers
	context.visual_actors = {"recipient": true}
	context.view_key = [context.capture_size, context.camera.global_transform]
	for property in ["projection", "keep_aspect", "size", "near", "far", "fov", "frustum_offset", "h_offset", "v_offset"]:
		context.view_key.append(context.camera.get(property))


## One private allocation unit per call. Existing packet; no new provider data,
## sampled history, fabricated departure, clock advance or occurrence prototype.
## The caller may run this optional source preparation before publishing a cue.
func prepare_actor_context(value: Dictionary) -> Dictionary:
	if not set_actor_context(value):
		return {"ready": false, "error": "Actor context not admitted"}
	_bind_packet(context.elapsed)
	if not is_instance_valid(owner):
		owner = Node3D.new()
		owner.name = "AssembledActorEchoes"
		context.add_child(owner)
		return {"ready": false, "stage": "owner"}
	if not live_bodies.has("recipient"):
		live_bodies.recipient = _prepared_pass(context, false)
		return {"ready": false, "stage": "live_body_viewport"}
	var live_step := _prepare_pass_step(live_bodies.recipient, context)
	if not live_step.ready:
		return {"ready": false, "stage": "live_body_" + str(live_step.stage)}
	for specification in context.staging_spec.review_actor_echoes:
		var key: String = specification.id
		if copies.has(key):
			for channel in ["colour", "depth"]:
				var existing_step := _prepare_pass_step(copies[key][channel], context)
				if not existing_step.ready:
					return {"ready": false, "stage": channel + "_" + str(existing_step.stage), "copy": key}
			continue
		if not preparing_copies.has(key):
			preparing_copies[key] = {"colour": _prepared_pass(context, false)}
			return {"ready": false, "stage": "colour", "copy": key}
		var group: Dictionary = preparing_copies[key]
		var colour_step := _prepare_pass_step(group.colour, context)
		if not colour_step.ready:
			return {"ready": false, "stage": "colour_" + str(colour_step.stage), "copy": key}
		if not group.has("depth"):
			group.depth = _prepared_pass(context, true)
			return {"ready": false, "stage": "depth", "copy": key}
		var depth_step := _prepare_pass_step(group.depth, context)
		if not depth_step.ready:
			return {"ready": false, "stage": "depth_" + str(depth_step.stage), "copy": key}
		copies[key] = _make_copy(context, "recipient", key, group)
		copies[key].output.hide()
		# Bind immutable authored finish settings during the explicit private
		# output allocation, not in the first displayed source sample. This does
		# not select a historical pose, advance a clock or show the output.
		_apply_output_parameters(copies[key], specification, context.receiver_depth)
		preparing_copies.erase(key)
		return {"ready": false, "stage": "output", "copy": key}
	return {"ready": true, "stage": "ready"}


func _prepared_pass(world: Node, depth: bool) -> Dictionary:
	var pass_data := _pass(world, depth)
	_sync_pass(pass_data, world)
	pass_data.viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	return pass_data


func _prepare_pass_step(pass_data: Dictionary, world: Node) -> Dictionary:
	# One native draw allocation per call, not an entire outfit + viewport +
	# shader binding in one unbounded preparation unit. No history is recorded.
	var required := 0
	var source_key := [world.pose_key, world.view_key]
	for layer in world.actor_layers:
		if not layer.get("node") is MeshInstance3D or layer.get("slot", "") in EXCLUDED_SLOTS or not layer.get("material") is ShaderMaterial:
			continue
		required += 1
		var node: MeshInstance3D = layer.node
		source_key.append([node.mesh, layer.material, node.global_transform,
			node.sorting_offset, layer.get("pivot", Vector3.ZERO),
			layer.get("ground_pixels", 19.0), layer.get("received_material")])
	if pass_data.draws.size() < required:
		var draw := MeshInstance3D.new()
		draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		draw.sorting_use_aabb_center = false
		draw.hide()
		pass_data.viewport.add_child(draw)
		pass_data.draws.append(draw)
		pass_data.prepared_pose_primed = false
		return {"ready": false, "stage": "draw"}
	if not pass_data.get("prepared_pose_primed", false) or pass_data.get("prepared_source_key") != source_key:
		_sync_pass(pass_data, world)
		_draw_pass(pass_data, _snapshot(world, "recipient"), Vector3.ZERO)
		pass_data.viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		pass_data.prepared_pose_primed = true
		pass_data.prepared_source_key = source_key
		return {"ready": false, "stage": "binding"}
	return {"ready": true}


func close() -> void:
	_clear_captures()
	if is_instance_valid(owner):
		owner.free()
	owner = null
	copies.clear()
	preparing_copies.clear()
	live_bodies.clear()
	history.clear()
	parameter_names.clear()
	material_cache.clear()
	depth_parameter_cache.clear()
	pose_material_cache.clear()
	last_seconds = -1.0
	capture_error = ""
	captured_packet.clear()
	capture_view_key.clear()


func _clear_captures() -> void:
	for poses: Array in history.values():
		for pose: Dictionary in poses:
			if pose.has("capture"): Capture.close(pose.capture)
	if captured_packet.has("capture"): Capture.close(captured_packet.capture)


## Actual source identity and completed draw identity are deliberately separate.
## A restored prefix supplies its original layers, clocks and dependency source
## descriptors; it never borrows a subsequently drawn current hit texture.
func capture_status() -> Dictionary:
	var records := []
	for poses: Array in history.values():
		for pose: Dictionary in poses:
			if pose.has("capture"): records.append(Capture.status(pose.capture))
	return {"error": capture_error, "captures": records, "held_departure": settings.get("capture_departure", false),
		"mirror_current_pose": settings.get("mirror", false), "retained_captures": records.size()}


func _capture_pose(world: Node, pose: Dictionary) -> bool:
	if pose.has("capture"):
		Capture.resume(pose.capture)
		capture_error = pose.capture.error
		if pose.capture.closed and capture_error.is_empty(): capture_error = "Immutable actor capture is already closed"
		return not pose.capture.closed and pose.capture.error.is_empty()
	if settings.get("mirror",false): return true
	var needed: bool = settings.get("capture_departure",false)
	for specification: Dictionary in world.staging_spec.review_actor_echoes:
		needed = needed or float(specification.get("delay",0.0)) > 0.0
	if not needed: return true
	var retained_count := 0
	for poses: Array in history.values():
		retained_count += poses.size()
	if retained_count >= int(settings.get("maximum_live_captures",64)):
		capture_error = "Immutable actor capture capacity reached; no required predecessor was silently dropped"
		return false
	capture_serial += 1
	if settings.get("capture_departure",false): pose.seconds = float(packet.get("departure_source_seconds",pose.seconds))
	var identity := {"request": capture_serial, "actor_uuid": bound_actor_uuid, "capture_owner_instance": parent.get_instance_id(),
		"source_seconds": pose.seconds, "requested_owner_seconds": world.elapsed, "pose_key": packet.pose_key, "material_revision": packet.get("material_revision",0),
		"departure_revision": departure_revision, "departure_capture_revision": departure_capture_revision,
		"provider_identity": packet.get("capture_identity",{}).duplicate(true)}
	if packet.has("condition_uuid"):
		identity.condition_uuid = packet.condition_uuid
	elif identity.provider_identity.has("condition_uuid"):
		identity.condition_uuid = identity.provider_identity.condition_uuid
	var record := Capture.request(self, world, pose, identity, packet.get("material_dependencies",[]), packet.get("history_clock_image"))
	pose.capture = record
	if not record.error.is_empty():
		capture_error = record.error
		return false
	else:
		capture_error = ""
		pose.layers = record.pose.layers
		pose.erase("draw_binding_key")
	if settings.get("capture_departure",false): captured_packet = pose
	return true


func _capture_key(world: Node) -> Array:
	var result := [world.elapsed, world.pose_key, world.view_key, packet.get("capture_identity",{})]
	for value: Dictionary in packet.get("material_dependencies",[]):
		result.append([value.get("identity"),value.get("seconds"),value.get("texture")])
	return result

func _echo_material(source: ShaderMaterial, shader: Shader) -> ShaderMaterial:
	var key := [source.get_instance_id(), shader.get_instance_id()]
	if material_cache.has(key): return material_cache[key]
	var material := ShaderMaterial.new()
	material.shader = shader
	# The immutable source program interface is shared; uniform values remain
	# those of the actual captured layer. No per-layer regex/compiler query.
	var names: Array = settings.depth_uniform_names if settings.has("depth_uniform_names") else SourceMaterials.declared_uniforms(shader)
	for name in names:
		var value: Variant = source.get_shader_parameter(name)
		if value != null:
			material.set_shader_parameter(name, value)
	material_cache[key] = material
	return material

func _pass(world: Node, depth: bool = false) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.use_hdr_2d = true
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	owner.add_child(viewport)
	var camera := Camera3D.new()
	viewport.add_child(camera)
	camera.environment = Environment.new()
	camera.environment.background_mode = Environment.BG_COLOR
	camera.environment.background_color = Color.BLACK
	return {"viewport": viewport, "camera": camera, "draws": [], "depth": depth}

func _sync_pass(pass_data: Dictionary, world: Node) -> void:
	if not world.view_key.is_empty() and pass_data.get("view_key") == world.view_key:
		return
	pass_data.view_key = world.view_key.duplicate(false)
	pass_data.viewport.size = world.capture_size
	pass_data.camera.global_transform = world.camera.global_transform
	for property in ["projection", "keep_aspect", "size", "near", "far", "fov", "frustum_offset", "h_offset", "v_offset"]:
		pass_data.camera.set(property, world.camera.get(property))

func _snapshot(world: Node, _actor: String) -> Dictionary:
	if settings.get("capture_departure",false) and not captured_packet.is_empty():
		var held := captured_packet.duplicate(false)
		if not held.has("capture"): held.seconds = world.elapsed
		return held
	var signature: Array = world.pose_key.duplicate() if world.pose_key is Array else [world.pose_key]
	var cached: Dictionary = pose_material_cache.get(signature,{})
	var layers: Array = []
	var draw_binding_key := []
	for entry in world.actor_layers:
		if not entry.get("node") is MeshInstance3D or entry.get("slot", "") in EXCLUDED_SLOTS or not entry.get("material") is ShaderMaterial:
			continue
		var node: MeshInstance3D = entry.node
		var source: ShaderMaterial = entry.material
		var identity := source.get_instance_id()
		if not cached.has(identity): cached[identity] = source.duplicate(false)
		var layer := {"mesh": node.mesh, "material": cached[identity],
			"transform": node.global_transform, "slot": entry.slot,
			"sorting_offset": node.sorting_offset, "pivot": entry.get("pivot",Vector3.ZERO),
			"ground_pixels": entry.get("ground_pixels", 19.0)}
		if entry.get("received_material") is ShaderMaterial:
			var received: ShaderMaterial = entry.received_material
			var received_id := received.get_instance_id()
			if not cached.has(received_id): cached[received_id] = received.duplicate(false)
			layer.received = cached[received_id]
		layers.append(layer)
		draw_binding_key.append([layer.mesh, layer.material, layer.transform, layer.sorting_offset])
	pose_material_cache[signature] = cached
	# History is <.25 seconds. Retain a bounded cache, never one allocation per
	# frame over the whole condition lifetime or mesh duplication at all.
	if pose_material_cache.size() > 64:
		pose_material_cache.erase(pose_material_cache.keys()[0])
		material_cache.clear()
		depth_parameter_cache.clear()
	return {"seconds":world.elapsed,"layers":layers,"origin":world.actor_origin,"draw_binding_key":draw_binding_key}

func _draw_pass(pass_data: Dictionary, pose: Dictionary, offset: Vector3) -> void:
	var layers: Array = pose.layers
	# An observed snapshot is immutable. Compute its exact layer identity once,
	# then share that value across the colour/depth passes and all delayed copies.
	# External test/empty poses still derive the identical key here.
	var source_key: Array = pose.get("draw_binding_key", [])
	if not pose.has("draw_binding_key"):
		for layer in layers:
			source_key.append([layer.mesh, layer.material, layer.transform, layer.sorting_offset])
	var binding_key: Array = [offset, source_key]
	if pass_data.get("binding_key") == binding_key:
		return
	var previous: Array = pass_data.get("binding_key", [])
	pass_data.binding_key = binding_key
	if previous.size() == 2 and previous[1] == source_key:
		# The captured outfit is immutable. Oscillating a copy changes only its
		# position; repeating mesh/material/depth-uniform discovery per layer
		# cannot change output. Preserve the original world-origin addition and
		# leave its already-bound basis, painter order and actual material intact.
		for index in layers.size():
			var transform: Transform3D = layers[index].transform
			pass_data.draws[index].global_position = transform.origin + offset
		return
	while pass_data.draws.size() < layers.size():
		var draw := MeshInstance3D.new()
		draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		draw.sorting_use_aabb_center = false
		pass_data.viewport.add_child(draw)
		pass_data.draws.append(draw)
	for index in pass_data.draws.size():
		var draw: MeshInstance3D = pass_data.draws[index]
		draw.visible = index < layers.size()
		if not draw.visible:
			continue
		var layer: Dictionary = layers[index]
		var material: ShaderMaterial
		if pass_data.depth:
			if not layer.has("depth_echo"):
				layer.depth_echo = layer.capture_depth if layer.has("capture_depth") else _echo_material(layer.material, DepthShader)
			material = layer.depth_echo
			var depth_key := [layer.material.render_priority, layer.pivot, layer.ground_pixels, layer.material.get_shader_parameter("component_units")]
			if depth_parameter_cache.get(material) != depth_key:
				material.render_priority = layer.material.render_priority
				material.set_shader_parameter("native_scene_pivot", layer.pivot)
				material.set_shader_parameter("native_scene_ground_height", float(layer.ground_pixels) * float(depth_key[3]))
				depth_parameter_cache[material] = depth_key
		else:
			# The provider supplied the approved current layer material. The pose
			# snapshot already owns a private copy. Retain its entire lighting,
			# tint, body-surface and impact path instead of substituting an older
			# source-colour shader or a legacy receiving-atlas reconstruction.
			material = layer.material
		if draw.mesh != layer.mesh:
			draw.mesh = layer.mesh
		if draw.material_override != material:
			draw.material_override = material
		if draw.sorting_offset != layer.sorting_offset:
			draw.sorting_offset = layer.sorting_offset
		var target: Transform3D = layer.transform
		target.origin += offset
		if draw.global_transform != target:
			draw.global_transform = target

func _make_copy(world: Node, actor: String, key: String, prepared: Dictionary = {}) -> Dictionary:
	var result := prepared if not prepared.is_empty() else {"colour": _pass(world), "depth": _pass(world, true)}
	var draw := MeshInstance3D.new()
	draw.name = "ActorEcho_"+key
	draw.mesh = QuadMesh.new()
	draw.mesh.size = Vector2(2,2)
	draw.layers = world.layer_mask
	draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	draw.sorting_use_aabb_center = false
	draw.custom_aabb = AABB(Vector3(-10000,-10000,-10000),Vector3(20000,20000,20000))
	draw.material_override = output_material.duplicate(false)
	draw.material_override.set_shader_parameter("vfx_condition_slot",clock_slot)
	draw.material_override.set_shader_parameter("echo_colour", result.colour.viewport.get_texture())
	draw.material_override.set_shader_parameter("echo_depth", result.depth.viewport.get_texture())
	draw.material_override.set_shader_parameter("receiver_depth", world.receiver_depth)
	draw.material_override.set_shader_parameter("live_body", live_bodies[actor].viewport.get_texture())
	owner.add_child(draw)
	result.output = draw
	return result


func _apply_output_parameters(group: Dictionary, specification: Dictionary, receiver_depth: Texture2D) -> void:
	var material: ShaderMaterial = group.output.material_override
	if group.get("output_parameters_material") != material or group.get("output_specification") != specification:
		# These are authored settings, not per-frame observations. Retain exact
		# values while avoiding repeated uniform writes/palette allocations for
		# every one of Blur's copies on every unchanged sample.
		group.output_parameters_material = material
		group.output_specification = specification.duplicate(true)
		material.set_shader_parameter("echo_opacity", float(specification.opacity))
		material.set_shader_parameter("protect_live_body", specification.get("protect_live_body", true))
		material.set_shader_parameter("echo_slot_phase", float(specification.get("slot_phase", 0.0)))
		material.set_shader_parameter("echo_wave_strength", float(specification.get("wave_strength", 0.0)))
		var spectral_palette: Array = specification.get("spectral_palette", [])
		var spectral_colours := PackedVector3Array()
		for rgb in spectral_palette:
			spectral_colours.append(Vector3((int(rgb) >> 16) & 255, (int(rgb) >> 8) & 255, int(rgb) & 255) / 255.0)
		if spectral_colours.size() == 4:
			material.set_shader_parameter("echo_spectral_palette", spectral_colours)
		material.set_shader_parameter("echo_spectral_maximum", float(specification.get("spectral_maximum", 170.0)) / 255.0)
		material.set_shader_parameter("echo_spectral_strength", float(specification.get("spectral_strength", 0.0)) if spectral_palette.size() == 4 else 0.0)
		var tint: Array = specification.get("tint", [1.0, 1.0, 1.0])
		material.set_shader_parameter("echo_tint", Vector3(tint[0], tint[1], tint[2]))
	if group.get("output_depth_material") != material or group.get("output_receiver_depth") != receiver_depth:
		group.output_depth_material = material
		group.output_receiver_depth = receiver_depth
		material.set_shader_parameter("receiver_depth", receiver_depth)


func _apply_output_mapping(group: Dictionary, world: Node, layer: Dictionary, offset: Vector3) -> void:
	var material: ShaderMaterial = group.output.material_override
	var mesh_size: Vector2 = layer.mesh.size
	var cell_size: Variant = layer.material.get_shader_parameter("material_cell_size")
	var key := [material, layer.transform, mesh_size, layer.mesh.center_offset, offset, world.view_key, cell_size]
	if group.get("output_mapping_key") == key:
		return
	group.output_mapping_key = key
	var top_left: Vector3 = layer.transform * (Vector3(-mesh_size.x * .5, mesh_size.y * .5, 0.0) + layer.mesh.center_offset) + offset
	var screen_size := Vector2(world.capture_size)
	var screen_origin: Vector2 = world.camera.unproject_position(top_left) / screen_size
	var axis_x: Vector2 = world.camera.unproject_position(top_left + layer.transform.basis.x * mesh_size.x) / screen_size - screen_origin
	var axis_y: Vector2 = world.camera.unproject_position(top_left - layer.transform.basis.y * mesh_size.y) / screen_size - screen_origin
	material.set_shader_parameter("echo_source_cell_size", cell_size)
	material.set_shader_parameter("echo_screen_origin", screen_origin)
	material.set_shader_parameter("echo_screen_axis_x", axis_x)
	material.set_shader_parameter("echo_screen_axis_y", axis_y)

func _sample(world: Node) -> void:
	var specifications: Array = world.staging_spec.get("review_actor_echoes", [])
	if specifications.is_empty():
		if is_instance_valid(owner):
			close()
		return
	# Facing sheets depend on the actual review camera. Never trail a stale view.
	var reversed: bool = world.elapsed < last_seconds-.00001
	var changed_view: bool = not capture_view_key.is_empty() and capture_view_key != world.view_key
	if changed_view and not reversed and captured_packet.has("capture"):
		capture_error = "Held departure view changes require actual departure layers and a new departure_capture_revision"
		_suspend_passes()
		for group: Dictionary in copies.values(): group.output.hide()
		return
	if reversed or changed_view:
		_clear_captures()
		history.clear()
		captured_packet.clear()
		_suspend_passes()
	view_basis = world.camera.global_basis
	capture_view_key = world.view_key.duplicate(true)
	var changed := not is_equal_approx(last_seconds, world.elapsed)
	last_seconds = world.elapsed
	if not is_instance_valid(owner):
		owner = Node3D.new()
		owner.name = "AssembledActorEchoes"
		world.add_child(owner)
	var actors: Dictionary = {}
	var maximum_delay: float = 0.0
	for specification in specifications:
		actors[specification.actor] = true
		maximum_delay = maxf(maximum_delay, float(specification.get("delay", 0.0)))
	# Record once per actor/time, not per copy. Retain by seconds so extra
	# contours cannot shorten the historical 80/160/240ms pose window.
	for actor in actors:
		if not world.visual_actors.has(actor):
			history.erase(actor)
			continue
		var request_key := _capture_key(world)
		var prior: Array = history.get(actor,[])
		var pose: Dictionary = prior.back() if not prior.is_empty() and prior.back().get("capture_key") == request_key else _snapshot(world, actor)
		if pose.layers.is_empty():
			history.erase(actor)
			continue
		if not history.has(actor):
			history[actor] = []
		# Retire before allocation so prefix restoration cannot temporarily grow
		# the rolling owner through an entire long condition lifetime.
		while history[actor].size() > 2 and history[actor][1].seconds < world.elapsed-maximum_delay:
			var retired: Dictionary = history[actor].pop_front()
			if retired.has("capture"): Capture.close(retired.capture)
		pose.capture_key = request_key
		if not _capture_pose(world, pose):
			# A required capture cannot fall back to mutable layers or grow the
			# pose history after the bounded target owner refused publication.
			_suspend_passes()
			for group: Dictionary in copies.values(): group.output.hide()
			return
		if settings.get("capture_departure",false) and not history[actor].is_empty():
			pass # One logical departure, retained for its real owner lifetime.
		elif changed or history[actor].is_empty():
			history[actor].append(pose)
		else:
			if history[actor][-1].has("capture") and history[actor][-1].capture != pose.get("capture"):
				Capture.close(history[actor][-1].capture)
			history[actor][-1] = pose
		if not live_bodies.has(actor):
			live_bodies[actor] = _pass(world)
		_sync_pass(live_bodies[actor], world)
		live_bodies[actor].viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		_draw_pass(live_bodies[actor], {"layers": [], "draw_binding_key": []} if settings.get("capture_departure",false) else pose, Vector3.ZERO)
	var age: float = world.elapsed-world.release
	for specification in specifications:
		var actor: String = specification.actor
		var key: String = specification.id
		var active: bool = specification.get("enabled",true) and history.has(actor)
		if not active:
			if copies.has(key):
				copies[key].output.hide()
				copies[key].colour.viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
				copies[key].depth.viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
			continue
		var selected: Dictionary = {}
		var desired: float = world.elapsed-float(specification.get("delay", 0.0))
		for pose in history[actor]:
			if pose.seconds <= desired+.00001:
				selected = pose
		# A missing predecessor cannot be substituted by a future/current pose.
		if selected.is_empty():
			if copies.has(key):
				copies[key].output.hide()
			continue
		if not copies.has(key):
			copies[key] = _make_copy(world, actor, key)
		var group: Dictionary = copies[key]
		var current: Dictionary = history[actor].back()
		# Blur trails belong to movement; stationary silhouettes use only their
		# compact authored contours, while the live body remains clearly legible.
		var moving: bool = history[actor].size() > 1 and not history[actor][-2].origin.is_equal_approx(current.origin)
		var moved: bool = moving and not selected.origin.is_equal_approx(current.origin)
		group.output.visible = not specification.get("motion_only", false) or moved
		_apply_output_parameters(group, specification, world.receiver_depth)
		if not group.output.visible:
			group.colour.viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
			group.depth.viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
			continue
		var offset_value: Array = specification.get("offset", [0,0,0])
		var offset := Vector3(offset_value[0],offset_value[1],offset_value[2])
		var oscillation: float = specification.get("oscillation", 0.0)
		offset += world.camera.global_basis.x*sin(age*float(specification.get("frequency", 7.0)))*oscillation
		# Full-screen composition still sorts at the real copy's world origin.
		group.output.global_position = selected.origin+offset
		if float(specification.get("delay",0.0)) > 0.0 and not settings.get("mirror",false):
			# The retained record owns these pixels. Even a still-pending request
			# must not leave the old empty compositor passes updating every frame.
			group.colour.viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
			group.depth.viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
			var record: Dictionary = selected.get("capture",{})
			# No previous-ready flag or later current pixels can satisfy this
			# request. The original delayed sources have zero world offset.
			if record.is_empty() or not record.ready or record.closed or record.view_key != world.view_key or not offset.is_zero_approx():
				group.output.hide()
				continue
			group.colour.viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
			group.depth.viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
			group.output.material_override.set_shader_parameter("echo_colour",record.colour.viewport.get_texture())
			group.output.material_override.set_shader_parameter("echo_depth",record.depth.viewport.get_texture())
			_apply_output_mapping(group,world,selected.layers[0],Vector3.ZERO)
			continue
		for pass_data in [group.colour, group.depth]:
			pass_data.viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			_sync_pass(pass_data, world)
			_draw_pass(pass_data, selected, offset)
		var layer: Dictionary = selected.layers[0]
		_apply_output_mapping(group, world, layer, offset)

const VfxPackageIO_6e2fd93397 = preload("res://assets/vfx/extensions/production-review-20261020/scoped_resource_io.gd")
