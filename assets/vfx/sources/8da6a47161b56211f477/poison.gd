extends "res://assets/vfx/sources/a4fd0883f0b17d893a03/base.gd"
var mats: Array[ShaderMaterial] = []
var ap: AnimationPlayer
var pixel_material: ShaderMaterial


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/8da6a47161b56211f477/poison.gd", input)


func prepare_materials(_node: Node) -> void:
	pass


func apply_scene_edits(node: Node) -> void:
	node.scale = Vector3.ONE * float(settings.scale)
	for player in node.find_children("*", "AnimationPlayer", true, false):
		for name in player.get_animation_list():
			var anim = player.get_animation(name)
			for i in range(anim.get_track_count() - 1, -1, -1):
				var path = String(anim.track_get_path(i))
				if (
					path.contains("smallparticles7:emitting")
					or (
						name == "End"
						and (
							path.begins_with("symbolWHq:") or path.begins_with("transfloorflash5:")
						)
					)
				):
					anim.remove_track(i)
	var particles = node.get_node("smallparticles7")
	particles.one_shot = false
	particles.explosiveness = 0.0
	particles.amount = 90
	particles.emitting = true
	particles.local_coords = true
	for child in node.find_children("*", "GeometryInstance3D", true, false):
		if (
			"distort" in String(child.name).to_lower()
			or String(child.name).begins_with("ShieldSphere")
		):
			child.layers = 0
			continue
		if child is GPUParticles3D:
			child.fixed_fps = 144
			child.use_fixed_seed = true
			child.seed = 47291
		if child.material_override is StandardMaterial3D:
			child.material_override = convert_standard(child.material_override)
		if child.material_override is ShaderMaterial:
			child.material_override = child.material_override.duplicate(false)
			child.material_override.set_meta("role", String(child.name))
			adapt(child.material_override, child.name in ["symbolWHq", "transfloorflash5"])
			if child.name in ["symbolWHq", "transfloorflash5"] and side == "front":
				child.layers = 0
	for light in node.find_children("*", "Light3D", true, false):
		light.visible = false


func convert_standard(source: StandardMaterial3D) -> ShaderMaterial:
	var mat = ShaderMaterial.new()
	var sh = Shader.new()
	sh.code = "shader_type spatial; render_mode unshaded,cull_disabled; uniform sampler2D source_tex:source_color; uniform vec4 source_tint:source_color=vec4(1.0); uniform bool use_vertex=true; void fragment(){vec4 c=texture(source_tex,UV)*source_tint; if(use_vertex)c*=COLOR; ALBEDO=c.rgb; ALPHA=c.a;}"
	mat.shader = sh
	var texture = source.albedo_texture
	if texture == null:
		var im = Image.create(1, 1, false, Image.FORMAT_RGBA8)
		im.fill(Color.WHITE)
		texture = ImageTexture.create_from_image(im)
	mat.set_shader_parameter("source_tex", texture)
	mat.set_shader_parameter("source_tint", source.albedo_color)
	mat.set_shader_parameter("use_vertex", source.vertex_color_use_as_albedo)
	return mat


func adapt(mat: ShaderMaterial, ground: bool = false, dual: bool = false) -> void:
	var params = {}
	for uniform in mat.shader.get_shader_uniform_list():
		params[uniform.name] = mat.get_shader_parameter(uniform.name)
	var original_shader = mat.shader
	var defaults = {}
	for uniform in original_shader.get_shader_uniform_list():
		if uniform.type == TYPE_OBJECT:
			var tex = original_shader.get_default_texture_parameter(uniform.name)
			if tex != null:
				defaults[uniform.name] = tex
	var sh = Shader.new()
	var code = mat.shader.code.replace("shadow_to_opacity, ", "")
	if settings.get("kind", "poison") == "shield":
		# Widen the existing texture lines before sampling the final pixel grid.
		code = (
			code
			. replace(
				"n_out41p0 = texture(Overlay_Texture, n_out46p0);",
				"n_out41p0 = max(texture(Overlay_Texture,n_out46p0),max(max(texture(Overlay_Texture,n_out46p0+vec2(0.0015,0)),texture(Overlay_Texture,n_out46p0-vec2(0.0015,0))),max(texture(Overlay_Texture,n_out46p0+vec2(0,0.0015)),texture(Overlay_Texture,n_out46p0-vec2(0,0.0015)))));"
			)
		)
	code = code.replace("TIME", "vfx_clock")
	code = code.replace(
		"shader_type spatial;",
		"shader_type spatial;\nuniform float vfx_clock=0.0;\nuniform float vfx_alpha=1.0;"
	)
	var regex = RegEx.new()
	regex.compile("void\\s+fragment\\s*\\(\\s*\\)\\s*\\{")
	var found = regex.search(code)
	if found:
		var at = found.get_end()
		var op = "<" if side == "front" else ">="
		var split = (
			"\nvec3 wp=(INV_VIEW_MATRIX*vec4(VERTEX,1.0)).xyz; if(dot(wp,vec3(0.70710678,0.0,0.70710678)) "
			+ op
			+ " 0.0) discard;\n"
		)
		if (
			settings.get("kind", "poison") in ["shield", "hit"]
			or settings.get("kind", "poison").begins_with("mage_armor")
		):
			split = (
				"\nvec3 wp=(INV_VIEW_MATRIX*vec4(VERTEX,1.0)).xyz; if(dot(wp-vec3(0.0,1.12,0.0),vec3(0.612372436,0.5,0.612372436)) "
				+ op
				+ " 0.0) discard;\n"
			)
		if settings.get("kind", "poison").begins_with("mage_armor"):
			split = split.replace(
				"1.12", "0.93" if settings.get("kind", "poison") == "mage_armor" else "1.03"
			)
		# Ground application stays behind the actor as one coherent surface.
		if ground:
			split = ""
		split = split.replace(
			"vec3(0.70710678,0.0,0.70710678)", "vec3(%s,%s,%s)" % parameters.clip_normal
		)
		code = code.insert(at, split)
		var depth = 1
		var end = at + split.length()
		while end < code.length() and depth > 0:
			if code[end] == "{":
				depth += 1
			elif code[end] == "}":
				depth -= 1
			end += 1
		if settings.get("kind", "poison") == "shield":
			var hex_lines = "\nfloat readable_hex=smoothstep(0.30,0.65,n_out41p1)*n_out57p0; ALBEDO=max(ALBEDO,vec3(0.025,0.23,0.7)*readable_hex); ALPHA=max(ALPHA,0.42*readable_hex);\n"
			code = code.insert(end - 1, hex_lines)
			end += hex_lines.length()
		code = code.insert(
			end - 1,
			(
				("\nALBEDO=clamp(ALBEDO,vec3(0.035,0.025,0.045),vec3(1.0));\n" if dual else "")
				+ "\nALPHA *= vfx_alpha;\n"
			)
		)
	sh.code = code
	mat.shader = sh
	for key in params:
		if params[key] != null:
			mat.set_shader_parameter(key, params[key])
	for key in defaults:
		if mat.get_shader_parameter(key) == null:
			mat.set_shader_parameter(key, defaults[key])
	mats.append(mat)


func advance_lifecycle(_delta: float) -> void:
	if not is_instance_valid(subject):
		return
	tick += 1
	var age = float(tick) / 144.0
	if tick == 216:
		subject.get_node("AnimationPlayer").play("End")
	var fade = 1.0 - smoothstep(7.0, 7.9, age)
	for m in mats:
		m.set_shader_parameter("vfx_clock", age)
		var role = String(m.get_meta("role", ""))
		var alpha = fade
		if role == "symbolWHq":
			alpha *= 1.0 - smoothstep(1.4, 2.4, age)
		if role == "transfloorflash5":
			alpha *= 1.0 - smoothstep(1.2, 1.8, age)
		m.set_shader_parameter("vfx_alpha", alpha)
	if tick == 1008:
		subject.get_node("smallparticles7").emitting = false
