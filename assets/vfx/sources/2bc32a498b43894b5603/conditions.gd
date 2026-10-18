extends "res://assets/vfx/sources/a4fd0883f0b17d893a03/base.gd"
const SpatialEnergyPalette = preload("res://assets/vfx/sources/386bc581a35eb3b9ee50/spatial_energy_palette.gd")

var curse_fragments: Array[Node3D] = []
var freedom_ribbons: Array[MeshInstance3D] = []
var freedom_opening: Node3D
var freedom_opening_player: AnimationPlayer


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/2bc32a498b43894b5603/conditions.gd", input)


func apply_scene_edits(node: Node) -> void:
	node.scale *= float(settings.scale)
	node.position.y += float(settings.height)
	if settings.id == "regenerate":
		node.scale *= Vector3(1.25, 1.0, 1.25)
	if settings.id == "freedom_of_movement":
		build_freedom(node)
	if settings.name == "VFX_WindAura_1" and settings.id != "freedom_of_movement":
		node.get_node("floor_flash4").layers = 0
		node.get_node("SmCylinder3").scale.y *= 0.8
		node.get_node("SmCylinder3").material_override.set_meta("freedom_open_strand", true)
	if settings.pack == "binbun-statusfxfull":
		node.set_script(null)
		for particles in node.find_children("*", "GPUParticles3D", true, false):
			particles.amount = maxi(6, int(particles.amount * 0.65))
	if settings.id == "regenerate":
		# Source aura's fourth-power alpha almost disappears at recipient pixel scale.
		# Retain authored noise/trajectories, expose their living strands natively.
		node.get_node("Aura").material_override.set_shader_parameter("shape_curve", 1.6)
		for particles in node.find_children("*", "GPUParticles3D", true, false):
			particles.local_coords = true
			particles.amount = 32
			particles.process_material.emission_shape_scale = Vector3(0.85, 1.0, 0.85)
	if settings.id == "remove_curse":
		var shell = node.get_node("Mesh")
		for sector in range(8):
			var part = shell.duplicate()
			part.name = "ReleaseFragment" + str(sector)
			part.material_override = shell.material_override.duplicate()
			part.material_override.set_meta("curse_sector", sector)
			node.add_child(part)
			curse_fragments.append(part)
		shell.layers = 0
		for particles in node.find_children("*", "GPUParticles3D", true, false):
			particles.local_coords = true
			particles.one_shot = true
			particles.explosiveness = 0.8
			particles.lifetime = 1.6
			particles.amount = 10 if particles.name == "Aura" else 32
			var process = particles.process_material as ParticleProcessMaterial
			process.radial_velocity_min = 1.0
			process.radial_velocity_max = 1.8
			process.gravity = Vector3(0, 0.25, 0)
			process.scale_min = 0.35
			process.scale_max = 0.75
	if settings.name == "VFX_Healing_Ring_A":
		node.get_node("white_Line_horizontal").layers = 0
		node.get_node("floorflash").position.y -= 0.75 / float(settings.scale)
	if settings.name == "VFX_Healing_Area":
		# The original source encloses a wide area. Each selected recipient gets its
		# own compact curtain; the source's decorative floor seal doesn't claim AoE.
		node.get_node("symbol1").scale *= 0.72
		for ground_name in ["symbol1", "waves"]:
			node.get_node(ground_name).material_override.set_meta("support_ground", true)
	if settings.get("id", "") == "mass_heal":
		var added = (
			VfxPackageIO_2bc32a498b.resource(
				"res://assets/vfx/sources/d6654b791469c50248d5/VFX_Healing_Ring_A.tscn"
			)
			. instantiate()
		)
		added.name = "MassHealRadialRelease"
		added.scale = Vector3.ONE * 0.65
		added.get_node("white_Line_horizontal").layers = 0
		node.add_child(added)
		_apply_particle_seed(added)
		added.get_node("AnimationPlayer").play("Init")
	if settings.name == "VFX_Healing_Flower":
		var flower = node.get_node("am_flower_001/Armature/Skeleton3D/LilyFlower")
		var old = flower.material_override
		var shader = Shader.new()
		shader.code = "shader_type spatial; render_mode unshaded,cull_disabled; uniform vec4 flower_color:source_color=vec4(1.0); uniform sampler2D tex:source_color; void fragment(){vec4 c=texture(tex,UV)*flower_color; ALBEDO=c.rgb; ALPHA=c.a;}"
		if settings.id == "mass_heal":
			shader.code = shader.code.replace(
				"ALBEDO=c.rgb; ALPHA=c.a;", "ALBEDO=c.rgb*0.45; ALPHA=c.a*0.65;"
			)
		var mat = ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("tex", old.albedo_texture)
		mat.set_shader_parameter("flower_color", old.albedo_color)
		flower.material_override = mat
		for player in node.find_children("*", "AnimationPlayer", true, false):
			for name in player.get_animation_list():
				var a = player.get_animation(name)
				for t in a.get_track_count():
					var path = String(a.track_get_path(t))
					if path.contains("LilyFlower:material_override:albedo_color"):
						a.track_set_path(
							t,
							NodePath(path.replace("albedo_color", "shader_parameter/flower_color"))
						)
		if settings.id == "greater_restoration":
			flower.layers = 0
	if settings.name == "VFX_Healing_Area":
		# Source contains world-space particles for a large stationary area. Recipient
		# captures need the particle trajectories in the same scaled local volume.
		for particle in node.find_children("*", "GPUParticles3D", true, false):
			particle.local_coords = true
		var sparkle = node.get_node("smallparticles5")
		var old = sparkle.material_override
		var shader = Shader.new()
		shader.code = "shader_type spatial;render_mode unshaded,blend_add,cull_disabled,depth_draw_never;uniform sampler2D tex:source_color;uniform vec4 tint:source_color=vec4(1.0);void vertex(){float c=cos(INSTANCE_CUSTOM.x);float s=sin(INSTANCE_CUSTOM.x);mat4 bb=mat4((INV_VIEW_MATRIX[0]*c+INV_VIEW_MATRIX[1]*s)*length(MODEL_MATRIX[0].xyz),(-INV_VIEW_MATRIX[0]*s+INV_VIEW_MATRIX[1]*c)*length(MODEL_MATRIX[1].xyz),INV_VIEW_MATRIX[2]*length(MODEL_MATRIX[2].xyz),MODEL_MATRIX[3]);MODELVIEW_MATRIX=VIEW_MATRIX*bb;}void fragment(){vec4 c=texture(tex,UV)*tint*COLOR;ALBEDO=c.rgb;ALPHA=c.a;}"
		var sm = ShaderMaterial.new()
		sm.shader = shader
		sm.render_priority = old.render_priority
		sm.set_shader_parameter("tex", old.albedo_texture)
		sm.set_shader_parameter("tint", old.albedo_color)
		sparkle.material_override = sm
		var animation = node.get_node("AnimationPlayer").get_animation("Start")
		for track in animation.get_track_count():
			for key in animation.track_get_key_count(track):
				animation.track_set_key_time(
					track, key, animation.track_get_key_time(track, key) / 1.8
				)
		animation.length /= 1.8


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
	# Instanced donor aliases can expose an already adapted shader through a
	# second material. Do not redeclare clocks or multiply its envelope twice.
	if mat.shader.code.contains("uniform float support_clock"):
		if mat not in materials:
			materials.append(mat)
		return
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
	if mat.has_meta("curse_sector"):
		code = code.replace(
			"shader_type spatial;", "shader_type spatial;\nuniform float curse_sector=0.0;\n"
		)
		code = (
			code
			. replace(
				"void fragment() {",
				"void fragment() {\nfloat segment=fract(UV.x + UV.y*0.045)*8.0; if(floor(segment)!=curse_sector || fract(segment)<0.12 || fract(segment)>0.88) discard;\n"
			)
		)
		mat.set_shader_parameter("curse_sector", float(mat.get_meta("curse_sector")))
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
	if mat.get_meta("support_ground", false):
		prefix = "\ndiscard;\n" if side == "front" else "\n"
	prefix = prefix.replace(
		"vec3(0.70710678,0.0,0.70710678)", "vec3(%s,%s,%s)" % parameters.clip_normal
	)
	if side == "full":
		prefix = ""
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
		var ending = "\nALPHA *= support_envelope;\n"
		if mat.get_meta("freedom_open_strand", false):
			ending += "float arc=cos((UV.x+UV.y*0.22+sin(support_clock*0.7)*0.035)*6.2831853); ALPHA *= smoothstep(0.25,0.62,arc);\n"
		code = code.insert(end - 1, ending)
	if settings.pack == "binbun-statusfxfull":
		# The donor aura's fractional power receives a negative base outside its
		# middle UV band. Keep those pixels transparent rather than propagating NaN.
		code = code.replace("pow((1.0 - abs(uv.y * 2.0 - 1.0) - 0.5) / 0.5, 0.2)", "pow(max((1.0 - abs(uv.y * 2.0 - 1.0) - 0.5) / 0.5, 0.0), 0.2)")
		# Keep donor noise and motion, but fill the body surface instead of retaining
		# only its overexposed speckled peaks at game size.
		if settings.id != "remove_curse":
			code = code.replace("smoothstep(0.5, 0.8, value)", "smoothstep(0.25, 0.70, value)")
		mat.set_shader_parameter("primary_color", Color(0.85, 0.85, 0.85))
		mat.set_shader_parameter("secondary_color", Color(0.38, 0.38, 0.38))
		mat.set_shader_parameter("tertiary_color", Color(0.48, 0.48, 0.48))
		mat.set_shader_parameter("emission", 1.0)
		mat.set_shader_parameter("hue_variation", 0.0)
		mat.set_shader_parameter("proximity_fade", false)
	shader.code = code
	NativeShaderBindings.replace_shader(mat, shader)
	SpatialEnergyPalette.apply(mat, parameters.get("native_palette", []), {"quantize": not ["remove_curse", "freedom_of_movement"].has(settings.id)})
	materials.append(mat)


func build_freedom(node: Node3D) -> void:
	var donor: ShaderMaterial = VfxPackageIO_2bc32a498b.resource("res://assets/vfx/sources/d63f0c0abc2c7e9a31cc/m_windstreaks13.tres").duplicate(true)
	donor.set_shader_parameter("speed", Vector2(0.0, 0.4))
	donor.set_shader_parameter("wind_speed", Vector2(0.0, -0.6))
	for child in node.find_children("*", "GeometryInstance3D", true, false):
		child.layers = 0
	freedom_opening = (
		VfxPackageIO_2bc32a498b.resource(
			"res://assets/vfx/sources/bfd2bc25908dd0829f16/VFX_WindTornado_Mystic.tscn"
		)
		. instantiate()
	)
	freedom_opening.name = "FreedomWhirlwind"
	node.add_child(freedom_opening)
	freedom_opening.scale = Vector3.ONE * 0.30
	for child in freedom_opening.find_children("*", "GeometryInstance3D", true, false):
		var keep = child.name == "SmCylinderBased" or child.name == "clouds_external13"
		child.layers = 1 if keep else 0
		if keep and child is GPUParticles3D:
			child.use_fixed_seed = true
			child.seed = 42617
			child.fixed_fps = 144
			child.process_material = child.process_material.duplicate(true)
			child.process_material.scale_min *= 0.55
			child.process_material.scale_max *= 0.55
			child.process_material.emission_ring_height = 2.8
			var curve = Curve.new()
			curve.add_point(Vector2(0, 0))
			curve.add_point(Vector2(0.30, 1))
			curve.add_point(Vector2(0.65, 1))
			curve.add_point(Vector2(1, 0))
			var curve_tex = CurveTexture.new()
			curve_tex.curve = curve
			child.process_material.alpha_curve = curve_tex

		if keep and child.material_override is ShaderMaterial:
			child.material_override = child.material_override.duplicate()
			child.material_override.set_meta("freedom_whirlwind", true)
	freedom_opening_player = freedom_opening.get_node("AnimationPlayer")
	freedom_opening_player.callback_mode_process = (
		AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	)
	freedom_opening_player.play("Init")
	freedom_opening_player.seek(0.0, true)
	for i in range(3):
		var ribbon = MeshInstance3D.new()
		ribbon.name = "FreedomStream" + str(i)
		ribbon.material_override = donor.duplicate()
		ribbon.material_override.set_meta("freedom_stream", true)
		node.add_child(ribbon)
		freedom_ribbons.append(ribbon)
	update_freedom(0.0)


func freedom_mesh(i: int, age: float) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var vertices = []
	var uvs = []
	for j in range(33):
		var u = float(j) / 32.0
		var a = float(i) * 2.15 + age * (1.15 + 0.12 * i) + u * (1.8 + float(i) * 0.15)
		var radius = 0.79 + 0.15 * sin(u * PI + age * 1.3 + float(i))
		var height = 0.36 + float(i) * 0.30 + u * 0.35 + 0.12 * sin(age * 1.7 + u * 3.0 + i)
		var width = (0.16 + float(i) * 0.025) * pow(sin(u * PI), 0.6)
		for edge in [-1, 1]:
			vertices.append(Vector3(cos(a) * radius, height + edge * width, sin(a) * radius))
			uvs.append(Vector2(u, float(edge + 1) * 0.5))
	for j in range(32):
		for k in [j * 2, j * 2 + 1, j * 2 + 2, j * 2 + 1, j * 2 + 3, j * 2 + 2]:
			st.set_uv(uvs[k])
			st.add_vertex(vertices[k])
	st.generate_normals()
	return st.commit()


func update_freedom(age: float) -> void:
	if is_instance_valid(freedom_opening):
		freedom_opening_player.seek(minf(age, 0.99), true)
		freedom_opening.get_node("rotator_pivot").rotation.y = -age * PI
		freedom_opening.get_node("clouds_external13").position.y = lerpf(
			0.8, 3.1, smoothstep(0.3, 1.15, age)
		)
		freedom_opening.visible = age < 2.15
	for i in freedom_ribbons.size():
		freedom_ribbons[i].mesh = freedom_mesh(i, age)


func advance_lifecycle(_delta: float) -> void:
	if not is_instance_valid(subject):
		return
	tick += 1
	var age = float(tick) / 144.0
	if settings.id == "freedom_of_movement":
		update_freedom(age)
	for i in curse_fragments.size():
		var a = (float(i) + 0.5) * TAU / 8.0
		var distance = 2.4 * smoothstep(0.1 + float(i % 3) * 0.035, 0.72, age)
		curse_fragments[i].position = Vector3(cos(a) * distance, 0.15 * distance, sin(a) * distance)
		var peel: float = smoothstep(0.12, 0.8, age)
		curse_fragments[i].rotation = Vector3(sin(a)*peel*0.65, peel*0.35, -cos(a)*peel*0.65)
	var fade = float(settings.get("alphaGain", 1.0))
	if settings.id == "regenerate":
		fade *= (
			lerpf(1.0, 0.3, smoothstep(0.8, 1.6, age)) + 0.65 * exp(-pow((age - 3.5) / 0.25, 2.0))
		)
	if settings.id == "freedom_of_movement":
		fade *= 0.9
	if settings.get("id", "") == "aid":
		fade *= lerpf(1.0, 0.24, smoothstep(1.1, 1.8, age))
	if int(settings.close) > 0 and tick > int(settings.close):
		fade *= (
			1.0
			- smoothstep(float(settings.close) / 144.0, float(settings.frames - 12) / 144.0, age)
		)
	for mat in materials:
		mat.set_shader_parameter("support_clock", age)
		var layer_fade = fade
		if mat.has_meta("freedom_stream"):
			layer_fade *= smoothstep(0.7, 1.5, age)
		if mat.has_meta("freedom_whirlwind"):
			layer_fade *= 0.85 * smoothstep(0.08, 0.60, age) * (1.0 - smoothstep(1.0, 2.15, age))
		if mat.has_meta("curse_sector"):
			layer_fade *= 0.58 * smoothstep(0.0, 0.12, age) * (1.0 - smoothstep(0.75, 1.85, age))
			mat.set_shader_parameter("edge_position", 0.12 * smoothstep(0.7, 1.7, age))
		mat.set_shader_parameter("support_envelope", layer_fade)
	if tick == int(settings.close):
		for particles in subject.find_children("*", "GPUParticles3D", true, false):
			particles.emitting = false
		for player in subject.find_children("*", "AnimationPlayer", true, false):
			for ending in ["close", "End"]:
				if player.has_animation(ending):
					player.play(ending)
					break

const VfxPackageIO_2bc32a498b = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
