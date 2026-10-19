extends RefCounted
## Live owner-held copies of real modular poses; immutable pose/material caches.
## Adaptive exception: bounded cached actor draw transforms, GPU composition.
## Offline copies of real modular poses. Compose each complete outfit before
## echo opacity, retaining source colour, slot order, equipment and geometry.
## No replacement character atlas, extra animation clock, receiver or game actor.
const SourceMaterials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
var SourceShader: Shader
var DepthShader: Shader

const EXCLUDED_SLOTS := ["shadow", "weaponGlow", "aura", "effect", "effect2", "effect3", "slash"]
## A prepared holder contains no body mesh/material references. Keep immutable
## compositor resources warm explicitly, rather than reloading/parsing them at
## every occurrence after the previous owner's last reference was released.
static var shared_resources: Dictionary = {}
var history: Dictionary = {}
var copies: Dictionary = {}
var live_bodies: Dictionary = {}
var last_seconds: float = -1.0
var view_basis := Basis.IDENTITY
var owner: Node3D
var parameter_names: Dictionary = {}
var material_cache: Dictionary = {}
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
		shared_resources[path] = load(path)
	return shared_resources[path]

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
		close()
		captured_packet.clear()
		# A camera/material recapture changes optical layers, not admission
		# position. An explicit origin still allows the provider to rebase it.
		if not logical_changed and held_origin is Vector3 and not value.has("departure_origin"):
			value = value.duplicate(false)
			value.departure_origin = held_origin
		departure_revision = value.get("departure_revision", departure_revision)
		departure_capture_revision = value.get("departure_capture_revision", departure_capture_revision)
	packet = value
	return true

func set_history_state(value: Dictionary) -> void:
	var count := clampi(int(value.get("duplicate_count",value.get("duplicates",3))),0,3)
	for index in context.staging_spec.review_actor_echoes.size():
		context.staging_spec.review_actor_echoes[index]["enabled"] = not settings.get("mirror",false) or index < count

func _suspend_passes() -> void:
	for group in copies.values():
		group.colour.viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		group.depth.viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	for pass_data in live_bodies.values():
		pass_data.viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

func sample(seconds: float) -> void:
	if not admitted: return
	context.camera = packet.camera
	context.receiver_depth = packet.receiver_depth
	context.capture_size = packet.get("capture_size", Vector2i(960,640))
	context.elapsed = seconds
	context.actor_origin = packet.get("departure_origin",packet.origin) if settings.get("capture_departure",false) else packet.origin
	context.pose_key = [packet.pose_key, packet.get("material_revision",0), departure_capture_revision]
	context.actor_layers = packet.get("departure_layers",packet.get("layers",[])) if settings.get("capture_departure",false) else packet.layers
	context.visual_actors = {"recipient": true}
	if settings.get("capture_departure",false):
		if captured_packet.is_empty():
			captured_packet = _snapshot(context,"recipient")
		context.actor_layers = []
	_sample(context)
	if is_instance_valid(owner): owner.show()


func close() -> void:
	if is_instance_valid(owner):
		owner.free()
	owner = null
	copies.clear()
	live_bodies.clear()
	history.clear()
	parameter_names.clear()
	material_cache.clear()
	pose_material_cache.clear()
	last_seconds = -1.0

func _echo_material(source: ShaderMaterial, shader: Shader) -> ShaderMaterial:
	var key := [source.get_instance_id(), shader.get_instance_id()]
	if material_cache.has(key): return material_cache[key]
	var source_shader: Shader = source.shader
	if not parameter_names.has(source_shader):
		var names: Array[String] = []
		var declarations := RegEx.new()
		declarations.compile("uniform\\s+(?:(?:lowp|mediump|highp)\\s+)?\\w+\\s+(\\w+)")
		for found in declarations.search_all(SourceMaterials.expand_shader(source_shader.code,source_shader.resource_path.get_base_dir())):
			names.append(found.get_string(1))
		parameter_names[source_shader] = names
	var material := ShaderMaterial.new()
	material.shader = shader
	for name in parameter_names[source_shader]:
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
	pass_data.viewport.size = world.capture_size
	pass_data.camera.global_transform = world.camera.global_transform
	for property in ["projection", "keep_aspect", "size", "near", "far", "fov", "frustum_offset", "h_offset", "v_offset"]:
		pass_data.camera.set(property, world.camera.get(property))

func _snapshot(world: Node, _actor: String) -> Dictionary:
	if settings.get("capture_departure",false) and not captured_packet.is_empty():
		var held := captured_packet.duplicate(false)
		held.seconds = world.elapsed
		return held
	var signature: Array = world.pose_key.duplicate() if world.pose_key is Array else [world.pose_key]
	var cached: Dictionary = pose_material_cache.get(signature,{})
	var layers: Array = []
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
	pose_material_cache[signature] = cached
	# History is <.25 seconds. Retain a bounded cache, never one allocation per
	# frame over the whole condition lifetime or mesh duplication at all.
	if pose_material_cache.size() > 64:
		pose_material_cache.erase(pose_material_cache.keys()[0])
		material_cache.clear()
	return {"seconds":world.elapsed,"layers":layers,"origin":world.actor_origin}

func _draw_pass(pass_data: Dictionary, pose: Dictionary, offset: Vector3) -> void:
	var layers: Array = pose.layers
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
		var material_key: String = "depth_echo" if pass_data.depth else "source_echo"
		if not layer.has(material_key):
			layer[material_key] = _echo_material(layer.material, DepthShader if pass_data.depth else SourceShader)
		var material: ShaderMaterial = layer[material_key]
		# Production has already assigned each slot's painter priority. Keep that
		# order inside the copy, independently of measured optical component depth.
		material.render_priority = layer.material.render_priority
		if pass_data.depth:
			material.set_shader_parameter("native_scene_pivot", layer.pivot)
			material.set_shader_parameter("native_scene_ground_height", float(layer.ground_pixels)*float(layer.material.get_shader_parameter("component_units")))
		elif layer.has("received"):
			var received: ShaderMaterial = layer.received
			material.set_shader_parameter("echo_receiving_enabled", received.shader.resource_path.ends_with("canvas_capped_modular.gdshader"))
			material.set_shader_parameter("echo_received", received.get_shader_parameter("received"))
			material.set_shader_parameter("echo_receiving_region", received.get_shader_parameter("atlas_region"))
			material.set_shader_parameter("echo_receiving_crop", received.get_shader_parameter("source_crop"))
			material.set_shader_parameter("echo_light_cap", received.get_shader_parameter("light_cap"))
		draw.mesh = layer.mesh
		draw.material_override = material
		draw.sorting_offset = layer.sorting_offset
		draw.global_transform = layer.transform
		draw.global_position += offset

func _make_copy(world: Node, actor: String, key: String) -> Dictionary:
	var result := {"colour": _pass(world), "depth": _pass(world, true)}
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

func _sample(world: Node) -> void:
	var specifications: Array = world.staging_spec.get("review_actor_echoes", [])
	if specifications.is_empty():
		if is_instance_valid(owner):
			close()
		return
	# Facing sheets depend on the actual review camera. Never trail a stale view.
	if world.elapsed < last_seconds-.00001 or not world.camera.global_basis.is_equal_approx(view_basis):
		close()
	view_basis = world.camera.global_basis
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
		var pose := _snapshot(world, actor)
		if pose.layers.is_empty():
			history.erase(actor)
			continue
		if not history.has(actor):
			history[actor] = []
		if changed or history[actor].is_empty():
			history[actor].append(pose)
		else:
			history[actor][-1] = pose
		while history[actor].size() > 2 and history[actor][1].seconds < world.elapsed-maximum_delay:
			history[actor].pop_front()
		if not live_bodies.has(actor):
			live_bodies[actor] = _pass(world)
		_sync_pass(live_bodies[actor], world)
		live_bodies[actor].viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		_draw_pass(live_bodies[actor], {"layers": []} if settings.get("capture_departure",false) else pose, Vector3.ZERO)
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
		group.output.material_override.set_shader_parameter("receiver_depth", world.receiver_depth)
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
		var envelope := 1.0
		for pass_data in [group.colour, group.depth]:
			pass_data.viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			_sync_pass(pass_data, world)
			_draw_pass(pass_data, selected, offset)
		var material: ShaderMaterial = group.output.material_override
		material.set_shader_parameter("echo_opacity", float(specification.opacity)*envelope)
		material.set_shader_parameter("protect_live_body", specification.get("protect_live_body", true))
		# Output wave and lifecycle opacity read the shared owner GPU clock.
		material.set_shader_parameter("echo_slot_phase", float(specification.get("slot_phase", 0.0)))
		material.set_shader_parameter("echo_wave_strength", float(specification.get("wave_strength", 0.0)))
		var spectral_palette: Array = specification.get("spectral_palette", [])
		var spectral_colours := PackedVector3Array()
		for rgb in spectral_palette:
			spectral_colours.append(Vector3((int(rgb)>>16)&255,(int(rgb)>>8)&255,int(rgb)&255)/255.0)
		if spectral_colours.size() == 4:
			material.set_shader_parameter("echo_spectral_palette", spectral_colours)
		material.set_shader_parameter("echo_spectral_maximum", float(specification.get("spectral_maximum", 170.0))/255.0)
		material.set_shader_parameter("echo_spectral_strength", float(specification.get("spectral_strength", 0.0)) if spectral_palette.size() == 4 else 0.0)
		var tint: Array = specification.get("tint", [1.0,1.0,1.0])
		material.set_shader_parameter("echo_tint", Vector3(tint[0],tint[1],tint[2]))
		var layer: Dictionary = selected.layers[0]
		var mesh_size: Vector2 = layer.mesh.size
		var top_left: Vector3 = layer.transform*(Vector3(-mesh_size.x*.5,mesh_size.y*.5,0.0)+layer.mesh.center_offset)+offset
		var screen_size := Vector2(world.capture_size)
		var screen_origin: Vector2 = world.camera.unproject_position(top_left)/screen_size
		var axis_x: Vector2 = world.camera.unproject_position(top_left+layer.transform.basis.x*mesh_size.x)/screen_size-screen_origin
		var axis_y: Vector2 = world.camera.unproject_position(top_left-layer.transform.basis.y*mesh_size.y)/screen_size-screen_origin
		material.set_shader_parameter("echo_source_cell_size", layer.material.get_shader_parameter("material_cell_size"))
		material.set_shader_parameter("echo_screen_origin", screen_origin)
		material.set_shader_parameter("echo_screen_axis_x", axis_x)
		material.set_shader_parameter("echo_screen_axis_y", axis_y)
