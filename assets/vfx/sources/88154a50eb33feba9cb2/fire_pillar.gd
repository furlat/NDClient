extends "res://assets/vfx/sources/a4fd0883f0b17d893a03/base.gd"
## Native source authoring; shared stage, process clock, palette and capture.
const SourceMaterials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/88154a50eb33feba9cb2/fire_pillar.gd", input)


func prepare_materials(_node: Node) -> void:
	pass


var reference_frame = 0


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
	if settings.mode == "strike":
		pass
		node.scale = Vector3(1.25, 0.35, 1.25)
		for n in ["floorflash", "floorflash2", "itemflash"]:
			node.get_node(n).scale *= 0.36
		for name in ["inner_base", "windsoil", "groundmark1"]:
			node.get_node(name).layers = 0
		var p = node.get_node("muzzle")
		p.process_material = p.process_material.duplicate(true)
		p.process_material.scale_min *= 0.05
		p.process_material.scale_max *= 0.05
		for child in node.find_children("*", "GPUParticles3D", true, false):
			child.fixed_fps = 144
	if settings.mode == "strike":
		for name in settings.get("hideStrikeNodes", []):
			node.get_node(name).layers = 0
		if settings.get("strikeGroundBack", false):
			for name in ["floorflash", "floorflash2"]:
				node.get_node(name).material_override.set_meta("support_ground", true)
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
				expand_includes(VfxPackageIO_88154a50eb.text(path), path.get_base_dir()) + "\n"
			)
		else:
			result += line + "\n"
	return result


func adapt_shader(mat: ShaderMaterial) -> void:
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
	if (
		settings.id == "continual_flame"
		or settings.mode == "authored_jet"
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
		if (
			settings.mode == "authored_jet"
			and not (
				settings.get("diagnosticRaw", false) or settings.get("preserveSourceColor", false)
			)
		):
			settle += "ALBEDO=vec3(clamp(dot(ALBEDO,vec3(0.2126,0.7152,0.0722))*0.32,0.0,0.85));EMISSION=vec3(0.0);\n"
		if settings.mode == "tile" or settings.mode == "firewall":
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
	if settings.id == "mass_healing_word" and tick == 18:
		subject.get_node("SecondaryAuthoredHealingWisp").emitting = true
	if settings.mode == "authored_jet" and tick == 90:
		subject.get_node("AnimationPlayer").play("End")
	var fade = float(settings.get("alphaGain", 1.0))
	if settings.mode == "authored_jet":
		fade *= smoothstep(0.0, 0.04, age) * (1.0 - smoothstep(1.20, 1.75, age))
	if settings.mode in ["tile", "firewall"]:
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
		sh.code = (
			sh
			. code
			. replace(
				"texture(source_tex,UV)",
				"texture(source_tex,(UV+vec2(mod(floor(steam_frame*16.0),4.0),floor(clamp(steam_frame*16.0,0.0,15.0)/4.0)))/4.0)"
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

const VfxPackageIO_88154a50eb = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
