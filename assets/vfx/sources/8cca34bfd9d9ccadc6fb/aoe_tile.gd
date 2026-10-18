extends "res://assets/vfx/sources/e212c77ca5bf64639ea0/base.gd"
const SourceMaterials = preload("res://assets/vfx/sources/5f45d57a61f8be02c69c/source_materials.gd")


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/8cca34bfd9d9ccadc6fb/aoe_tile.gd", input)


func prepare_materials(_node: Node) -> void:
	pass


func apply_scene_edits(node: Node) -> void:
	prepare_tile(node, Vector2(settings.cell[0], settings.cell[1]), side)


func recolor(r: Resource) -> void:
	if r == null or visited.has(r.get_instance_id()):
		return
	visited[r.get_instance_id()] = true
	for p in r.get_property_list():
		if not (int(p.usage) & PROPERTY_USAGE_STORAGE):
			continue
		var v = r.get(p.name)
		if v is Color and v.s > 0.15:
			r.set(p.name, Color.from_hsv(0.045, v.s, v.v, v.a))
		elif v is PackedColorArray:
			var cs = PackedColorArray()
			for c in v:
				cs.append(Color.from_hsv(0.045, c.s, c.v, c.a) if c.s > 0.15 else c)
			r.set(p.name, cs)
		elif v is Resource:
			recolor(v)


func clipped_material(old: Material, cell: Vector2, side: String) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	var shader := Shader.new()
	if old is ShaderMaterial:
		shader.code = SourceMaterials.expand_shader(
			old.shader.code, old.shader.resource_path.get_base_dir()
		)
		mat.shader = shader
		for p in old.shader.get_shader_uniform_list():
			mat.set_shader_parameter(p.name, old.get_shader_parameter(p.name))
	else:
		# Standard-material features used by the artist's smoke/spark layers.
		# Preserve their textures, particle flipbooks, billboard transform and colors;
		# expose a spatial fragment hook for the actual gameplay-cell clipping.
		var vertex = ""
		if old.billboard_mode != BaseMaterial3D.BILLBOARD_DISABLED:
			vertex += "float c=cos(INSTANCE_CUSTOM.x);float s=sin(INSTANCE_CUSTOM.x);mat4 bb=mat4((INV_VIEW_MATRIX[0]*c+INV_VIEW_MATRIX[1]*s)*length(MODEL_MATRIX[0].xyz),(-INV_VIEW_MATRIX[0]*s+INV_VIEW_MATRIX[1]*c)*length(MODEL_MATRIX[1].xyz),INV_VIEW_MATRIX[2]*length(MODEL_MATRIX[2].xyz),MODEL_MATRIX[3]);MODELVIEW_MATRIX=VIEW_MATRIX*bb;"
		var h = maxi(1, old.particles_anim_h_frames)
		var v = maxi(1, old.particles_anim_v_frames)
		if h * v > 1:
			vertex += (
				"float f=min(floor(INSTANCE_CUSTOM.z*%d.0),%d.0);UV=(UV+vec2(mod(f,%d.0),floor(f/%d.0)))/vec2(%d.0,%d.0);"
				% [h * v, h * v - 1, h, h, h, v]
			)
		var vertex_color = "*COLOR" if old.vertex_color_use_as_albedo else ""
		var normal_code = (
			"NORMAL_MAP=texture(normal_tex,UV).rgb;NORMAL_MAP_DEPTH=normal_strength;"
			if old.normal_enabled
			else ""
		)
		var mode = "unshaded," if old.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED else ""
		shader.code = (
			"shader_type spatial;render_mode %sblend_mix,cull_disabled,depth_draw_never;uniform sampler2D tex:source_color,filter_linear;uniform sampler2D normal_tex:hint_normal,filter_linear;uniform float normal_strength=0.3;uniform vec4 tint:source_color=vec4(1.0);void vertex(){%s}void fragment() {vec4 c=texture(tex,UV)*tint%s;ALBEDO=c.rgb;ALPHA=c.a;%s}"
			% [mode, vertex, vertex_color, normal_code]
		)
		mat.shader = shader
		mat.set_shader_parameter("tex", old.albedo_texture)
		mat.set_shader_parameter("tint", old.albedo_color)
		if old.normal_enabled:
			mat.set_shader_parameter("normal_tex", old.normal_texture)
			mat.set_shader_parameter("normal_strength", old.normal_scale)
	var code: String = shader.code.replace("TIME", "source_clock")
	code = code.replace(
		"shader_type spatial;", "shader_type spatial;\nuniform float source_clock=0.0;"
	)
	var guard = "\nvec3 wp=(INV_VIEW_MATRIX*vec4(VERTEX,1.0)).xyz;\nif(wp.y<0.0) discard;\n"
	guard += (
		"if (floor(wp.x/2.0+0.5)!=%.1f || floor(wp.z/2.0+0.5)!=%.1f) discard;\n" % [cell.x, cell.y]
	)
	guard += (
		"if ((wp.x-(%.5f))+(wp.z-(%.5f)) %s 0.0) discard;\n"
		% [cell.x * 2.0, cell.y * 2.0, "<" if side == "front" else ">="]
	)
	code = code.replace("void fragment() {", "void fragment() {" + guard)
	shader.code = code
	mat.render_priority = old.render_priority
	materials.append(mat)
	return mat


func adapt_thunder(subject: Node3D) -> void:
	var source: GPUParticles3D = subject.get_node("cut")
	source.visible = false
	var crest := MeshInstance3D.new()
	crest.name = "AuthoredWaveDerivative"
	var imported = (
		VfxPackageIO_8cca34bfd9.resource("res://assets/vfx/sources/8b7a808febc21bdb9fae/ThunderCrest.scn").instantiate()
	)
	var imported_mesh: MeshInstance3D = (
		imported.find_children("*", "MeshInstance3D", true, false)[0]
	)
	crest.mesh = imported_mesh.mesh
	imported.queue_free()
	subject.set_meta("crest", crest)
	crest.layers = 4
	var mat := ShaderMaterial.new()
	mat.shader = VfxPackageIO_8cca34bfd9.resource("res://assets/vfx/sources/a377c4d989c237945914/ThunderCrest.gdshader")
	mat.set_shader_parameter(
		"authored_noise", source.material_override.get_shader_parameter("Disolver_Texture")
	)
	mat.set_shader_parameter(
		"authored_mask", source.material_override.get_shader_parameter("Multiply_Texture")
	)
	crest.material_override = mat
	subject.add_child(crest)
	# A second curled surface gives the wave a thicker body and a short pressure echo.
	var echo = crest.duplicate()
	echo.name = "PressureEcho"
	echo.mesh = crest.mesh
	echo.material_override = mat.duplicate()
	echo.material_override.set_shader_parameter("echo_layer", true)
	subject.add_child(echo)
	subject.set_meta("echo", echo)
	var dust: GPUParticles3D = subject.get_node("dust")
	dust.amount = 3
	dust.process_material = dust.process_material.duplicate(true)
	dust.process_material.color = Color(0.28, 0.20, 0.40, 0.30)


func prepare_tile(subject: Node, cell: Vector2, side: String) -> void:
	if settings.spell == "thunderwave":
		adapt_thunder(subject)
	var direction = Vector2(settings.direction[0], settings.direction[1]).normalized()
	subject.rotation.y = atan2(-direction.x, -direction.y)
	subject.position = Vector3(settings.emitter[0], settings.emitter[1], settings.emitter[2])
	subject.scale = Vector3(settings.scale[0], settings.scale[1], settings.scale[2])
	if settings.spell == "burning_hands":
		for node in subject.find_children("*", "", true, false):
			for p in node.get_property_list():
				if int(p.usage) & PROPERTY_USAGE_STORAGE:
					var value = node.get(p.name)
					if value is Resource:
						recolor(value)
	var index := 0
	for node in subject.find_children("*", "", true, false):
		if node is GPUParticles3D:
			if settings.spell == "burning_hands" and node.name == "fire":
				node.amount = 320
				node.process_material = node.process_material.duplicate(true)
				node.process_material.spread = 26.5
				node.process_material.flatness = 0.85
			node.use_fixed_seed = true
			node.seed = 47291 + index
			index += 1
			node.visibility_aabb = AABB(Vector3(-50, -50, -50), Vector3(100, 100, 100))
		if node is GeometryInstance3D:
			if node.material_override != null:
				node.material_override = clipped_material(node.material_override, cell, side)
		if node is AnimationPlayer:
			node.stop()
			node.clear_caches()
			if node.has_animation("Init"):
				node.play("Init")
			elif node.has_animation("Start"):
				node.play("Start")


func advance_lifecycle(_delta: float) -> void:
	tick += 1
	for subject in [self.subject]:
		if subject.has_meta("crest"):
			var crest: MeshInstance3D = subject.get_meta("crest")
			var time = float(tick) / 144.0
			crest.set_blend_shape_value(
				crest.find_blend_shape_by_name("Rise"), 1.0 - smoothstep(0.0, 0.12, time)
			)
			crest.set_blend_shape_value(
				crest.find_blend_shape_by_name("Break"), smoothstep(0.34, 0.64, time)
			)
			crest.set_blend_shape_value(
				crest.find_blend_shape_by_name("Collapse"), smoothstep(0.65, 0.89, time)
			)
			crest.position.z = 0.3 - 5.4 * clampf(time / 0.80, 0.0, 1.0)
			crest.scale.z = 1.30
			if subject.has_meta("echo"):
				var echo: MeshInstance3D = subject.get_meta("echo")
				for i in crest.get_blend_shape_count():
					echo.set_blend_shape_value(i, crest.get_blend_shape_value(i))
				echo.position.z = crest.position.z + 0.55
				echo.scale = Vector3(1.0, 0.86, 1.30)
	for mat in materials:
		mat.set_shader_parameter("source_clock", float(tick) / 144.0)
	if settings.spell == "burning_hands" and tick == 65:
		for subject in [self.subject]:
			for p in subject.find_children("*", "AnimationPlayer", true, false):
				if p.has_animation("End"):
					p.play("End")

const VfxPackageIO_8cca34bfd9 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
