extends "res://assets/vfx/sources/a4fd0883f0b17d893a03/base.gd"
## Native source authoring; shared stage, process clock, palette and capture.
const SourceMaterials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/57b9ea67c1761593cabb/touch_or_puff.gd", input)


func prepare_materials(_node: Node) -> void:
	pass


var necrotic_wrap: Node3D


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
		flame.position = Vector3(-0.22, 0.0, 0.0)
		flame.scale *= Vector3(0.8, 1.5, 0.8)
		var second = flame.duplicate()
		node.add_child(second)
		second.position = Vector3(0.28, 0.15, 0.05)
		second.scale *= Vector3(0.7, 0.8, 0.7)
		var third = flame.duplicate()
		node.add_child(third)
		third.position = Vector3(0.0, 0.1, -0.22)
		third.scale *= Vector3(0.6, 1.1, 0.6)
	if settings.name == "VFX_Smoke_z_puff":
		node.fixed_fps = 144
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
		corruption.position.z = 0.0
		corruption.lifetime = 0.70
		corruption.fixed_fps = 144
		corruption.process_material = corruption.process_material.duplicate(true)
		var curve = Curve.new()
		curve.add_point(Vector2(0, 0.9))
		curve.add_point(Vector2(0.15, 1.15))
		curve.add_point(Vector2(1, 0.2))
		var tex = CurveTexture.new()
		tex.curve = curve
		corruption.process_material.scale_curve = tex
		corruption.process_material.scale_min = 3.0
		corruption.process_material.scale_max = 3.4
		var mat = corruption.material_override.duplicate(true)
		var sh = Shader.new()
		sh.code = mat.shader.code.replace("blend_add", "blend_mix")
		sh.code = (
			sh
			. code
			. replace(
				"uniform sampler2D Mask_Texture",
				"uniform sampler2D corruption_noise : filter_linear, repeat_enable;\nuniform sampler2D Mask_Texture"
			)
		)
		sh.code = (
			sh
			. code
			. replace(
				"ALBEDO = vec3(n_out4p0.xyz);",
				"""
	float grain=texture(corruption_noise,UV*1.9+vec2(TIME*0.11,-TIME*0.08)).r;
	float radius=length((UV-vec2(0.5))*vec2(1.35,0.92));
	float edge=radius+(grain-0.5)*0.105;
	float core=(1.0-smoothstep(0.17,0.225,edge))*(1.0-smoothstep(0.51,0.74,UV.x));
	float rim=smoothstep(0.125,0.17,edge)*(1.0-smoothstep(0.18,0.225,edge));
	ALBEDO=mix(vec3(0.045),vec3(0.9),rim*0.96+n_out3p1*0.04);
	"""
			)
		)
		sh.code = sh.code.replace(
			"ALPHA = n_out6p0;", "ALPHA = max(core*0.9,n_out3p1*0.28)*n_out4p4;"
		)
		(
			mat
			. set_shader_parameter(
				"corruption_noise",
				VfxPackageIO_57b9ea67c1.resource(
					"res://assets/vfx/sources/5aecbaf1cbc2519c6be0/texture.res"
				)
			)
		)
		mat.shader = sh
		corruption.material_override = mat
		# Reuse the authored 3D darkness ribbon mesh/noise, as a finite target-local collapse.
		# It does not translate between caster and recipient.
		necrotic_wrap = (
			VfxPackageIO_57b9ea67c1.resource(
				"res://assets/vfx/sources/953396d370816cb0732f/VFX_Darkness_projectile.tscn"
			)
			. instantiate()
		)
		node.add_child(necrotic_wrap)
		necrotic_wrap.rotation.x = -PI / 2
		necrotic_wrap.position.y = -0.3
		necrotic_wrap.scale = Vector3(2.2, 2.2, 1.4)
		for component in necrotic_wrap.get_children():
			if component.name not in ["FBHead", "FBHead2inner"]:
				if component is VisualInstance3D:
					component.visible = false
				continue
			component.material_override = component.material_override.duplicate(true)
			var ramp = Gradient.new()
			ramp.offsets = PackedFloat32Array([0.18, 0.30, 0.40, 1.0])
			ramp.colors = PackedColorArray(
				[
					Color(0.22, 0.55, 0.35),
					Color(0.45, 0.9, 0.6),
					Color(0.025, 0.04, 0.03, 0.42),
					Color(0.01, 0.02, 0.012, 0.25)
				]
			)
			var ramp_tex = GradientTexture1D.new()
			ramp_tex.gradient = ramp
			component.material_override.set_shader_parameter("Color_1D_Gradient", ramp_tex)
			(
				component
				. material_override
				. set_shader_parameter(
					"Fire_Texture",
					VfxPackageIO_57b9ea67c1.resource(
						"res://assets/vfx/sources/bbbefac0deb7154eff4b/texture.res"
					)
				)
			)
			component.material_override.set_shader_parameter(
				"Fire_Scale",
				Vector2(1.7, 1.15) if component.name == "FBHead" else Vector2(2.1, 1.65)
			)
			component.material_override.set_shader_parameter("Fire_Speed", Vector2(0.15, 1.6))
			component.material_override.set_shader_parameter("Dissapear_Step", 0.18)
			var ribbon_shader = Shader.new()
			ribbon_shader.code = (
				component
				. material_override
				. shader
				. code
				. replace(
					"void fragment()",
					"varying vec3 necrotic_local;\nvoid vertex(){necrotic_local=VERTEX;float squeeze=sin(clamp(TIME/0.65,0.0,1.0)*3.14159);VERTEX.xy*=1.0-0.22*squeeze*(0.7+0.3*sin(VERTEX.z*2.4));}\nvoid fragment()"
				)
			)
			ribbon_shader.code = (
				ribbon_shader
				. code
				. replace(
					"ALPHA = n_out41p0;",
					"float angle=atan(necrotic_local.y,necrotic_local.x);float bands=smoothstep(-0.4,0.2,sin(angle*2.0+necrotic_local.z*1.4+0.7)+0.42*sin(angle*3.0-0.4));ALPHA = n_out41p0*smoothstep(-2.23,-1.8,necrotic_local.z)*bands;"
				)
			)
			component.material_override.shader = ribbon_shader

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
	if mat.shader.code.contains("uniform float support_clock"):
		if mat not in materials:
			materials.append(mat)
		return
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
	if settings.name == "VFX_Hit_dark":
		fade *= smoothstep(0.0, 0.014, age) * (1.0 - smoothstep(0.36, 0.80, age))
		if is_instance_valid(necrotic_wrap):
			var swell = lerpf(0.58, 1.0, smoothstep(0.0, 0.09, age))
			var collapse = 1.0 - 0.44 * smoothstep(0.16, 0.74, age)
			necrotic_wrap.scale = Vector3(
				2.2 * swell * collapse, 2.2 * swell * collapse, 1.4 * (0.8 + 0.2 * swell)
			)

	if settings.name == "VFX_FireStatic_K1":
		fade *= smoothstep(0.0, 0.07, age)
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

const VfxPackageIO_57b9ea67c1 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
