extends "res://assets/vfx/sources/a4fd0883f0b17d893a03/base.gd"
## Preserved native authoring geometry and material lifecycle, with shared capture/clock ownership.
const SourceMaterials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/137cf9cc5700f7fe4686/cone_of_cold.gd", input)


func prepare_materials(_node: Node) -> void:
	pass


const YC = .816496580927726
var raw_cache = {}
var assembly: Node3D
var mats: Array[ShaderMaterial] = []
var puffs: Array = []
var shards: Array = []
var flares: Array = []
var rng = RandomNumberGenerator.new()


func adapt(shader_code: String) -> Shader:
	var s = Shader.new()
	var code = shader_code.replace("TIME", "cold_age")
	code = (
		code
		. replace(
			"shader_type spatial;",
			"shader_type spatial;\nuniform float cold_age=0.;\nuniform float opacity=1.;\nuniform bool stream=false;\nuniform sampler2D edge_noise:repeat_enable,filter_linear;\n"
		)
	)
	var pre = "vec3 wp=(INV_VIEW_MATRIX*vec4(VERTEX,1.)).xyz;"
	# Angular/range masks belong to the authored cone, not the camera/world axes.
	# Keep the accepted canonical shader unchanged when no yaw is requested.
	var yaw = deg_to_rad(float(settings.get("source_yaw_degrees", 0.0)))
	if not is_zero_approx(yaw):
		pre += "vec2 localxz=mat2(vec2(%.12f,%.12f),vec2(%.12f,%.12f))*wp.xz;vec3 realp=vec3(localxz.x,wp.y,localxz.y)/vec3(1.,.81649658,1.);" % [cos(yaw), sin(yaw), -sin(yaw), cos(yaw)]
	else:
		pre += "vec3 realp=wp/vec3(1.,.81649658,1.);"
	if settings.layer < 3:
		pre += "float depth=wp.x+wp.z;"
		if settings.layer == 0:
			pre += "if(depth>=%.12f)discard;" % float(settings.get("source_depth_cuts", [4.5, 9.])[0])
		elif settings.layer == 1:
			pre += "if(depth<%.12f||depth>=%.12f)discard;" % [float(settings.get("source_depth_cuts", [4.5, 9.])[0]), float(settings.get("source_depth_cuts", [4.5, 9.])[1])]
		else:
			pre += "if(depth<%.12f)discard;" % float(settings.get("source_depth_cuts", [4.5, 9.])[1])
	elif settings.layer >= 4:
		pre += "if((wp.x+wp.z>=0.)!=" + ("true" if settings.layer == 5 else "false") + ")discard;"
	code = code.replace("void fragment() {", "void fragment(){").replace(
		"void fragment(){", "void fragment(){" + pre
	)
	var start = code.find("void fragment(){") + "void fragment(){".length()
	var depth = 1
	var at = start
	while at < code.length() and depth > 0:
		if code[at] == "{":
			depth += 1
		elif code[at] == "}":
			depth -= 1
		at += 1
	var post = "\nALPHA*=opacity;\n"
	if settings.layer < 3:
		post += """float r=length(realp.xz);float angular=abs(atan(realp.z,max(realp.x,.001)));
	float grain=texture(edge_noise,realp.xz*.21).r;
	ALPHA*=smoothstep(-.03,.18,realp.y)*(1.-smoothstep(11.5+grain*.23,12.,r))*(1.-smoothstep(.418+grain*.026,.46251225,angular));
	if(stream){float travel=realp.x/22.;float local_age=cold_age-.10-travel;ALPHA*=pow(abs(dot(NORMAL,VIEW)),.65);ALPHA*=smoothstep(-.08,.06,local_age)*(1.-smoothstep(.58,.98,local_age));}
"""
	code = code.insert(at - 1, post)
	s.code = code
	return s


func custom(code: String) -> ShaderMaterial:
	var m = ShaderMaterial.new()
	m.shader = adapt(code)
	m.set_shader_parameter(
		"edge_noise",
		raw(
			"res://assets/vfx/sources/900721c102c94ad02849/texture.res"
		)
	)
	mats.append(m)
	return m


func mist(strength: float, streamed: bool) -> ShaderMaterial:
	var m = VfxPackageIO_137cf9cc57.resource("res://assets/vfx/sources/ae7b90df27a2647b2686/mist.tres").duplicate(false)
	var mist_code = (
		SourceMaterials
		. expand_shader(m.shader.code, m.shader.resource_path.get_base_dir())
		. replace(
			"render_mode blend_mix;",
			"render_mode blend_mix,unshaded,cull_disabled,depth_draw_never;"
		)
	)
	mist_code = mist_code.replace("pow(alpha_mask, 3.0)", "pow(alpha_mask, 1.8)")
	m.shader = adapt(mist_code)
	m.set_shader_parameter("billboard", false)
	m.set_shader_parameter("emission_strength", .10)
	m.set_shader_parameter("primary_color", Color(.65, .85, .90))
	m.set_shader_parameter("secondary_color", Color(.25, .52, .67))
	m.set_shader_parameter("tertiary_color", Color(.12, .29, .40))
	m.set_shader_parameter("use_tertiary", false)
	m.set_shader_parameter("mask2_scale", Vector2(4., 2.6))
	m.set_shader_parameter("mask1_scroll", Vector2(-.72, .035))
	m.set_shader_parameter("mask2_scroll", Vector2(-.34, -.14))
	m.set_shader_parameter("mask2_blend_mode", 3)
	m.set_shader_parameter("use_mask3", not streamed)
	m.set_shader_parameter("alpha_multiplier", strength)
	m.set_shader_parameter("alpha_cutoff", 0.)
	m.set_shader_parameter("proximity_fade", false)
	m.set_shader_parameter("stream", streamed)
	m.set_shader_parameter(
		"edge_noise",
		raw(
			"res://assets/vfx/sources/900721c102c94ad02849/texture.res"
		)
	)
	mats.append(m)
	return m


func envelope(v: float, a: float, b: float) -> float:
	return smoothstep(a, b, v)


func tube(index: int) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings = 64
	var sides = 32
	var radius = [1., .73, .44][index]
	for i in range(rings):
		for j in range(sides):
			for q in [
				Vector2i(i, j),
				Vector2i(i + 1, j),
				Vector2i(i + 1, j + 1),
				Vector2i(i, j),
				Vector2i(i + 1, j + 1),
				Vector2i(i, j + 1)
			]:
				var x = .55 + float(q.x) / rings * 11.45
				var a = float(q.y) / sides * TAU
				var width = x * .498581 * radius
				var ridge = (.045 + .018 * x) * sin(x * 2.4 + a * 3. + index * 1.7)
				var y = .90 + sin(a) * (minf(.20 + x * .155, 2.05) * radius + ridge)
				st.set_uv(Vector2(x / 12., float(q.y) / sides))
				st.set_color(Color(float(index) * .17, 1., 1., 1.))
				st.add_vertex(Vector3(x, y, -.1 + cos(a) * width))
	st.generate_normals()
	return st.commit()


func apply_scene_edits(node: Node) -> void:
	settings.layer = int(settings.layer)
	rng.seed = 628103
	assembly = Node3D.new()
	assembly.scale.y = YC
	node.add_child(assembly)
	if settings.layer == 3:
		var f = MeshInstance3D.new()
		var p = PlaneMesh.new()
		p.size = Vector2(24., 24.)
		f.mesh = p
		f.position = Vector3(0., .012, 0.)
		f.material_override = custom(
			VfxPackageIO_137cf9cc57.text("res://assets/vfx/sources/9d48e53392ca3e22cc12/cone_of_cold_floor.gdshader")
		)
		assembly.add_child(f)
		return
	if settings.layer >= 4:
		contact()
		return
	for i in range(3):
		var f = MeshInstance3D.new()
		f.mesh = tube(i)
		var m = mist(.95 - i * .09, true)
		m.set_shader_parameter("mask1_scale", Vector2(6.0 + i * 1.2, 2.2 + i * .38))
		f.material_override = m
		assembly.add_child(f)
	# Soft billows accelerate and widen from the hands in native world space.
	for i in range(88):
		var f = MeshInstance3D.new()
		var q = QuadMesh.new()
		q.size = Vector2(1., 1.)
		f.mesh = q
		var m = mist(.92, false)
		m.set_shader_parameter("texture_scale", Vector2(1.2, 1.6))
		m.set_shader_parameter("mask1_scale", Vector2(1.3 + rng.randf(), 1.3 + rng.randf()))
		f.material_override = m
		assembly.add_child(f)
		var width = rng.randf_range(-.445, .445)
		puffs.append(
			{
				"node": f,
				"mat": m,
				"birth": rng.randf_range(.06, .46),
				"speed": rng.randf_range(18., 24.),
				"width": width,
				"phase": rng.randf() * TAU,
				"size": rng.randf_range(.7, 1.4)
			}
		)
	# Authored ice mesh supplies small solid crystals carried by the blast.
	var crystal = VfxPackageIO_137cf9cc57.resource(
		"res://assets/vfx/sources/1de4aba0c112cd12248b/sm_ice004uv2.res"
	)
	var bb = crystal.get_aabb()
	var source_shader = VfxPackageIO_137cf9cc57.text(
		"res://assets/vfx/sources/e0db67ddc0d6c2aa1614/ice.gdshader"
	)
	source_shader = source_shader.replace("if(wp.y<0.0||(wp.x+wp.z>=0.0)!=front)discard;", "")
	var cm = custom(
		VfxPackageIO_137cf9cc57.text("res://assets/vfx/sources/a646ff3dda161ebcfa99/cone_of_cold_crystal.gdshader")
	)
	cm.set_shader_parameter(
		"frost", raw("res://assets/vfx/sources/9dd4b1e9c98d16632575/texture.res")
	)
	for i in range(108):
		var f = MeshInstance3D.new()
		f.mesh = crystal
		f.material_override = cm
		assembly.add_child(f)
		shards.append(
			{
				"node": f,
				"birth": rng.randf_range(.05, .42),
				"speed": rng.randf_range(20., 29.),
				"width": rng.randf_range(-.46, .46),
				"vertical": rng.randf_range(-.45, .85),
				"angle": Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU),
				"size": rng.randf_range(.04, .13) / bb.size.x,
				"phase": rng.randf() * TAU
			}
		)
	# Retain the original Community 3D ice muzzle mesh and erosion masks.
	for i in range(2):
		var f = MeshInstance3D.new()
		f.mesh = VfxPackageIO_137cf9cc57.resource(
			"res://assets/vfx/sources/c2e5aa5f8f8854bcdb2b/sm_plane_coned_spiked_waved1.res"
		)
		f.position = Vector3(.55, .90, -.1)
		f.rotation.z = -PI / 2.
		assembly.add_child(f)
		var m = custom(
			VfxPackageIO_137cf9cc57.text("res://assets/vfx/sources/426586b929d7f568e4a3/cone_of_cold_flare.gdshader")
		)
		m.set_shader_parameter(
			"mask_tex", raw("res://assets/vfx/sources/ef5c68317e3e127c3045/texture.res")
		)
		m.set_shader_parameter(
			"noise_tex", raw("res://assets/vfx/sources/900721c102c94ad02849/texture.res")
		)
		f.material_override = m
		flares.append(f)


func contact() -> void:
	for i in range(12):
		var f = MeshInstance3D.new()
		var q = QuadMesh.new()
		q.size = Vector2(1., 1.)
		f.mesh = q
		var m = mist(.9, false)
		m.set_shader_parameter("texture_scale", Vector2(1.4, 1.8))
		f.material_override = m
		assembly.add_child(f)
		puffs.append(
			{
				"node": f,
				"mat": m,
				"phase": rng.randf() * TAU,
				"size": rng.randf_range(.7, 1.0),
				"height": rng.randf_range(.15, 1.6),
				"rad": rng.randf_range(.12, .44)
			}
		)
	var f = MeshInstance3D.new()
	f.mesh = VfxPackageIO_137cf9cc57.resource(
		"res://assets/vfx/sources/c2e5aa5f8f8854bcdb2b/sm_plane_coned_spiked_waved1.res"
	)
	f.rotation.z = -PI / 2.
	f.position = Vector3(-.3, .85, 0.)
	assembly.add_child(f)
	var m = custom(
		VfxPackageIO_137cf9cc57.text("res://assets/vfx/sources/426586b929d7f568e4a3/cone_of_cold_flare.gdshader")
	)
	m.set_shader_parameter(
		"mask_tex", raw("res://assets/vfx/sources/ef5c68317e3e127c3045/texture.res")
	)
	m.set_shader_parameter(
		"noise_tex", raw("res://assets/vfx/sources/900721c102c94ad02849/texture.res")
	)
	f.material_override = m
	flares.append(f)


func advance_lifecycle(_delta: float) -> void:
	if assembly == null:
		return
	tick += 1
	var age = float(tick) / 144.
	for m in mats:
		m.set_shader_parameter("cold_age", age)
	if settings.layer < 3:
		for p in puffs:
			var a = age - p.birth
			var x = .55 + maxf(0., a * p.speed)
			var r = x * sqrt(1. + p.width * p.width)
			var fade = smoothstep(0., .12, a) * (1. - smoothstep(10., 12., r))
			var y = maxf(.18, .90 + sin(x * .63 + p.phase) * minf(.30 + x * .1, 1.05))
			var z = -.1 + p.width * (x - .55) + sin(x * .9 + p.phase) * .08 * x
			p.node.visible = a >= 0. && r < 12.
			p.node.position = Vector3(x, y, z)
			p.node.basis = Basis(Vector3.UP, PI / 4.).scaled(
				Vector3((.6 + x * .16) * p.size, (.5 + x * .11) * p.size, 1.)
			)
			p.mat.set_shader_parameter("opacity", fade * .85)
		for p in shards:
			var a = age - p.birth
			var x = .55 + maxf(0., a * p.speed)
			var r = x * sqrt(1. + p.width * p.width)
			var grow = smoothstep(0., .055, a) * (1. - smoothstep(11., 12., r))
			p.node.visible = a >= 0. && r < 12.
			p.node.position = Vector3(
				x,
				maxf(.15, .90 + p.vertical * x * .17 + .12 * sin(x + p.phase)),
				-.1 + p.width * (x - .55)
			)
			p.node.basis = Basis.from_euler(p.angle + Vector3(1., 2., 1.) * a).scaled(
				Vector3(p.size * grow, p.size * .55 * grow, p.size * grow)
			)
		for i in range(flares.size()):
			var f = flares[i]
			var u = smoothstep(.0, .10, age) * (1. - smoothstep(.38, .66, age))
			f.scale = Vector3(.35 * u * (1. + .3 * i), 1.6 + .6 * i, .35 * u * (1. + .3 * i))
			f.visible = u > .01
	elif settings.layer >= 4:
		for p in puffs:
			var u = smoothstep(0., .06, age) * (1. - smoothstep(.30, .95, age))
			var a = p.phase + age * .28
			var scale0 = p.size * (.65 + age * .5)
			p.node.position = Vector3(
				cos(a) * (p.rad + age * .24), p.height + age * .28, sin(a) * (p.rad + age * .24)
			)
			p.node.basis = Basis(Vector3.UP, PI / 4.).scaled(Vector3(scale0, scale0 * .72, 1.))
			p.mat.set_shader_parameter("opacity", u * .72)
		for f in flares:
			var u = smoothstep(0., .04, age) * (1. - smoothstep(.10, .32, age))
			f.scale = Vector3(.55 * u, 1.35, .55 * u)
			f.visible = u > .01


func raw(path: String) -> ImageTexture:
	return SourceMaterials.raw_texture(path, raw_cache)

const VfxPackageIO_137cf9cc57 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
