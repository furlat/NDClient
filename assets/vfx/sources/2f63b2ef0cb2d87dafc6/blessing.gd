extends "res://assets/vfx/sources/e212c77ca5bf64639ea0/base.gd"


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/2f63b2ef0cb2d87dafc6/blessing.gd", input)


func apply_scene_edits(node: Node) -> void:
	node.scale *= float(settings.scale)
	node.position.y += float(settings.height)
	if settings.name == "vfx_status_divine":
		var envelope = node.get_node("Mesh")
		var cylinder = CylinderMesh.new()
		cylinder.top_radius = 0.8
		cylinder.bottom_radius = 0.8
		cylinder.height = 2.5
		cylinder.radial_segments = 48
		cylinder.rings = 12
		cylinder.cap_top = false
		cylinder.cap_bottom = false
		envelope.mesh = cylinder
		envelope.material_override = envelope.material_override.duplicate(true)
		envelope.material_override.set_shader_parameter("proximity_fade", false)
		envelope.material_override.set_shader_parameter("noise_scale", Vector2(1.5, 0.3))
		envelope.material_override.set_shader_parameter("noise_twist", 0.12)
		envelope.material_override.set_shader_parameter("noise_scroll", Vector2(0.04, -0.15))
		envelope.material_override.set_shader_parameter("waviness", 0.05)
		node.get_node("Aura").layers = 0
		var mark = MeshInstance3D.new()
		mark.name = "BrokenGroundBlessing"
		var surface = SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for segment in range(3):
			for step in range(12):
				var a = deg_to_rad(float(segment * 120 + step * 5))
				var b = deg_to_rad(float(segment * 120 + (step + 1) * 5))
				var y = -float(settings.height) / float(settings.scale) + 0.02
				var p0 = Vector3(cos(a) * 0.78, y, sin(a) * 0.78)
				var p1 = Vector3(cos(b) * 0.78, y, sin(b) * 0.78)
				var p2 = Vector3(cos(a) * 0.85, y, sin(a) * 0.85)
				var p3 = Vector3(cos(b) * 0.85, y, sin(b) * 0.85)
				for point in [p0, p1, p2, p2, p1, p3]:
					surface.add_vertex(point)
		mark.mesh = surface.commit()
		var seal = ShaderMaterial.new()
		var seal_shader = Shader.new()
		seal_shader.code = "shader_type spatial; render_mode unshaded,cull_disabled; void fragment(){ALBEDO=vec3(0.76,0.56,0.24);ALPHA=0.6;}"
		seal.shader = seal_shader
		mark.material_override = seal
		node.add_child(mark)
	if settings.name == "vfx_status_green" and settings.get("mode", "") == "sustain":
		var envelope = node.get_node("Mesh")
		envelope.mesh = envelope.mesh.duplicate()
		envelope.mesh.height = 1.6
		envelope.mesh.radius = 0.65
		envelope.position.y = -0.45
	# Keep the authored 3D particle/shader motion; cap density for body readability.
	node.set_script(null)
	for particles in node.find_children("*", "GPUParticles3D", true, false):
		if settings.get("mode", "") == "sustain" or settings.name == "vfx_status_void":
			particles.layers = 0
		particles.fixed_fps = 144
		particles.process_material = particles.process_material.duplicate(true)
		if settings.name == "vfx_status_divine":
			particles.process_material.gravity = Vector3(0, -0.6, 0)
		if settings.name == "vfx_status_green":
			particles.process_material.radial_accel_min = -0.4
			particles.process_material.radial_accel_max = -0.4
		particles.amount = 7 if settings.name == "vfx_status_void" else 20
		if settings.name == "vfx_status_divine":
			particles.amount = 8 if particles.name == "Aura" else 14
			particles.process_material.scale_min *= 0.7
			particles.process_material.scale_max *= 0.65
			particles.process_material.emission_shape_scale = Vector3(0.85, 0.35, 0.85)
			particles.process_material.gravity = Vector3(0, -1.0, 0)


func adapt_shader(mat: ShaderMaterial) -> void:
	if settings.name == "vfx_status_green":
		mat.set_shader_parameter("proximity_fade", false)
	if settings.name == "vfx_status_void" and "streaks1_count" in mat.shader.code:
		mat.set_shader_parameter("proximity_fade", false)
		mat.set_shader_parameter("streaks1_count", 7.0)
		mat.set_shader_parameter("streaks2_count", 9.0)
		mat.set_shader_parameter("center_radius", 0.12)
		mat.set_shader_parameter("fade_radius", 0.38)
		mat.set_shader_parameter("streaks_thickness", 0.025)
	var shader = Shader.new()
	var code: String = expand_includes(mat.shader.code, mat.shader.resource_path.get_base_dir())
	if settings.name == "vfx_status_void" and "float r = length(UV" in code:
		code = code.replace("render_mode unshaded;", "render_mode unshaded,cull_disabled;")
		code = code.replace(
			"float r = length(UV * 2.0 - 1.0);", "float r = abs(UV.x*2.0-1.0)*0.35;"
		)
	# Source-relative includes must resolve from the copied shader resource.
	if settings.name in ["vfx_status_divine", "vfx_status_green"] and "float sample_value" in code:
		code = code.replace(
			"pow((1.0 - abs(uv.y * 2.0 - 1.0) - 0.5) / 0.5, 0.2)",
			"smoothstep(0.0,0.18,uv.y)*(1.0-smoothstep(0.82,1.0,uv.y))"
		)
		code = code.replace("blend_add", "blend_mix")
	if settings.name == "vfx_status_void" and "uniform float streaks1_count" in code:
		code = code.replace(
			"float radius = length(centered_uv) * 2.0;",
			"float radius = length(centered_uv) * 2.0 / mix(1.25,0.42,smoothstep(0.12,0.85,TIME));"
		)
	code = code.replace("TIME", "support_clock")
	code = (
		code
		. replace(
			"shader_type spatial;",
			"shader_type spatial;\nuniform float support_clock=0.0;\nuniform float support_envelope=1.0;"
		)
	)
	var split = "<" if side == "front" else ">="
	var prefix = (
		"\nvec3 support_world=(INV_VIEW_MATRIX*vec4(VERTEX,1.0)).xyz;\nif(dot(support_world,vec3(0.70710678,0.0,0.70710678)) "
		+ split
		+ " 0.0) discard;\n"
	)
	if "curse_brand_marker" in code:
		prefix = (
			"\nif(dot(MODEL_MATRIX[3].xyz,vec3(0.70710678,0.0,0.70710678)) "
			+ split
			+ " 0.0) discard;\n"
		)
	if "curse_ground_marker" in code:
		prefix = "\ndiscard;\n" if side == "front" else "\n"
	prefix = prefix.replace(
		"vec3(0.70710678,0.0,0.70710678)", "vec3(%s,%s,%s)" % parameters.clip_normal
	)
	var regex = RegEx.new()
	regex.compile("void\\s+fragment\\s*\\(\\s*\\)\\s*\\{")
	var match0 = regex.search(code)
	if match0:
		var pos = match0.get_end()
		if side == "full": prefix = ""
		code = code.insert(pos, prefix)
		var depth = 1
		var end = pos + prefix.length()
		while end < code.length() and depth > 0:
			if code[end] == "{":
				depth += 1
			elif code[end] == "}":
				depth -= 1
			end += 1
		var opacity = "support_envelope"
		if settings.name == "vfx_status_void" and not "curse_brand_marker" in code:
			opacity = "support_envelope * 0.6"
		if "curse_ground_marker" in code:
			opacity = "1.0"
		if "curse_brand_marker" in code:
			opacity = "min(1.0,support_envelope*1.5)"
		code = code.insert(end - 1, "\nALPHA *= " + opacity + ";\n")
	shader.code = code
	mat.shader = shader
	materials.append(mat)


func advance_lifecycle(_delta: float) -> void:
	if not is_instance_valid(subject):
		return
	tick += 1
	var age = float(tick) / 144.0
	var fade = float(settings.get("alphaGain", 1.0))
	fade *= smoothstep(0.0, 0.18, age)
	fade *= lerpf(1.0, 0.25, smoothstep(0.85, 1.65, age))
	if int(settings.close) > 0 and tick > int(settings.close):
		fade *= (
			1.0
			- smoothstep(float(settings.close) / 144.0, float(settings.frames - 12) / 144.0, age)
		)
	var shader_age = age
	if settings.get("mode", "") == "sustain":
		shader_age = 0.5 + 0.3 * sin(TAU * float((tick - 1) % 288) / 288.0)
		fade = float(settings.get("alphaGain", 1.0)) * 0.35
	for mat in materials:
		mat.set_shader_parameter("curse_age", age)
		mat.set_shader_parameter("support_clock", shader_age)
		mat.set_shader_parameter("support_envelope", fade)
	if tick == int(settings.close):
		for particles in subject.find_children("*", "GPUParticles3D", true, false):
			particles.emitting = false
		for player in subject.find_children("*", "AnimationPlayer", true, false):
			for ending in ["close", "End"]:
				if player.has_animation(ending):
					player.play(ending)
					break
