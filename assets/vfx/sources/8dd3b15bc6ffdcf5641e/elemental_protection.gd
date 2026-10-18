extends "res://assets/vfx/sources/a4fd0883f0b17d893a03/base.gd"
## Native source authoring; shared stage, process clock, palette and capture.
const SourceMaterials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
const SpatialEnergyPalette = preload("res://assets/vfx/sources/386bc581a35eb3b9ee50/spatial_energy_palette.gd")


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/8dd3b15bc6ffdcf5641e/elemental_protection.gd", input)


func prepare_materials(_node: Node) -> void:
	pass


var mats: Array[ShaderMaterial] = []
var ap: AnimationPlayer
var pixel_material: ShaderMaterial


func apply_scene_edits(node: Node) -> void:
	subject = node
	if settings.kind == "sanctuary":
		node.scale = Vector3.ONE * 0.24
		var original = node.get_node("YingYang_Kar")
		var mark = original.duplicate()
		mark.name = "SanctuaryMark"
		node.add_child(mark)
		mark.position = Vector3(0, 11.25, 0)
		mark.scale = Vector3.ONE * 0.70
		mark.quaternion = Quaternion(Vector3.UP, Vector3(12, 9.797958971, 12).normalized())
		node.get_node("YingYang_Base_Circle").lifetime = 4.8
	elif settings.kind.begins_with("mage_armor"):
		node.scale = Vector3.ONE * (0.93 if settings.kind == "mage_armor" else 1.03)
	else:
		node.scale = Vector3.ONE * 1.23
	for child in node.find_children("*", "GeometryInstance3D", true, false):
		if str(child.name).contains("Distortion"):
			child.layers = 0
			continue
		if (
			settings.kind == "sanctuary"
			and (
				child.name
				not in [
					"YingYang_Base_Circle",
					"YingYang_Kar",
					"Small Sparks",
					"Small Sparks2",
					"torus2white",
					"torus3black",
					"SanctuaryMark"
				]
			)
		):
			child.layers = 0
			continue
		if child is GPUParticles3D:
			child.fixed_fps = 144
			child.use_fixed_seed = true
			child.seed = 47291
		if child.material_override is StandardMaterial3D:
			child.material_override = convert_standard(child.material_override)
		if child is GPUParticles3D and child.draw_pass_1 and not child.material_override:
			var sm = child.draw_pass_1.surface_get_material(0)
			if sm is StandardMaterial3D:
				child.material_override = convert_standard(sm)
		if child.material_override is ShaderMaterial:
			child.material_override = child.material_override.duplicate(false)
			if settings.kind == "shield":
				child.material_override.set_shader_parameter("Overlay_Scale", Vector2(0.75, 0.75))
				child.material_override.set_shader_parameter("Overlay_Velocity", Vector2(0, -0.08))
			adapt(
				child.material_override,
				(
					settings.kind == "sanctuary"
					and child.name in ["YingYang_Base_Circle", "YingYang_Kar", "SanctuaryMark"]
				),
				child.name in ["YingYang_Kar", "SanctuaryMark"]
			)
		elif child is MeshInstance3D and child.mesh:
			child.mesh = child.mesh.duplicate(true)
			for s in range(child.mesh.get_surface_count()):
				var m = child.mesh.surface_get_material(s)
				if m is ShaderMaterial:
					m = m.duplicate(true)
					adapt(
						m,
						(
							settings.kind == "sanctuary"
							and child.name in ["YingYang_Base_Circle", "YingYang_Kar"]
						)
					)
					child.set_surface_override_material(s, m)
		# Ground motif belongs below the character, regardless of its horizontal extent.
		if (
			settings.kind == "sanctuary"
			and child.name in ["YingYang_Base_Circle", "YingYang_Kar"]
			and side == "front"
		):
			child.layers = 0
		if child.name == "SanctuaryMark" and side == "back":
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
	if settings.kind == "shield":
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
		if settings.kind in ["shield", "hit", "energy"] or settings.kind.begins_with("mage_armor"):
			split = (
				"\nvec3 wp=(INV_VIEW_MATRIX*vec4(VERTEX,1.0)).xyz; if(dot(wp-vec3(0.0,1.12,0.0),vec3(0.612372436,0.5,0.612372436)) "
				+ op
				+ " 0.0) discard;\n"
			)
		if settings.kind.begins_with("mage_armor"):
			split = split.replace("1.12", "0.93" if settings.kind == "mage_armor" else "1.03")
		# Sanctuary ground plane is one coherent symbol, not half a symbol.
		if ground:
			split = ""
		code = code.insert(at, split)
		var depth = 1
		var end = at + split.length()
		while end < code.length() and depth > 0:
			if code[end] == "{":
				depth += 1
			elif code[end] == "}":
				depth -= 1
			end += 1
		if settings.kind == "shield":
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
	if settings.kind == "energy":
		SpatialEnergyPalette.apply(mat, settings.palette)
	mats.append(mat)


func advance_lifecycle(_delta: float) -> void:
	if not is_instance_valid(subject):
		return
	tick += 1
	var age = float(tick) / float(parameters.simulation_hz)
	var alpha = 1.0
	if settings.kind == "energy":
		alpha = lerpf(0.85, 0.23, smoothstep(0.75, 1.65, age))
	elif settings.kind.begins_with("mage_armor"):
		var opacity = (
			lerpf(1.0, 0.22, smoothstep(2.0, 2.8, age)) * (1.0 - smoothstep(6.5, 7.3, age))
		)
		if pixel_material:
			pixel_material.set_shader_parameter("output_opacity", opacity)
	elif settings.kind == "sanctuary":
		alpha = (1.0 - smoothstep(4.8, 5.6, age)) * 0.85
	if settings.kind == "shield" and tick == 720:
		for p in subject.find_children("*", "AnimationPlayer", true, false):
			if p.has_animation("end_animation"):
				p.play("end_animation")
	if settings.kind == "sanctuary":
		var mark = subject.get_node("SanctuaryMark")
		var original = subject.get_node("YingYang_Kar")
		mark.visible = true
		mark.material_override.set_shader_parameter(
			"Alpha_Treshold", original.material_override.get_shader_parameter("Alpha_Treshold")
		)
		mark.material_override.set_shader_parameter(
			"Color_Intensity", original.material_override.get_shader_parameter("Color_Intensity")
		)
		mark.quaternion = (
			Quaternion(Vector3.UP, Vector3(12, 9.797958971, 12).normalized())
			* Quaternion(Vector3.UP, sin(age * 1.2) * 0.08)
		)
		for geo in subject.find_children("*", "GeometryInstance3D", true, false):
			geo.transparency = smoothstep(4.8, 5.6, age)
	for m in mats:
		m.set_shader_parameter("vfx_clock", age)
		m.set_shader_parameter("vfx_alpha", alpha)

# Accepted LeLu Lab palette/alpha shader runs on the GPU before PNG readback.
