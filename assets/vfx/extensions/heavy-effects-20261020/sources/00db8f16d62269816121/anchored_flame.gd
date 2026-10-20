extends "res://assets/vfx/sources/a4fd0883f0b17d893a03/base.gd"
## Native source authoring; shared stage, process clock, palette and capture.
const SourceMaterials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/extensions/heavy-effects-20261020/sources/00db8f16d62269816121/anchored_flame.gd", input)


func prepare_materials(_node: Node) -> void:
	pass


var root_field: Node
var reference_frame = 0
var packet_hit: Node3D
var packet_contact = false


func tint(c: Color) -> Color:
	if (
		(settings.get("diagnosticRaw", false) or settings.get("preserveSourceColor", false))
		or c.s < 0.08
	):
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
	if r is ShaderMaterial and not r.get_meta("gold_symbol", false):
		adapt_shader(r)


func apply_scene_edits(node: Node) -> void:
	subject = node
	node.scale *= float(settings.scale)
	node.position.y += float(settings.height)
	if settings.mode == "tile_varied":
		node.scale = Vector3(
			float(settings.get("width", .78)),
			float(settings.scale),
			float(settings.get("depth", .78))
		)
		var variant = int(settings.get("variant", 0))
		node.get_node("firepops").visible = false
		var main = node.get_node("firebursts")
		main.layers = 1
		main.amount = int(settings.get("amount", 17 + variant % 3 * 3))
		main.fixed_fps = 144
		main.process_material = main.process_material.duplicate(true)
		var pm = main.process_material
		pm.emission_ring_radius = 1.35
		pm.emission_ring_inner_radius = 0.0
		pm.scale_min = float(settings.get("scaleMin", .70))
		pm.scale_max = float(settings.get("scaleMax", 2.1))
		if settings.get("fixedFlameBase", false):
			pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
			pm.particle_flag_rotate_y = false
			pm.angle_min = 0.0
			pm.angle_max = 0.0
			pm.initial_velocity_min = 0.0
			pm.initial_velocity_max = 0.0
			pm.gravity = Vector3.ZERO
		main.lifetime = 2.0
		main.preprocess = 2.0
		# Retain the authored irregular emission. Independent particle phases avoid a synchronized atlas.
		var mat = main.material_override.duplicate(true)
		var sh = mat.shader.duplicate()
		sh.code = (
			sh
			. code
			. replace(
				"if (is_loop){ timex = TIME;}",
				"if (is_loop){ timex = fract(TIME * 0.5 + fract(dot(MODEL_MATRIX[3].xz,vec2(13.47,19.31))) + INSTANCE_CUSTOM.y * 0.13);}"
			)
		)
		if settings.get("gentleFlame", false):
			sh.code = sh.code.replace("TIME * 0.5", "TIME * 0.32")
		mat.shader = sh
		main.material_override = mat
		var secondary = (
			VfxPackageIO_00db8f16d6.resource(
				"res://assets/vfx/extensions/heavy-effects-20261020/sources/bc7dd343a29a9f43bb8e/VFX_FireDynamic_Reallistic_A.tscn"
			)
			. instantiate()
		)
		var tips = secondary.get_node("test34").duplicate()
		secondary.free()
		tips.name = "UnequalRisingFlames"
		node.add_child(tips)
		tips.scale = Vector3(.48, .7, .48)
		tips.position = Vector3(
			[-.48, .25, .52, -.28][variant % 4], .06, [.35, -.48, .1, -.25][variant % 4]
		)
		tips.layers = 1
		tips.amount = 7 + variant % 3
		tips.fixed_fps = 144
		tips.lifetime = 1.0
		tips.preprocess = 2.0
		tips.set("use_fixed_seed", true)
		tips.set("seed", int(settings.seed) + 519)
		tips.process_material = tips.process_material.duplicate(true)
		tips.process_material.scale_min = .8
		tips.process_material.scale_max = 1.7
		if settings.get("noTips", false):
			tips.visible = false
		tips.visibility_aabb = AABB(Vector3(-5, -1, -5), Vector3(10, 10, 10))
	if int(settings.get("moduleCount", 0)) > 0:
		# Accepted hollow-ring composition: independent native emitter seeds,
		# tangential modules and a shared radial boundary, with an empty centre.
		var ring_parent = Node3D.new()
		ring_parent.name = "NativeHollowFireRing"
		var parent = node.get_parent()
		parent.add_child(ring_parent)
		parent.remove_child(node)
		ring_parent.add_child(node)
		var segments: Array[Node3D] = [node]
		for i in range(1, int(settings.moduleCount)):
			var copy = node.duplicate() as Node3D
			copy.name = "NativeArcEmitter_%02d" % i
			ring_parent.add_child(copy)
			segments.append(copy)
		for i in segments.size():
			var segment = segments[i]
			var theta = TAU * float(i) / float(segments.size())
			segment.position = Vector3(cos(theta)*float(settings.ringRadius), 0, sin(theta)*float(settings.ringRadius))
			segment.rotation.y = -(theta+PI*.5)
			segment.scale = Vector3(.81, 1.65 if i%2==0 else 1.4, .26)
			var main = segment.get_node("firebursts")
			main.process_material = main.process_material.duplicate(true)
			main.material_override = main.material_override.duplicate(true)
			main.use_fixed_seed = true
			main.seed = int(settings.seed)+i*931
			main.restart()
			var tips = segment.get_node("UnequalRisingFlames")
			tips.process_material = tips.process_material.duplicate(true)
			tips.material_override = tips.material_override.duplicate(true)
			tips.position = Vector3([-.48,.25][i%2], .06, [.35,-.48][i%2])
			tips.use_fixed_seed = true
			tips.seed = int(settings.seed)+i*931+519
			tips.restart()
			for light in segment.find_children("*", "OmniLight3D", true, false):
				light.visible = false
		node = ring_parent
		subject = ring_parent
	if settings.pack.begins_with("binbun"):
		pass
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


func expand_includes(code: String, base: String) -> String:
	var result = ""
	for line in code.split("\n"):
		if line.strip_edges().begins_with("#include"):
			var path = line.get_slice('"', 1)
			if not path.begins_with("res://"):
				path = base.path_join(path)
			result += (
				expand_includes(VfxPackageIO_00db8f16d6.text(path), path.get_base_dir()) + "\n"
			)
		else:
			result += line + "\n"
	return result


func adapt_shader(mat: ShaderMaterial) -> void:
	# Particle simulation shaders must retain built-ins such as LIFETIME.
	if mat.shader.code.contains("shader_type particles"):
		return
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
	if settings.get("strikeNoDepthWrite", false):
		code = code.replace("depth_draw_opaque", "depth_draw_never")
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
	if mat.has_meta("stream_launch"):
		code = code.replace(
			"float timex = COLOR.a;",
			"float timex = clamp((support_clock-stream_launch)/0.22,0.0,0.999);"
		)
		code = code.replace(
			"shader_type spatial;", "shader_type spatial;\nuniform float stream_launch=0.0;"
		)
	var clock_token = RegEx.new()
	clock_token.compile("\\bTIME\\b")
	code = clock_token.sub(code, "support_clock", true)
	code = (
		code
		. replace(
			"shader_type spatial;",
			"shader_type spatial;\nuniform float support_clock=0.0;\nuniform float support_envelope=1.0;\nuniform float support_age=0.0;"
		)
	)
	if settings.get("groundGrowth", false):
		var heading = settings.get("growthDirection", [0, 0])
		code = code.replace(
			"shader_type spatial;", "shader_type spatial;\nvarying float flame_rise;\n"
		)
		var growth = (
			"float birth = 0.08 + clamp(dot(MODEL_MATRIX[3].xz, vec2(%s,%s)) * 0.23 + 0.28,0.0,0.6); float rising=smoothstep(birth,birth+0.55,support_age); flame_rise=rising; VERTEX.y *= max(0.008,rising);\n"
			% [heading[0], heading[1]]
		)
		var vertex_re = RegEx.new()
		vertex_re.compile("void\\s+vertex\\s*\\(\\s*\\)\\s*\\{")
		var vertex_match = vertex_re.search(code)
		if settings.get("fixedFlameBase", false):
			growth = "VERTEX.xz *= smoothstep(0.0,0.35,VERTEX.y);\n" + growth
		if vertex_match:
			code = code.insert(vertex_match.get_end(), growth)
		else:
			code += "\nvoid vertex(){" + growth + "}\n"
	var split = "<" if side == "front" else ">="
	var prefix = (
		"\nvec3 support_world=(INV_VIEW_MATRIX*vec4(VERTEX,1.0)).xyz;\nif(dot(support_world,vec3(0.70710678,0.0,0.70710678)) "
		+ split
		+ " 0.0) discard;\n"
	)
	if side == "whole":
		prefix = "\nvec3 support_world=(INV_VIEW_MATRIX*vec4(VERTEX,1.0)).xyz;\n"
	if int(settings.get("moduleCount", 0)) > 0:
		var radius = float(settings.ringRadius)
		var half_width = float(settings.ringHalfWidth)
		prefix += "float ring_radial=length(support_world.xz);if(ring_radial<%.12f||ring_radial>%.12f||support_world.y<-.02||support_world.y>%.12f)discard;\n" % [radius-half_width,radius+half_width,float(settings.ringMaxHeight)]
	if (
		settings.id == "continual_flame"
		or settings.mode in ["authored_jet", "fire_packet", "firebolt_native"]
		or settings.get("strikeWhole", false)
	):
		prefix = "\ndiscard;\n" if side == "back" else "\n"
	if mat.get_meta("support_ground", false):
		prefix = "\ndiscard;\n" if side == "front" else "\n"
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
		if int(settings.get("moduleCount", 0)) > 0:
			settle += "ALPHA *= smoothstep(4.0305086536,4.0655086536,ring_radial)*(1.-smoothstep(4.4197727224,4.4547727224,ring_radial))*(1.-smoothstep(7.98,8.485281376,support_world.y));\n"

		if settings.get("groundGrowth", false):
			settle += "ALPHA *= smoothstep(0.12,0.38,flame_rise);\n"
		if settings.get("gentleFlame", false):
			settle += "float calm_energy=dot(ALBEDO,vec3(0.2126,0.7152,0.0722));ALPHA *= smoothstep(0.07,0.24,calm_energy);ALBEDO=vec3(clamp(calm_energy*0.32,0.22,0.72));\n"
		if (
			settings.mode == "authored_jet"
			and not (
				settings.get("diagnosticRaw", false) or settings.get("preserveSourceColor", false)
			)
		):
			settle += "ALBEDO=vec3(clamp(dot(ALBEDO,vec3(0.2126,0.7152,0.0722))*0.32,0.0,0.85));EMISSION=vec3(0.0);\n"
		if (
			settings.mode in ["tile", "tile_varied", "tile_loop", "firewall"]
			and not settings.get("gentleFlame", false)
		):
			settle += "ALBEDO=vec3(clamp(dot(ALBEDO,vec3(0.2126,0.7152,0.0722))*0.65,0.05,0.85));EMISSION=vec3(0.0);\n"

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


func advance_lifecycle(_delta: float) -> void:
	if not is_instance_valid(subject):
		return
	tick += 1
	var age = float(tick) / float(parameters.simulation_hz)
	if settings.has("emission_stop_seconds") and age >= float(settings.emission_stop_seconds):
		for emitter in subject.find_children("*", "GPUParticles3D", true, false):
			emitter.emitting = false
	if is_instance_valid(root_field):
		root_field.advance(age)
	if settings.id == "mass_healing_word" and tick == 18:
		subject.get_node("SecondaryAuthoredHealingWisp").emitting = true
	if settings.mode == "authored_jet" and tick == 90:
		subject.get_node("AnimationPlayer").play("End")
	var fade = float(settings.get("alphaGain", 1.0))
	if settings.mode == "firebolt_native":
		fade *= smoothstep(0.0, 0.04, age) * (1.0 - smoothstep(1.05, 1.35, age))
	if settings.mode == "fire_packet":
		fade *= smoothstep(0.0, 0.06, age) * (1.0 - smoothstep(0.80, 1.25, age))
	if settings.mode == "fire_tile":
		fade *= smoothstep(0.0, 0.70, age)
	if settings.mode == "authored_jet":
		fade *= smoothstep(0.0, 0.04, age) * (1.0 - smoothstep(1.20, 1.75, age))
	if (
		settings.mode in ["tile", "tile_varied", "tile_loop", "firewall"]
		and not settings.get("groundGrowth", false)
	):
		fade *= smoothstep(0.0, 0.7, age)
	if settings.mode == "strike":
		fade *= 1.0 - smoothstep(1.8, 2.6, age)
	if settings.id in ["continual_flame", "daylight"]:
		fade *= smoothstep(0.0, 0.35, age)
	for mat in materials:
		if mat.has_meta("stream_launch"):
			mat.set_shader_parameter("stream_launch", float(mat.get_meta("stream_launch")))
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


# Godot screen_texture may expose opaque alpha under Forward+. Quantize the
# native RGBA image here instead: RGB uses a 2px grid, alpha is byte-for-byte kept.
func convert_standard(source: StandardMaterial3D) -> ShaderMaterial:
	var mat = ShaderMaterial.new()
	var sh = Shader.new()
	var vertex = ""
	var flipbook = source.particles_anim_h_frames > 1
	if source.billboard_mode != BaseMaterial3D.BILLBOARD_DISABLED:
		vertex = "void vertex(){vec3 up=vec3(0.0,1.0,0.0);vec3 right=normalize(INV_VIEW_MATRIX[0].xyz);vec3 forward=normalize(cross(right,up));mat4 bb=mat4(vec4(right*length(MODEL_MATRIX[0].xyz),0.0),vec4(up*length(MODEL_MATRIX[1].xyz),0.0),vec4(forward*length(MODEL_MATRIX[2].xyz),0.0),MODEL_MATRIX[3]);MODELVIEW_MATRIX=VIEW_MATRIX*bb;}"
	if flipbook:
		vertex = vertex.replace(
			"void vertex(){",
			"varying float steam_frame;void vertex(){steam_frame=INSTANCE_CUSTOM.z;"
		)
	sh.code = (
		"shader_type spatial;render_mode unshaded,cull_disabled,depth_draw_never;uniform sampler2D source_tex:source_color;uniform vec4 source_tint:source_color=vec4(1.0);"
		+ vertex
		+ "void fragment(){vec4 c=texture(source_tex,UV)*source_tint*COLOR;ALBEDO=c.rgb*0.7;ALPHA=c.a;}"
	)
	if flipbook:
		var cols = float(source.particles_anim_h_frames)
		var rows = float(source.particles_anim_v_frames)
		var count = cols * rows
		var frame_expr = (
			"mod(floor(steam_frame*%s),%s)" % [count, count]
			if source.particles_anim_loop
			else "clamp(floor(steam_frame*%s),0.0,%s)" % [count, count - 1.0]
		)
		sh.code = sh.code.replace(
			"texture(source_tex,UV)",
			(
				"texture(source_tex,(UV+vec2(mod(%s,%s),floor(%s/%s)))/vec2(%s,%s))"
				% [frame_expr, cols, frame_expr, cols, cols, rows]
			)
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

const VfxPackageIO_00db8f16d6 = preload("res://assets/vfx/extensions/heavy-effects-20261020/scoped_resource_io.gd")
