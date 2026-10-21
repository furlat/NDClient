extends RefCounted
## Private, once-evaluated actor attachments. No CPU texture readback, shared
## mutable viewport, source clock hold, or second presentation timeline.
const Sources = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
const Clock = preload("res://assets/vfx/sources/c0017ad639184b208deb/occurrence_clock.gd")
static var frozen_programs: Dictionary = {}
static var depth_programs: Dictionary = {}


static func frozen_material(source: ShaderMaterial, clock: Texture2D) -> ShaderMaterial:
	# An uninspected next-pass chain can hide independently mutable clocks or
	# textures. Only the actual single-pass materials qualified here are admitted.
	if source == null or source.shader == null or source.next_pass != null:
		return null
	var result: ShaderMaterial = source.duplicate(false)
	var code := Sources.expand_shader(source.shader.code, source.shader.resource_path.get_base_dir())
	if code.contains("global uniform sampler2D vfx_package_clock;"):
		if clock == null:
			return null
		if not frozen_programs.has(source.shader):
			var shader := Shader.new()
			shader.code = code.replace("global uniform sampler2D vfx_package_clock;", "uniform sampler2D vfx_package_clock;")
			frozen_programs[source.shader] = shader
		Sources.replace_shader(result, frozen_programs[source.shader])
		result.set_shader_parameter("vfx_package_clock", clock)
	return result


static func depth_material(source: ShaderMaterial) -> ShaderMaterial:
	# Run the supplied receiver's complete alpha/discard path. The legacy depth
	# program has older coverage/storage rules and cannot reconstruct these from
	# a copied subset of uniforms. Only the final colour is replaced by numeric
	# reverse-Z depth; the actual source clock and texture bindings stay private.
	if source == null or source.shader == null or source.next_pass != null: return null
	if not depth_programs.has(source.shader):
		var code := Sources.expand_shader(source.shader.code,source.shader.resource_path.get_base_dir())
		for hook in ["vec3 source_world_origin;","bool native_scene_receiver(","vec2 lit_texel_uv(","void fragment()"]:
			if not code.contains(hook): return null
		var start := code.find("void fragment()")
		var opening := code.find("{",start)
		var end := opening+1
		var braces := 1
		while end < code.length() and braces > 0:
			if code[end] == "{": braces += 1
			elif code[end] == "}": braces -= 1
			end += 1
		if braces != 0 or code.substr(opening,end-opening).contains("return;"): return null
		code = code.insert(end-1,"""
    if (ALPHA <= 0.0) discard;
    vec3 history_point = VERTEX;
    vec3 history_measured;
    if (native_scene_receiver(lit_texel_uv(UV,material_cell_size), VERTEX,
            VIEW_MATRIX, INV_VIEW_MATRIX, source_world_origin, history_measured)) history_point = history_measured;
    vec4 history_projected = PROJECTION_MATRIX*vec4(history_point,1.0);
    uint history_packed = uint(round(clamp(history_projected.z/history_projected.w,0.0,1.0)*16777215.0));
    ALBEDO = vec3(float(history_packed>>16u),float((history_packed>>8u)&255u),float(history_packed&255u))/255.0;
    ALPHA = 1.0;
""")
		# Numeric depth must not receive environmental fog after the receiver.
		var modes := code.find("render_mode ")
		var modes_end := code.find(";",modes)
		if modes < 0 or modes_end < 0: return null
		if not code.substr(modes,modes_end-modes).contains("fog_disabled"):
			code = code.insert(modes_end,", fog_disabled")
		var shader := Shader.new()
		shader.code = code
		depth_programs[source.shader] = shader
	var result: ShaderMaterial = source.duplicate(false)
	Sources.replace_shader(result,depth_programs[source.shader])
	return result


static func clock_snapshot(supplied: Variant = null) -> Image:
	# This is the source-owned CPU clock table, not a GPU pixel readback. A
	# restored prefix may explicitly supply its privately realized original table.
	var image: Image = supplied if supplied is Image else Clock.image
	return image.duplicate() if image != null else null


static func dependency(parent: Node, value: Dictionary, clock: Texture2D) -> Dictionary:
	var surface: Dictionary = value.get("surface", {})
	var original: SubViewport = surface.get("viewport")
	var quad: MeshInstance3D = surface.get("quad")
	if original == null or quad == null or surface.get("closed", false) or value.get("texture") != original.get_texture():
		return {"error": "Native history dependency must identify its actual live surface/texture"}
	if not value.has("identity") or not value.has("seconds") or not value.get("clock_parameter", "") is String:
		return {"error": "Native history dependency requires actual identity, absolute seconds and selected clock parameter"}
	if not quad.material_override is ShaderMaterial or surface.get("material") != quad.material_override:
		return {"error": "Native history dependency material does not match its actual quad"}
	for child in original.get_children():
		if not child is Camera3D and not child is WorldEnvironment and child != quad:
			return {"error": "Unsupported native material surface topology"}
		if child.get_script() != null:
			return {"error": "A scripted native surface requires its own frozen realization"}
	var material := frozen_material(quad.material_override, clock)
	if material == null:
		return {"error": "Native history material requires a single inspected shader pass and its source body-clock snapshot"}
	var parameter := str(value.clock_parameter)
	if not parameter.is_empty():
		if not material.shader.get_shader_uniform_list().any(func(row: Dictionary) -> bool: return str(row.name) == parameter):
			return {"error": "Selected native hit clock is absent from actual material"}
		material.set_shader_parameter(parameter, float(value.seconds))
	var viewport := SubViewport.new()
	viewport.size = original.size
	viewport.own_world_3d = true
	viewport.transparent_bg = original.transparent_bg
	viewport.use_hdr_2d = original.use_hdr_2d
	viewport.msaa_3d = original.msaa_3d
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	parent.add_child(viewport)
	for child in original.get_children():
		var copy: Node = child.duplicate(0)
		if child == quad:
			copy.material_override = material
		viewport.add_child(copy)
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	return {"viewport": viewport, "texture": viewport.get_texture(), "identity": value.identity,
		"seconds": float(value.seconds), "clock_parameter": parameter, "source_texture": value.texture}


static func request(history: RefCounted, world: Node, pose: Dictionary, identity: Dictionary, dependencies: Array, supplied_clock: Variant = null) -> Dictionary:
	var record := {"requested_identity": identity.duplicate(true), "drawn_identity": {}, "attempt":0, "suspended":false,
		"ready": false, "closed": false, "error": "", "dependencies": [],
		"pose": pose.duplicate(false), "view_key": world.view_key.duplicate(true), "size": world.capture_size}
	var retained := Node3D.new()
	retained.name = "ImmutableActorCapture"
	history.owner.add_child(retained)
	record.owner = retained
	record.history_owner = weakref(history)
	# Keep the original CPU table as well as its GPU realization. A held pose may
	# need a new camera realization long after the live body's slot was reused.
	# This is authored source state, never a readback of evaluated pixels.
	record.clock_image = clock_snapshot(supplied_clock)
	var clock: Texture2D = ImageTexture.create_from_image(record.clock_image) if record.clock_image != null else null
	var replacements := {}
	for value: Dictionary in dependencies:
		var held := dependency(retained, value, clock)
		if held.has("error"):
			record.error = held.error
			close(record)
			return record
		record.dependencies.append(held)
		replacements[value.texture] = held.texture
	var layers := []
	for original: Dictionary in pose.layers:
		var layer := original.duplicate(false)
		layer.material = frozen_material(original.material, clock)
		if layer.material == null:
			record.error = "Actor history requires a single inspected shader pass and its source-owned clock snapshot"
			break
		for uniform: Dictionary in layer.material.shader.get_shader_uniform_list():
			var value: Variant = layer.material.get_shader_parameter(uniform.name)
			if value is ViewportTexture:
				if str(uniform.name) == "native_body_surface" and not bool(layer.material.get_shader_parameter("native_body_enabled")):
					# The actual native-body program returns before sampling this
					# binding when disabled. Do not retain a retired, unused surface.
					layer.material.set_shader_parameter(uniform.name,null)
					continue
				if not replacements.has(value):
					record.error = "Mutable viewport dependency lacks an immutable native-surface descriptor: " + str(uniform.name)
					break
				layer.material.set_shader_parameter(uniform.name, replacements[value])
		if not record.error.is_empty(): break
		layer.capture_depth = depth_material(layer.material)
		if layer.capture_depth == null:
			record.error = "Actual actor receiver lacks the supported source-preserving numeric-depth hooks"
			break
		layers.append(layer)
	if not record.error.is_empty():
		close(record)
		return record
	record.pose.layers = layers
	record.pose.erase("draw_binding_key")
	for channel in ["colour", "depth"]:
		var pass_data: Dictionary = history._pass(world, channel == "depth")
		pass_data.viewport.reparent(retained)
		history._sync_pass(pass_data, world)
		history._draw_pass(pass_data, record.pose, Vector3.ZERO)
		pass_data.viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		record[channel] = pass_data
	_arm(record)
	return record


static func _arm(record: Dictionary) -> void:
	record.attempt += 1
	var attempt: int = record.attempt
	# Arm at a real pre-draw, so a request made during a previous post-draw
	# cannot falsely complete in that same signal emission. Withdrawal cancels
	# this attempt without discarding an already completed immutable capture.
	RenderingServer.frame_pre_draw.connect(func():
		if record.closed or record.suspended or record.attempt != attempt: return
		RenderingServer.frame_post_draw.connect(func():
			if record.closed or record.suspended or record.attempt != attempt or not is_instance_valid(record.owner): return
			_complete(record),CONNECT_ONE_SHOT),CONNECT_ONE_SHOT)


static func _complete(record: Dictionary) -> void:
	for channel in ["colour", "depth"]:
		record[channel].viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	for held: Dictionary in record.dependencies:
		held.viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	record.drawn_identity = record.requested_identity.duplicate(true)
	record.drawn_frame = Engine.get_frames_drawn()
	record.ready = true


static func suspend(record: Dictionary) -> void:
	if record.get("closed",false) or record.get("ready",false) or record.get("suspended",false): return
	record.suspended = true
	record.attempt += 1
	for channel in ["colour","depth"]:
		record[channel].viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	for held: Dictionary in record.dependencies:
		held.viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED


static func resume(record: Dictionary) -> void:
	if record.get("closed",false) or not record.get("suspended",false): return
	record.suspended = false
	for channel in ["colour","depth"]:
		record[channel].viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	for held: Dictionary in record.dependencies:
		held.viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_arm(record)


static func close(record: Dictionary) -> void:
	if record.get("closed", false): return
	record.closed = true
	record.ready = false
	record.attempt = int(record.get("attempt",0))+1
	# These source materials are private to this capture. The older compositor
	# cache is useful for reusable poses, but must not retain one depth material
	# and its native viewport dependency for every frame of a long condition.
	var history: RefCounted = record.history_owner.get_ref() if record.has("history_owner") else null
	if history != null:
		for layer: Dictionary in record.get("pose",{}).get("layers",[]):
			history.material_cache.erase([layer.material.get_instance_id(),history.DepthShader.get_instance_id()])
			if layer.has("depth_echo"): history.depth_parameter_cache.erase(layer.depth_echo)
	if is_instance_valid(record.get("owner")):
		# Retirement can process many genuine prefix observations in one main-
		# thread turn. Queueing their Nodes would retain O(prefix) targets until
		# the next delete drain. No callback runs on these private Nodes; closed
		# and attempt checks invalidate completion before immediate retirement.
		record.owner.free()


static func status(record: Dictionary) -> Dictionary:
	return {"ready": record.get("ready", false) and not record.get("closed", false),
		"error": record.get("error", ""), "requested_identity": record.get("requested_identity", {}),
		"drawn_identity": record.get("drawn_identity", {}), "drawn_frame": record.get("drawn_frame", -1),
		"size": record.get("size", Vector2i.ZERO), "closed": record.get("closed", false)}
