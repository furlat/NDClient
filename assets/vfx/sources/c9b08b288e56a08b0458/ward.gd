extends "res://assets/vfx/sources/a4fd0883f0b17d893a03/base.gd"
const SpatialEnergyPalette = preload("res://assets/vfx/sources/386bc581a35eb3b9ee50/spatial_energy_palette.gd")
var mats: Array[ShaderMaterial] = []
var stones: Array[MeshInstance3D] = []
var velocities: Array[Vector3] = []


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/c9b08b288e56a08b0458/ward.gd", input)


func prepare_materials(_node: Node) -> void:
	pass


func apply_scene_edits(node: Node) -> void:
	node.scale = Vector3.ONE * float(settings.scale)
	node.position.y = float(settings.height)
	if settings.id.begins_with("ward"):
		node.set_script(null)
		var aura = node.get_node("Aura")
		aura.local_coords = true
		aura.amount = 28 if settings.id == "ward_hold" else 72
		aura.process_material = aura.process_material.duplicate()
		aura.process_material.gravity = Vector3(0, 0.65, 0)
		aura.process_material.radial_accel_min = 0.05
		aura.process_material.radial_accel_max = 0.1
		if settings.id == "ward_trigger":
			aura.amount = 28
			aura.process_material.scale_min *= 0.75
			aura.process_material.scale_max *= 0.75
			aura.process_material.gravity = Vector3(0, 3.5, 0)
			aura.lifetime = 0.95
			aura.one_shot = true
			aura.explosiveness = 0.85
		if settings.id == "ward_hold":
			node.get_node("MeshInstance3D").scale = Vector3.ONE * 1.0
	else:
		node.get_node("windwave1").layers = 0
		if settings.id in ["stone_hold", "stone_cast"]:
			var donor = node.get_node("debirs_mini_A")
			var rock_mesh = donor.draw_pass_1
			for child in node.find_children("*", "GPUParticles3D", true, false):
				child.layers = 0
			for i in range(16):
				var rock = MeshInstance3D.new()
				rock.mesh = rock_mesh
				rock.material_override = donor.material_override.duplicate()
				var size = rock_mesh.get_aabb().size
				var extent = maxf(size.x, maxf(size.y, size.z))
				rock.scale = Vector3.ONE * (0.105 + float(i % 3) * 0.045) / maxf(extent, 0.001)
				var angle = float(i) * TAU / 16.0 + 0.12 * sin(float(i) * 1.7)
				var radius = 1.15 + float(i % 3) * 0.16
				var tilt = -0.48 + float(i % 5) * 0.23
				var radial = Vector3(cos(angle), sin(angle) * sin(tilt), sin(angle) * cos(tilt))
				var tangent = Vector3(-sin(angle), cos(angle) * sin(tilt), cos(angle) * cos(tilt))
				rock.position = Vector3(0, 1.05, 0) + radial * radius
				rock.rotation = Vector3(angle, angle * 0.7, angle * 1.3)
				velocities.append(tangent * sqrt(5.0 / radius) * (0.93 + float(i % 2) * 0.09))
				if settings.id == "stone_cast":
					rock.position = Vector3(
						cos(angle) * (0.25 + float(i % 4) * 0.14),
						3.0 + float(i % 5) * 0.28,
						sin(angle) * (0.25 + float(i % 4) * 0.14)
					)
					velocities[i] = Vector3(0, -0.4, 0)
				node.add_child(rock)
				stones.append(rock)
	for child in node.find_children("*", "GeometryInstance3D", true, false):
		if child is GPUParticles3D:
			child.fixed_fps = 144
			child.use_fixed_seed = true
			child.seed = 47291
		if child.material_override is StandardMaterial3D:
			child.material_override = convert_standard(child.material_override)
		if child.material_override is ShaderMaterial:
			child.material_override = child.material_override.duplicate(false)
			child.material_override.set_shader_parameter("proximity_fade", false)
			if settings.id.begins_with("ward") and child.name == "Aura":
				child.material_override.set_shader_parameter(
					"shape_curve", 2.7 if settings.id == "ward_trigger" else 1.7
				)
			adapt(child.material_override)
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
		if settings.id.begins_with("ward"):
			# The live floor depth remains enabled. Feather the last source-space
			# strip above it so the star's lower rays do not end at a hard flat cut.
			var ending: int = code.rfind("}")
			code = code.insert(ending, "\nALPHA *= smoothstep(0.0, 0.20, wp.y);\n")
	sh.code = code
	NativeShaderBindings.replace_shader(mat, sh)
	for key in params:
		if params[key] != null:
			mat.set_shader_parameter(key, params[key])
	for key in defaults:
		if mat.get_shader_parameter(key) == null:
			mat.set_shader_parameter(key, defaults[key])
	if settings.id.begins_with("ward"):
		SpatialEnergyPalette.apply(mat, settings.palette)
	mats.append(mat)


# Covered samples determine the block color; transparent RGB never supplies it.
# Native Godot readback -> palette/edge cleanup -> PNG. No post-export repaint.


func advance_lifecycle(_delta: float) -> void:
	if not is_instance_valid(subject):
		return
	tick += 1
	var age = float(tick) / 144.0
	var envelope = 1.0
	if settings.id == "stone_hold":
		# Velocity Verlet in native world coordinates: central inverse-square force.
		# Irregular radii, inclinations, masses/scales and speeds; no screen-space ring.
		var dt = 1.0 / 144.0
		for i in range(stones.size()):
			var rock = stones[i]
			var r = rock.position - Vector3(0, 1.05, 0)
			var acceleration = -5.0 * r / pow(maxf(r.length(), 0.3), 3.0)
			rock.position += velocities[i] * dt + acceleration * (0.5 * dt * dt)
			var next_r = rock.position - Vector3(0, 1.05, 0)
			var next_acceleration = -5.0 * next_r / pow(maxf(next_r.length(), 0.3), 3.0)
			velocities[i] += (acceleration + next_acceleration) * (0.5 * dt)
			rock.rotate_object_local(
				Vector3(0.3, 0.8, 0.2).normalized(), dt * (0.4 + float(i) * 0.11)
			)
	if settings.id == "stone_cast":
		var dt = 1.0 / 144.0
		for i in range(stones.size()):
			var rock = stones[i]
			velocities[i].y -= 6.0 * dt
			rock.position += velocities[i] * dt
			var radial = Vector2(rock.position.x, rock.position.z)
			# Rounded body proxy only for this application audition; no actor deformation.
			var surface = 1.45 if radial.length() < 0.52 else 0.08
			if rock.position.y < surface and velocities[i].y < 0:
				rock.position.y = surface
				velocities[i].y = -velocities[i].y * 0.18
				var outward = radial.normalized()
				velocities[i].x = outward.x * 0.65
				velocities[i].z = outward.y * 0.65
			rock.rotate_object_local(
				Vector3(0.3, 0.8, 0.2).normalized(), dt * (1.0 + float(i) * 0.13)
			)
	if settings.id == "ward_cast":
		envelope = smoothstep(0.0, 0.22, age) * (1.0 - smoothstep(0.9, 1.8, age))
		subject.scale = (
			Vector3.ONE * float(settings.scale) * lerpf(1.1, 0.65, smoothstep(0.2, 1.8, age))
		)
	elif settings.id == "ward_trigger":
		envelope = smoothstep(0.0, 0.06, age) * (1.0 - smoothstep(0.45, 1.5, age))
		subject.scale = Vector3(
			float(settings.scale), float(settings.scale) * (1.0 + 0.5 * age), float(settings.scale)
		)
	elif settings.id == "ward_hold":
		envelope = 0.20
	elif settings.id != "stone_hold":
		envelope = 1.0 - smoothstep(1.2, 1.95, age)
	for mat in mats:
		mat.set_shader_parameter("vfx_clock", age)
		mat.set_shader_parameter("vfx_alpha", envelope)
