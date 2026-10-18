extends "res://assets/vfx/sources/a4fd0883f0b17d893a03/base.gd"
## Shared native recipient geometry/material construction, no camera or recorder.
var assembly: Node3D
var envelope: MeshInstance3D
var blades: Array[MeshInstance3D] = []
var seal: MeshInstance3D
var donor: Node3D


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/02e8eda447821da38634/necrotic.gd", input)


func prepare_materials(_node: Node) -> void:
	pass  # Donor construction and procedural surfaces already bind their materials exactly once.


func recolor(r: Resource) -> void:
	if r == null or visited.has(r.get_instance_id()):
		return
	visited[r.get_instance_id()] = true
	for p in r.get_property_list():
		if not (int(p.usage) & PROPERTY_USAGE_STORAGE):
			continue
		var v = r.get(p.name)
		if v is Color:
			r.set(
				p.name,
				Color(
					minf(v.v, .55) if settings.kind == "circle" else v.v,
					minf(v.v, .55) if settings.kind == "circle" else v.v,
					minf(v.v, .55) if settings.kind == "circle" else v.v,
					v.a
				)
			)
		elif v is Resource:
			recolor(v)
		elif v is PackedColorArray:
			var colors = PackedColorArray()
			for c in v:
				colors.append(
					Color(
						minf(c.v, .55) if settings.kind == "circle" else c.v,
						minf(c.v, .55) if settings.kind == "circle" else c.v,
						minf(c.v, .55) if settings.kind == "circle" else c.v,
						c.a
					)
				)
			r.set(p.name, colors)
	if r is Mesh:
		for i in r.get_surface_count():
			recolor(r.surface_get_material(i))
	if r is ShaderMaterial:
		adapt_shader(r)


func add_donor(path: String, size: float, height: float) -> Node3D:
	var d = VfxPackageIO_02e8eda447.resource(path).instantiate()
	ResourceGraph.isolate_node(d, {})
	assembly.add_child(d)
	d.scale = Vector3.ONE * size
	d.position.y = height
	# Isolate authored source resources before changing their clocks or materials.
	for c in [d] + d.find_children("*", "", true, false):
		if c is GPUParticles3D:
			c.fixed_fps = 144
			c.use_fixed_seed = true
			c.seed = 61702
			c.process_material = c.process_material.duplicate(true)
			for i in range(c.draw_passes):
				var mesh = c.get("draw_pass_" + str(i + 1))
				if mesh is Resource:
					c.set("draw_pass_" + str(i + 1), mesh.duplicate(true))
			if (c is GPUParticles3D or c is MeshInstance3D) and c.material_override:
				c.material_override = c.material_override.duplicate(true)
			c.restart()
		if c is MeshInstance3D:
			c.mesh = c.mesh.duplicate(true)
			if (c is GPUParticles3D or c is MeshInstance3D) and c.material_override:
				c.material_override = c.material_override.duplicate(true)
		for p in c.get_property_list():
			if int(p.usage) & PROPERTY_USAGE_STORAGE and c.get(p.name) is Resource:
				recolor(c.get(p.name))
		if c is AnimationPlayer and c.has_animation("Init"):
			c.play("Init")
	return d


func apply_scene_edits(node: Node) -> void:
	tick = 0
	assembly = Node3D.new()
	node.add_child(assembly)
	# Production q0 ground axes (64,32),(-64,32); Y correction gives (0,-64).
	assembly.scale.y = sqrt(2. / 3.)
	if settings.kind == "harm":
		donor = add_donor("res://assets/vfx/sources/7369a78ff84eee8fdbbc/FamilyStatusDark.tscn", .48, .69)
		donor.set_script(null)
		# Preserve its authored noise sphere and streaks, remove the loose orbiting swarm.
		donor.get_node("Particles").visible = false
		var mesh = donor.get_node("Mesh")
		mesh.material_override.set_shader_parameter("proximity_fade", false)
		mesh.material_override.set_shader_parameter("primary_color", Color(1., .22, .12))
		mesh.material_override.set_shader_parameter("secondary_color", Color(.34, .065, .04))
		mesh.material_override.set_shader_parameter("tertiary_color", Color(.11, .15, .19))
		mesh.material_override.set_shader_parameter("emission", 1.2)
		mesh.material_override.set_shader_parameter("hue_variation", 0.)
		mesh.material_override.set_shader_parameter("waviness", .08)
		mesh.material_override.set_shader_parameter("support_opacity", .28)
		for i in [0, 2, 4]:
			make_fold(i)
		# Harm uses the connected compression surface, not the command rune.
	elif settings.kind == "stunned":
		for i in range(3):
			make_star(i)
	elif settings.kind == "kill" or settings.kind == "stun":
		donor = add_donor("res://assets/vfx/sources/8d0029337d39d86670d4/FamilyStatusShatter.tscn", .62, .70)
		donor.set_script(null)
		donor.get_node("Aura").amount = 8
		for c in donor.find_children("*", "", true, false):
			if (c is GPUParticles3D or c is MeshInstance3D) and c.material_override:
				c.material_override.set_shader_parameter("proximity_fade", false)
				c.material_override.set_shader_parameter(
					"primary_color",
					Color(.95, .28, .16) if settings.kind == "kill" else Color(.15, .50, 1.)
				)
				c.material_override.set_shader_parameter(
					"secondary_color",
					Color(.38, .045, .025) if settings.kind == "kill" else Color(.05, .18, .55)
				)
				c.material_override.set_shader_parameter("emission", 1.7)
		add_seal(1.28, 1.13)


func make_star(index: int) -> void:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(10):
		st.set_uv(Vector2(.5, .5))
		st.add_vertex(Vector3.ZERO)
		for j in [i, i + 1]:
			var a = TAU * j / 10. - PI / 2.
			var r = .085 if j % 2 == 0 else .038
			st.set_uv(Vector2(.5 + cos(a) * .5, .5 + sin(a) * .5))
			st.add_vertex(Vector3(cos(a) * r, sin(a) * r, 0.))
	st.generate_normals()
	var f = MeshInstance3D.new()
	f.mesh = st.commit()
	var m = ShaderMaterial.new()
	var sh = Shader.new()
	sh.code = "shader_type spatial;render_mode unshaded,cull_disabled,depth_draw_never;void fragment(){ALBEDO=vec3(.4,.70,.94);EMISSION=vec3(.2,.4,.55);ALPHA=1.;}"
	m.shader = sh
	adapt_shader(m)
	f.material_override = m
	assembly.add_child(f)
	blades.append(f)


func make_fold(index: int) -> void:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nx = 6
	var ny = 24
	var count = 6 if settings.kind == "harm" else 8
	var a0 = float(index) * TAU / count
	for j in range(ny):
		for i in range(nx):
			for c in [
				Vector2i(i, j),
				Vector2i(i + 1, j),
				Vector2i(i + 1, j + 1),
				Vector2i(i, j),
				Vector2i(i + 1, j + 1),
				Vector2i(i, j + 1)
			]:
				var u = float(c.x) / nx
				var v = float(c.y) / ny
				var width = .78 if settings.kind == "harm" else .16
				var a = a0 + (u - .5) * width + sin(v * PI * 1.2 + a0) * .12
				var r = .36 + sin(v * PI) * .15
				var h = (
					.08 + v * (1.50 + .08 * sin(a0 * 2.))
					if settings.kind == "harm"
					else .70 + (v - .5) * 1.40
				)
				st.set_uv(Vector2(u, v))
				st.add_vertex(Vector3(cos(a) * r, h, sin(a) * r))
	st.generate_normals()
	var f = MeshInstance3D.new()
	f.mesh = st.commit()
	f.material_override = custom_material(0)
	assembly.add_child(f)
	blades.append(f)


func add_seal(size: float, height: float) -> void:
	seal = MeshInstance3D.new()
	var q = QuadMesh.new()
	q.size = Vector2(size, size)
	seal.mesh = q
	seal.position = Vector3(.055, height, .055)
	seal.rotation.y = PI / 4.
	seal.material_override = custom_material(1)
	assembly.add_child(seal)


func custom_material(style: int) -> ShaderMaterial:
	var m = ShaderMaterial.new()
	var s = Shader.new()
	s.code = VfxPackageIO_02e8eda447.text(parameters.layer_shader)
	m.shader = s
	(
		m
		. set_shader_parameter(
			"noise_tex",
			VfxPackageIO_02e8eda447.resource(
				"res://assets/vfx/sources/6961d971113968c3631f/texture.res"
			)
		)
	)
	m.set_shader_parameter("style", style)
	m.set_shader_parameter(
		"mode", 0 if settings.kind == "harm" else (1 if settings.kind == "kill" else 2)
	)
	adapt_shader(m)
	return m


func advance_lifecycle(_delta: float) -> void:
	if assembly == null:
		return
	tick += 1
	var age = float(tick) / 144.
	var env = 1. - smoothstep(.88, 1.28, age)
	if settings.kind == "circle":
		env = 1. - smoothstep(.90, 1.28, age)
	if settings.kind == "stunned":
		env = 1.
	for m in materials:
		m.set_shader_parameter("support_clock", age)
		m.set_shader_parameter("support_envelope", env)
	if settings.kind == "stunned":
		for i in range(blades.size()):
			var a = TAU * (age / (44. / 32.) + float(i) / 3.)
			blades[i].position = Vector3(cos(a) * .30, 1.55 + .035 * sin(a * 2.), sin(a) * .30)
			blades[i].rotation = Vector3(0., PI / 4., sin(a) * .15)
	if settings.kind == "harm":
		donor.scale = Vector3.ONE * .48 * (1. - .30 * smoothstep(.10, .55, age))
		for f in blades:
			f.scale = Vector3(
				1. - .32 * smoothstep(.10, .55, age), 1., 1. - .32 * smoothstep(.10, .55, age)
			)
	elif settings.kind == "kill" or settings.kind == "stun":
		var compress = 1. - .72 * smoothstep(.03, .20, age)
		for f in blades:
			f.scale = Vector3(compress, 1., compress)


func expand_includes(code: String, base: String) -> String:
	var result = ""
	for line in code.split("\n"):
		if line.strip_edges().begins_with("#include"):
			var path = line.get_slice('"', 1)
			if not path.begins_with("res://"):
				path = base.path_join(path)
			result += (
				expand_includes(VfxPackageIO_02e8eda447.text(path), path.get_base_dir()) + "\n"
			)
		else:
			result += line + "\n"
	return result


func adapt_shader(mat: ShaderMaterial) -> void:
	var shader = Shader.new()
	var code: String = expand_includes(mat.shader.code, mat.shader.resource_path.get_base_dir())
	# Source-relative includes must resolve from the copied shader resource.
	code = code.replace("TIME", "support_clock")
	code = (
		code
		. replace(
			"shader_type spatial;",
			"shader_type spatial;\nuniform float support_clock=0.0;\nuniform float support_envelope=1.0;\nuniform float support_opacity=1.0;"
		)
	)
	var split = "<" if side == "front" else ">="
	var prefix = (
		"\nvec3 support_world=(INV_VIEW_MATRIX*vec4(VERTEX,1.0)).xyz;\nif(dot(support_world,vec3(0.70710678,0.0,0.70710678)) "
		+ split
		+ " 0.0) discard;\n"
	)
	if settings.kind == "circle":
		prefix = "\nvec3 support_world=(INV_VIEW_MATRIX*vec4(VERTEX,1.0)).xyz;\nif(length(support_world.xz)>12.0 || support_world.y<0.0) discard;\n"
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
		code = code.insert(
			end - 1,
			(
				"\nALPHA *= support_envelope * support_opacity;\n"
				if parameters.get("support_opacity", true)
				else "\nALPHA *= support_envelope;\n"
			)
		)
	shader.code = code
	NativeShaderBindings.replace_shader(mat, shader)
	materials.append(mat)

const VfxPackageIO_02e8eda447 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
