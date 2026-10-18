extends "res://assets/vfx/sources/a4fd0883f0b17d893a03/base.gd"
## Native source authoring; shared stage, process clock, palette and capture.
const SourceMaterials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/fc6f8b4f3c0cf8ba0291/rebuke.gd", input)


func prepare_materials(_node: Node) -> void:
	pass


func tint(c: Color) -> Color:
	if c.s < 0.08:
		return c
	return Color.from_hsv(float(settings.hue), c.s * 0.85, c.v, c.a)


func recolor(r: Resource) -> void:
	if r == null or visited.has(r.get_instance_id()):
		return
	visited[r.get_instance_id()] = true
	for p in r.get_property_list():
		if not (int(p.usage) & PROPERTY_USAGE_STORAGE):
			continue
		var v = r.get(p.name)
		if v is Color:
			r.set(p.name, tint(v))
		elif v is PackedColorArray:
			var colors = PackedColorArray()
			for c in v:
				colors.append(tint(c))
			r.set(p.name, colors)
		elif v is Resource:
			recolor(v)
	if r is Mesh:
		for i in r.get_surface_count():
			recolor(r.surface_get_material(i))
	if r is ShaderMaterial:
		adapt_shader(r)


func apply_scene_edits(node: Node) -> void:
	subject = node
	if settings.name == "VFX_FireStatic_K1":
		var flame = node.get_node("FireTorch_AC")
		flame.position = Vector3(-0.37, 0.0, -0.1)
		flame.scale = Vector3(0.2, 0.52, 0.20)
		flame.material_override = flame.material_override.duplicate(true)
		var fm = flame.material_override
		fm.set_shader_parameter("speed", 2.4)
		fm.set_shader_parameter("wobble_strength", 0.85)
		fm.set_shader_parameter("Color_Intensity2", 1.8)
		fm.set_shader_parameter("Scale_XY2", Vector2(2.0, 2.8))
		fm.set_shader_parameter("Speed_XY2", Vector2(0.18, 2.0))
		var sh = Shader.new()
		sh.code = fm.shader.code
		sh.code = (
			sh
			. code
			. replace(
				"float n_out44p0 = texture(Base_noise2, n_out38p0).r + texture(Texture_add, UV).r;",
				"float n_out44p0 = texture(Base_noise2, n_out38p0).r * 1.6 + texture(Texture_add, UV).r * 0.48;"
			)
		)
		sh.code = (
			sh
			. code
			. replace(
				"VERTEX.y += (noise.g - 0.5) * height_effect * 0.5;",
				"VERTEX.y += (noise.g - 0.5) * height_effect * 0.5; VERTEX.x += sin(VERTEX.y*1.4 + TIME*7.0)*pow(max(VERTEX.y,0.0)/4.0,1.6)*0.9;"
			)
		)
		sh.code = sh.code.replace(
			"ALPHA = n_out61p0;", "ALPHA = n_out61p0 * smoothstep(0.08,0.28,n_out57p0);"
		)
		sh.code = sh.code.replace(
			"uniform float speed",
			"varying vec3 hellish_local;\nuniform float break_strip=0.0;\nuniform float speed"
		)
		sh.code = sh.code.replace("void vertex() {", "void vertex() { hellish_local=VERTEX;")
		sh.code = (
			sh
			. code
			. replace(
				"ALPHA = n_out61p0 * smoothstep(0.08,0.28,n_out57p0);",
				"float lower_cut=0.95 + 0.35*sin(atan(hellish_local.z,hellish_local.x)*2.0 + 0.7); float root_open=smoothstep(lower_cut,lower_cut+0.34,hellish_local.y); float crown=1.0-smoothstep(2.85,3.5,hellish_local.y); ALPHA = n_out61p0 * smoothstep(0.08,0.28,n_out57p0) * root_open * crown * (1.0-break_strip*(1.0-smoothstep(0.08,0.30,abs(hellish_local.y-(2.05+0.16*sin(hellish_local.x*7.0+TIME*5.0))))));"
			)
		)
		fm.shader = sh
		var second = flame.duplicate()
		node.add_child(second)
		second.material_override = fm.duplicate(true)
		second.material_override.set_shader_parameter("break_strip", 1.0)
		second.position = Vector3(0.4, 0.05, 0.05)
		second.scale = Vector3(0.17, 0.40, 0.16)
		second.rotation.y = 2.0
		var third = flame.duplicate()
		node.add_child(third)
		third.position = Vector3(0.05, 0.10, -0.30)
		third.scale = Vector3(0.12, 0.58, 0.13)
		third.rotation.y = -1.0
	if settings.name == "VFX_Smoke_z_puff":
		node.amount = 7
		node.one_shot = true
		node.explosiveness = 0.8
		node.lifetime = 0.65
		node.process_material = node.process_material.duplicate(true)
		node.process_material.radial_velocity_min = 0.5
		node.process_material.radial_velocity_max = 1.2

	if settings.name == "VFX_Hit_dark":
		node.get_node("torus").visible = false
		node.get_node("stars").visible = false
		var corruption = node.get_node("Pruple Expansion")
		corruption.lifetime = 0.45
		corruption.process_material = corruption.process_material.duplicate(true)
		var curve = Curve.new()
		curve.add_point(Vector2(0, 0.9))
		curve.add_point(Vector2(0.3, 1.0))
		curve.add_point(Vector2(1, 0.05))
		var tex = CurveTexture.new()
		tex.curve = curve
		corruption.process_material.scale_curve = tex
		corruption.process_material.scale_min = 2.5
		corruption.process_material.scale_max = 3.0
		var mat = corruption.material_override.duplicate(true)
		var sh = Shader.new()
		sh.code = mat.shader.code.replace("blend_add", "blend_mix")
		mat.shader = sh
		corruption.material_override = mat
	if settings.name == "VFX_WindShock_A1":
		node.get_node("SmCharacterBase17").visible = false
	node.scale *= float(settings.scale)
	node.position.y += float(settings.height)
	if settings.name == "VFX_HealPuff_A":
		node.get_node("objectflare").layers = 0
		node.get_node("lines").layers = 0
		var puff = node.get_node("smoke2init2")
		for player in node.find_children("*", "AnimationPlayer", true, false):
			if player.has_animation("Init"):
				var anim = player.get_animation("Init")
				for track in anim.get_track_count():
					if String(anim.track_get_path(track)) == "smoke2init2:emitting":
						for key in anim.track_get_key_count(track):
							anim.track_set_key_time(track, key, 0.25)
		puff.amount = 5
		puff.lifetime = 0.85
		puff.process_material = puff.process_material.duplicate(true)
		puff.process_material.radial_velocity_min = 0.4
		puff.process_material.radial_velocity_max = 0.9
		puff.process_material.emission_shape_scale = Vector3(0.9, 0.35, 0.9)
		puff.process_material.scale_min *= 0.65
		puff.process_material.scale_max *= 0.65
		puff.process_material.initial_velocity_min *= 0.5
		puff.process_material.initial_velocity_max *= 0.5
	if settings.name == "VFX_Healing_W1":
		node.get_node("white_Line_horizontal").layers = 0
		var pulse = node.get_node("verticalflash")
		pulse.scale = Vector3(0.9, 0.5, 0.9)
		pulse.lifetime = 0.65
		pulse.process_material = pulse.process_material.duplicate(true)
		pulse.process_material.scale_min *= 0.85
		pulse.process_material.scale_max *= 0.85
	if settings.name == "VFX_Protection_4_Shield":
		node.get_node("muzzle2").scale *= 0.35
		node.get_node("muzzle2").position.y += 0.7
		node.get_node("floorflash4").layers = 0
		node.get_node("verticalflash3").layers = 0
		node.get_node("shield_effect").position.y += 1.0
		node.get_node("shield_effect").scale *= Vector3(0.85, 0.85, 0.85)
		node.get_node("external_base_ring").scale *= Vector3(0.6, 0.6, 0.6)
		node.get_node("verticalflash2").scale.y = 0.08
		node.get_node("verticalflash2").position.y = 1.5
		node.get_node("verticalflash2").lifetime = 0.45
		node.get_node("smallparticles4").amount = 24
	if settings.name == "magic_orb_small_vfx_03":
		node.get_node("Flare").layers = 0
		var glow = node.get_node("Glow").material_override
		var gradient = Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.65, 1.0])
		gradient.colors = PackedColorArray([Color.WHITE, Color(0.6, 0.6, 0.6, 1), Color.BLACK])
		var texture = GradientTexture1D.new()
		texture.gradient = gradient
		glow.set_shader_parameter("fresnel_gradient", texture)
		glow.set_shader_parameter("fresnel_exponent", 1.3)
		glow.set_shader_parameter("proximity_fade", false)
	if settings.name == "VFX_Healing_R1":
		var flecks = node.get_node("smallparticles4")
		flecks.amount = 24
		flecks.lifetime = 0.85
		flecks.process_material = flecks.process_material.duplicate(true)
		flecks.process_material.directional_velocity_max = 2.0
		flecks.process_material.radial_velocity_max = 0.8
		var wisp = node.get_node("verticalflash2")
		wisp.amount = 1
		wisp.one_shot = true
		wisp.explosiveness = 1.0
		wisp.lifetime = 1.15
		wisp.position.x = -0.48
		wisp.position.y = 1.15
		wisp.scale = Vector3(1.6, 0.75, 1.0)
		wisp.process_material = wisp.process_material.duplicate(true)
		wisp.process_material.emission_sphere_radius = 0.08
		wisp.process_material.gravity = Vector3(0, 0.1, 0)
		var other = wisp.duplicate()
		other.name = "SecondWisp"
		other.position.x = 0.48
		other.position.y = 0.9
		other.scale = Vector3(1.25, 0.85, 1.0)
		other.emitting = true
		node.add_child(other)
	if settings.name == "VFX_Dark_sword":
		node.get_node("PurpleSword").layers = 0
	if settings.name == "vfx_status_magic":
		pass
		for particles in node.find_children("*", "GPUParticles3D", true, false):
			particles.amount = 3
			particles.lifetime = 0.7
			particles.process_material = particles.process_material.duplicate(true)
			particles.process_material.emission_shape_scale = Vector3(1, 0.5, 1)
			particles.process_material.emission_sphere_radius = 0.8
			particles.process_material.orbit_velocity_curve = null
			particles.process_material.radial_velocity_min = -1.0
			particles.process_material.radial_velocity_max = -1.0
			particles.process_material.scale_min = 0.2
			particles.process_material.scale_max = 0.4
	for child in [node] + node.find_children("*", "", true, false):
		if child is GeometryInstance3D:
			if "distort" in String(child.name).to_lower():
				child.layers = 0
			if (
				child.material_override is ShaderMaterial
				and "hint_screen_texture" in child.material_override.shader.code
			):
				child.layers = 0
		for p in child.get_property_list():
			if int(p.usage) & PROPERTY_USAGE_STORAGE:
				var v = child.get(p.name)
				if v is Resource:
					recolor(v)
		if child is GeometryInstance3D and side == "back":
			var has_shader = child.material_override is ShaderMaterial
			if child is GPUParticles3D:
				for i in child.draw_passes:
					var mesh = child.get_draw_pass_mesh(i)
					if mesh:
						for j in mesh.get_surface_count():
							if mesh.surface_get_material(j) is ShaderMaterial:
								has_shader = true
			if not has_shader:
				child.layers = 0


func adapt_shader(mat: ShaderMaterial) -> void:
	var shader = Shader.new()
	var code: String = SourceMaterials.expand_shader(
		mat.shader.code, mat.shader.resource_path.get_base_dir()
	)
	# Source-relative includes must resolve from the copied shader resource.
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
	var regex = RegEx.new()
	regex.compile("void\\s+fragment\\s*\\(\\s*\\)\\s*\\{")
	var match0 = regex.search(code)
	if match0:
		var pos = match0.get_end()
		code = code.insert(pos, prefix)
		var depth = 1
		var end = pos + prefix.length()
		while end < code.length() and depth > 0:
			if code[end] == "{":
				depth += 1
			elif code[end] == "}":
				depth -= 1
			end += 1
		code = code.insert(end - 1, "\nALPHA *= support_envelope;\n")
	shader.code = code
	mat.shader = shader
	materials.append(mat)


func advance_lifecycle(_delta: float) -> void:
	if not is_instance_valid(subject):
		return
	tick += 1
	var age = float(tick) / float(parameters.simulation_hz)
	var fade = float(settings.get("alphaGain", 1.0))
	if settings.name == "VFX_FireStatic_K1":
		fade *= smoothstep(0.0, 0.04, age)
	if settings.name == "VFX_FireStatic_K1":
		for flame in subject.get_children():
			if flame is MeshInstance3D:
				flame.scale.y = (
					lerpf(0.14, 0.55, smoothstep(0.0, 0.16, age))
					* (1.0 - 0.30 * smoothstep(0.25, 0.7, age))
				)
	if int(settings.close) > 0 and tick > int(settings.close):
		fade *= (
			1.0
			- smoothstep(
				float(settings.close) / float(parameters.simulation_hz),
				float(settings.frames - 12) / float(parameters.simulation_hz),
				age
			)
		)
	for mat in materials:
		mat.set_shader_parameter("support_clock", age)
		mat.set_shader_parameter("support_envelope", fade)
	if tick == int(settings.close):
		if subject is GPUParticles3D:
			subject.emitting = false
		for particles in subject.find_children("*", "GPUParticles3D", true, false):
			particles.emitting = false
		for player in subject.find_children("*", "AnimationPlayer", true, false):
			for ending in ["close", "End"]:
				if player.has_animation(ending):
					player.play(ending)
					break

# Godot screen_texture may expose opaque alpha under Forward+. Quantize the
# native RGBA image here instead: RGB uses a 2px grid, alpha is byte-for-byte kept.
