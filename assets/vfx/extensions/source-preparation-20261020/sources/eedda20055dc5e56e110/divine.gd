extends "res://assets/vfx/extensions/source-preparation-20261020/sources/542662543981a7706f49/base.gd"
const GOLD_GLYPH_CODE = "shader_type spatial;\nrender_mode unshaded,cull_disabled;\nuniform float support_clock=0.0;\nuniform float support_envelope=1.0;\nuniform float support_age=0.0;\nuniform int kind=0;\nuniform float glyph_phase=0.0;\nuniform sampler2D gold_noise;\nvoid vertex(){MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0]*length(MODEL_MATRIX[0].xyz),INV_VIEW_MATRIX[1]*length(MODEL_MATRIX[1].xyz),INV_VIEW_MATRIX[2]*length(MODEL_MATRIX[2].xyz),MODEL_MATRIX[3]);}\nfloat line(vec2 p,vec2 a,vec2 b){vec2 v=b-a;return length(p-a-v*clamp(dot(p-a,v)/dot(v,v),0.0,1.0));}\nvoid fragment(){\n vec2 p=UV*2.0-1.0;\n float d=10.0;\n float close=smoothstep(0.15,0.48,support_clock)*(1.0-smoothstep(3.4,3.75,support_clock));\n if(kind==0){\n  float x=clamp(p.x,-0.78,0.78);\n  float bow=0.37*(1.0-pow(x/0.78,2.0));\n  float lower=bow;\n  float upper=mix(-bow,bow,close);\n  if(abs(p.x)<0.8){d=min(abs(p.y-upper),abs(p.y-lower));}\n  d=min(d,line(p,vec2(0.77,0),vec2(0.96,-0.15)));\n  d=min(d,line(p,vec2(-0.77,0),vec2(-0.95,-0.10)));\n  if(close>0.7){\n   d=min(d,line(p,vec2(-0.48,0.23),vec2(-0.60,0.59)));\n   d=min(d,line(p,vec2(-0.05,0.36),vec2(-0.06,0.74)));\n   d=min(d,line(p,vec2(0.40,0.27),vec2(0.54,0.61)));\n  }\n  if(close<0.9&&p.y>upper&&p.y<lower){d=min(d,abs(length(p*vec2(1.0,0.7))-0.12));}\n }else if(kind==1){\n  vec2 pts[9]=vec2[9](vec2(-0.55,-0.1),vec2(-0.56,-0.47),vec2(-0.31,-0.7),vec2(0.12,-0.72),vec2(0.39,-0.46),vec2(0.35,-0.05),vec2(0.03,0.28),vec2(-0.03,0.64),vec2(-0.31,0.71));\n  for(int i=0;i<8;i++){d=min(d,line(p,pts[i],pts[i+1]));}\n  d=min(d,line(p,vec2(-0.31,0.71),vec2(-0.49,0.48)));\n  d=min(d,line(p,vec2(-0.32,-0.20),vec2(-0.25,-0.43)));\n  d=min(d,line(p,vec2(-0.25,-0.43),vec2(0.05,-0.39)));\n  d=min(d,line(p,vec2(0.05,-0.39),vec2(0.07,-0.13)));\n  d=min(d,line(p,vec2(0.07,-0.13),vec2(-0.19,0.1)));\n  if(close>0.6){d=min(d,line(p,vec2(0.14,0.18),vec2(0.60,-0.22)));}\n  else{d=min(d,abs(length(p-vec2(-0.9,0))-0.20));}\n }else{\n  float snap=1.0-0.2*smoothstep(2.6,2.8,support_clock);\n  p/=snap;\n  d=min(line(p,vec2(-0.75,-0.55),vec2(-0.35,0.1)),line(p,vec2(0.75,-0.55),vec2(0.35,0.1)));\n  d=min(d,line(p,vec2(-0.35,0.1),vec2(0,-0.5)));\n  d=min(d,line(p,vec2(0,-0.5),vec2(0.35,0.1)));\n  d=min(d,line(p,vec2(0,0.1),vec2(0,0.62)));\n }\n float mask=1.0-smoothstep(0.085,0.12,d);\n ALPHA=mask*support_envelope;\n float grain=texture(gold_noise,UV*2.0+vec2(sin(glyph_phase),cos(glyph_phase))*0.07).r;\n float facet=floor(grain*4.0)/3.0;\n float edge=1.0-smoothstep(0.01,0.075,d);\n ALBEDO=vec3(clamp(0.57+facet*0.20+edge*0.14,0.0,0.94));\n}\n"


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/extensions/source-preparation-20261020/sources/eedda20055dc5e56e110/divine.gd", input)


func apply_scene_edits(node: Node) -> void:
	node.scale *= float(settings.scale)
	node.position.y += float(settings.height)
	if settings.pack.begins_with("binbun"):
		node.set_script(null)
	if settings.id == "continual_flame":
		node.get_node("Smoke").layers = 0
		node.get_node("Smoke").emitting = false
		var p = node.get_node("Flame")
		p.sub_emitter = NodePath("")
		p.amount = 20
		p.fixed_fps = 144
		p.process_material = p.process_material.duplicate(true)
	if settings.id == "beacon_of_hope":
		node.get_node("OmniLight3D").free()
		for n in ["Ring_01", "Ring_02", "Ring_03", "GlowCore"]:
			node.get_node(n).layers = 0
		node.get_node("Flare").scale *= 0.35
		node.get_node("Pillar_02").material_override = (
			node.get_node("Pillar_02").material_override.duplicate(true)
		)
		node.get_node("Pillar_02").material_override.set_meta("hold_phase", 1.0)
		for n in ["Pillar_01", "Pillar_02"]:
			node.get_node(n).scale *= Vector3(3.6, 1.25, 3.6)
			node.get_node(n).position.y += 0.0
		for p in node.find_children("*", "GPUParticles3D", true, false):
			p.amount = 24
			p.fixed_fps = 144
	if settings.id == "divine_proclamation":
		node.get_node("OmniLight3D").free()
		for n in [
			"Ring_01", "Ring_02", "Ring_03", "GlowCore", "Pillar_01", "Pillar_02", "GPUParticles3D2"
		]:
			node.get_node(n).layers = 0
		var flare = node.get_node("Flare").material_override
		flare.set_shader_parameter("flare_ring", 0.0)
		flare.set_shader_parameter("flare_streaks", 18.0)
		flare.set_shader_parameter("flare_amount", 0.7)
		node.get_node("Flare").scale *= 2.5
		node.get_node("ShapeParticles").amount = 36
	if settings.id == "daylight":
		var glow = node.get_node("Glow").material_override
		var gradient = Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
		gradient.colors = PackedColorArray(
			[Color(0.95, 0.95, 0.95), Color(0.75, 0.75, 0.75), Color(0.3, 0.3, 0.3)]
		)
		var texture = GradientTexture1D.new()
		texture.gradient = gradient
		glow.set_shader_parameter("fresnel_gradient", texture)
		glow.set_shader_parameter("fresnel_exponent", 1.2)
		glow.set_shader_parameter("proximity_fade", false)
		glow.set_shader_parameter("emission_strength", 0.9)
		var f = node.get_node("Flare").material_override
		f.set_shader_parameter("flare_streaks", 12.0)
		f.set_shader_parameter("flare_ring", 0.0)
		f.set_shader_parameter("flare_amount", 0.28)
	if settings.id == "mass_healing_word":
		node.get_node("white_Line_horizontal").layers = 0
		var pulse = node.get_node("verticalflash")
		pulse.scale = Vector3(1.8, 0.85, 1.8)
		pulse.lifetime = 1.05
		var wisp = pulse.duplicate()
		wisp.name = "SecondaryAuthoredHealingWisp"
		wisp.position.x = 0.0
		wisp.position.z = 0.0
		wisp.scale = Vector3(1.2, 0.75, 1.2)
		node.add_child(wisp)
		wisp.emitting = false
		wisp.one_shot = true
		wisp.explosiveness = 1.0
	if String(settings.id).begins_with("divine_condition_"):
		for player in node.find_children("*", "AnimationPlayer", true, false):
			player.stop()
			player.active = false
		for child in node.find_children("*", "GeometryInstance3D", true, false):
			child.layers = 0
		var chip = node.get_node("smallparticles7").duplicate()
		chip.name = "GoldenConditionChips"
		node.add_child(chip)
		chip.layers = 1
		chip.position = Vector3(0, 0.0, 0)
		chip.amount = 6
		chip.lifetime = 0.45
		chip.one_shot = false
		chip.explosiveness = 0.0
		chip.fixed_fps = 144
		chip.use_fixed_seed = true
		chip.seed = 7339
		chip.process_material = chip.process_material.duplicate(true)
		chip.process_material.emission_ring_radius = 0.42
		chip.process_material.emission_ring_inner_radius = 0.32
		chip.process_material.emission_ring_height = 0.15
		chip.process_material.initial_velocity_min = 0.15
		chip.process_material.initial_velocity_max = 0.4
		chip.process_material.gravity = Vector3(0, -0.25, 0)
		chip.process_material.scale_min = 0.8
		chip.process_material.scale_max = 1.3
		chip.process_material.scale_curve = null
		chip.draw_pass_1 = chip.draw_pass_1.duplicate(true)
		chip.draw_pass_1.size = Vector2(0.10, 0.12)
		chip.material_override = chip.material_override.duplicate(true)
		chip.emitting = true
		chip.restart()
		var mesh = QuadMesh.new()
		mesh.size = Vector2(0.68, 0.64)
		var mark = MeshInstance3D.new()
		mark.name = "GoldenConditionGlyph"
		mark.mesh = mesh
		node.add_child(mark)
		var mat = ShaderMaterial.new()
		var shader = Shader.new()
		shader.code = GOLD_GLYPH_CODE
		mat.shader = shader
		mat.set_shader_parameter("kind", 0 if settings.id.ends_with("blinded") else 1)
		var noise = FastNoiseLite.new()
		noise.seed = 7339
		noise.frequency = 0.13
		var texture = NoiseTexture2D.new()
		texture.width = 64
		texture.height = 64
		texture.noise = noise
		texture.seamless = true
		mat.set_shader_parameter("gold_noise", texture)
		mat.set_meta("gold_symbol", true)
		mark.material_override = mat
		if side == "back":
			mark.layers = 0
		materials.append(mat)
	if settings.id == "divine_word":
		for n in [
			"VFX_Shield_blue_wild",
			"symbol marks",
			"SmCylinderVulkano",
			"torus2 aura",
			"floorflash2",
			"floorflash3"
		]:
			var c = node.get_node(n)
			if c is GeometryInstance3D:
				c.layers = 0
			else:
				for m in c.find_children("*", "GeometryInstance3D", true, false):
					m.layers = 0
		for ap in node.find_children("*", "AnimationPlayer", true, false):
			if ap.has_animation("Init"):
				var anim = ap.get_animation("Init")
				for track in anim.get_track_count():
					var path = String(anim.track_get_path(track))
					if path in ["smallparticles6:emitting", "smallparticles7:emitting"]:
						for key in anim.track_get_key_count(track):
							anim.track_set_key_time(track, key, 0.12 if key == 0 else 0.9)
		node.get_node("smallparticles6").amount = 48
		node.get_node("smallparticles7").amount = 36
		for name in ["smallparticles6", "smallparticles7"]:
			var p = node.get_node(name)
			p.process_material = p.process_material.duplicate(true)
			p.process_material.emission_ring_radius = 1.4
			p.process_material.emission_ring_inner_radius = 0.7
			p.process_material.radial_velocity_min = 0.6
			p.process_material.radial_velocity_max = 1.4
			p.position.y += 0.65
			p.process_material.gravity = Vector3(0, 0.2, 0)
			if p.process_material.scale_curve is CurveXYZTexture:
				var curve = p.process_material.scale_curve.curve_y
				for i in curve.point_count:
					var point = curve.get_point_position(i)
					point.y *= 0.35
					curve.set_point_value(i, point.y)
			p.fixed_fps = 144


func prepare_materials(node: Node) -> void:
	for child in node.find_children("*", "", true, false):
		if child is GeometryInstance3D:
			if "distort" in String(child.name).to_lower():
				child.layers = 0
			if (
				child.material_override is ShaderMaterial
				and "hint_screen_texture" in child.material_override.shader.code
			):
				child.layers = 0
		if child is GeometryInstance3D and child.material_override is StandardMaterial3D:
			child.material_override = convert_standard(child.material_override)
		if (
			settings.id == "beacon_of_hope"
			and child is GeometryInstance3D
			and child.material_override is ShaderMaterial
		):
			child.material_override.set_meta(
				"application_only", not String(child.name).begins_with("Pillar")
			)
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
	if r is ShaderMaterial and not r.get_meta("gold_symbol", false):
		adapt_shader(r)


func adapt_shader(mat: ShaderMaterial) -> void:
	if settings.id == "continual_flame":
		mat.set_shader_parameter("emission", 0.65)
		mat.set_shader_parameter("proximity_fade", false)
	if settings.id in ["beacon_of_hope", "divine_proclamation"]:
		mat.set_shader_parameter("emission", 1.0)
		mat.set_shader_parameter("density", 0.9)
		mat.set_shader_parameter("streaks", 5.0)
		mat.set_shader_parameter("scroll", 1.0 if settings.id == "beacon_of_hope" else 0.45)
	var shader = Shader.new()
	var code: String = expand_includes(mat.shader.code, mat.shader.resource_path.get_base_dir())
	# The tiny floor seal used non-mipmapped alpha scissoring and wrote depth.
	# At recipient scale it became glitter and cut into overlapping floor waves.
	if settings.name == "VFX_Healing_Area" and code.contains("uniform float Base_intensity"):
		code = code.replace("filter_linear;", "filter_linear_mipmap_anisotropic;")
		code = code.replace("depth_draw_opaque", "depth_draw_never")
		code = code.replace(
			"ALPHA_SCISSOR_THRESHOLD = n_out55p0;",
			"ALPHA *= smoothstep(n_out55p0, n_out55p0 + 0.08, n_out74p1);"
		)
	# Source-relative includes must resolve from the copied shader resource.
	if settings.id == "divine_proclamation" and code.contains("flare_streaks"):
		code = code.replace("ALPHA = value * 0.2;", "ALPHA = value * 0.85;")
		code = (
			code
			. replace(
				"mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3])",
				"mat4(INV_VIEW_MATRIX[0]*length(MODEL_MATRIX[0].xyz), INV_VIEW_MATRIX[1]*length(MODEL_MATRIX[1].xyz), INV_VIEW_MATRIX[2]*length(MODEL_MATRIX[2].xyz), MODEL_MATRIX[3])"
			)
		)
		mat.set_shader_parameter("emission", 2.0)
	if settings.id == "beacon_of_hope":
		code = code.replace("sin(TIME * 2.0)", "sin(TIME * 3.14159265359)")
	if settings.id == "daylight":
		code = code.replace("TIME", "(sin(TIME * 3.14159265359) * 0.25)")
	if settings.id == "continual_flame":
		code = code.replace(
			"ALBEDO = main_color;",
			"ALBEDO = vec3(clamp(dot(main_color,vec3(0.2126,0.7152,0.0722))*1.4,0.0,1.0));"
		)
		code = code.replace("ALBEDO * 3.0", "ALBEDO * 0.75")
	code = code.replace("TIME", "support_clock")
	code = (
		code
		. replace(
			"shader_type spatial;",
			"shader_type spatial;\nuniform float support_clock=0.0;\nuniform float support_envelope=1.0;\nuniform float support_age=0.0;"
		)
	)
	var split = "<" if side == "front" else ">="
	var prefix = (
		"\nvec3 support_world=(INV_VIEW_MATRIX*vec4(VERTEX,1.0)).xyz;\nif(dot(support_world,vec3(0.70710678,0.0,0.70710678)) "
		+ split
		+ " 0.0) discard;\n"
	)
	if settings.id == "continual_flame":
		prefix = "\ndiscard;\n" if side == "back" else "\n"
	if mat.get_meta("support_ground", false):
		prefix = "\ndiscard;\n" if side == "front" else "\n"
	prefix = prefix.replace(
		"vec3(0.70710678,0.0,0.70710678)", "vec3(%s,%s,%s)" % parameters.clip_normal
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
		var settle = "\nALPHA *= support_envelope;\n"
		if settings.id == "beacon_of_hope":
			settle += "ALPHA *= 1.0-smoothstep(1.8,2.8,support_age)*(1.0-smoothstep(1.10,1.20,support_world.y));\n"
		code = code.insert(end - 1, settle)
	if settings.pack == "binbun-statusfxfull":
		# Keep donor noise and motion, but fill the body surface instead of retaining
		# only its overexposed speckled peaks at game size.
		code = code.replace("smoothstep(0.5, 0.8, value)", "smoothstep(0.25, 0.70, value)")
		mat.set_shader_parameter("primary_color", Color(0.85, 0.85, 0.85))
		mat.set_shader_parameter("secondary_color", Color(0.38, 0.38, 0.38))
		mat.set_shader_parameter("tertiary_color", Color(0.48, 0.48, 0.48))
		mat.set_shader_parameter("emission", 1.0)
		mat.set_shader_parameter("hue_variation", 0.0)
		mat.set_shader_parameter("proximity_fade", false)
	shader.code = code
	mat.shader = shader
	materials.append(mat)


func convert_standard(source: StandardMaterial3D) -> ShaderMaterial:
	var mat = ShaderMaterial.new()
	var sh = Shader.new()
	var vertex = ""
	if source.billboard_mode != BaseMaterial3D.BILLBOARD_DISABLED:
		vertex = "void vertex(){vec3 up=vec3(0.0,1.0,0.0);vec3 right=normalize(INV_VIEW_MATRIX[0].xyz);vec3 forward=normalize(cross(right,up));mat4 bb=mat4(vec4(right*length(MODEL_MATRIX[0].xyz),0.0),vec4(up*length(MODEL_MATRIX[1].xyz),0.0),vec4(forward*length(MODEL_MATRIX[2].xyz),0.0),MODEL_MATRIX[3]);MODELVIEW_MATRIX=VIEW_MATRIX*bb;}"
	sh.code = (
		"shader_type spatial;render_mode unshaded,cull_disabled,depth_draw_never;uniform sampler2D source_tex:source_color;uniform vec4 source_tint:source_color=vec4(1.0);"
		+ vertex
		+ "void fragment(){vec4 c=texture(source_tex,UV)*source_tint*COLOR;ALBEDO=c.rgb*0.7;ALPHA=c.a;}"
	)
	mat.shader = sh
	var tex = source.albedo_texture
	if tex == null:
		var im = Image.create(1, 1, false, Image.FORMAT_RGBA8)
		im.fill(Color.WHITE)
		tex = ImageTexture.create_from_image(im)
	mat.set_shader_parameter("source_tex", tex)
	mat.set_shader_parameter("source_tint", source.albedo_color)
	return mat


func advance_lifecycle(_delta: float) -> void:
	if not is_instance_valid(subject):
		return
	tick += 1
	var age = float(tick) / 144.0
	if settings.id == "mass_healing_word" and tick == 18:
		subject.get_node("SecondaryAuthoredHealingWisp").emitting = true
	var fade = float(settings.get("alphaGain", 1.0))
	if settings.id in ["continual_flame", "daylight"]:
		fade *= smoothstep(0.0, 0.35, age)
	if settings.id == "beacon_of_hope":
		fade *= smoothstep(0.0, 0.35, age) * lerpf(1.0, 0.65, smoothstep(1.5, 2.8, age))
	if settings.id == "divine_proclamation":
		fade *= smoothstep(0.0, 0.08, age) * (1.0 - smoothstep(0.25, 0.85, age))
		subject.scale = (
			Vector3.ONE * float(settings.scale) * lerpf(0.3, 1.5, smoothstep(0.0, 0.5, age))
		)
	if settings.id == "divine_word":
		fade *= 1.0 - smoothstep(1.3, 2.6, age)
	for mat in materials:
		mat.set_shader_parameter("support_age", age)
		mat.set_shader_parameter(
			"support_clock",
			(
				0.9
				if mat.get_meta("gold_symbol", false)
				else age + float(mat.get_meta("hold_phase", 0.0)) * smoothstep(2.0, 3.0, age)
			)
		)
		if mat.get_meta("gold_symbol", false):
			mat.set_shader_parameter("glyph_phase", age * PI)
		mat.set_shader_parameter(
			"support_envelope",
			(
				fade * (1.0 - smoothstep(2.0, 3.0, age))
				if settings.id == "beacon_of_hope" and mat.get_meta("application_only", false)
				else fade
			)
		)
