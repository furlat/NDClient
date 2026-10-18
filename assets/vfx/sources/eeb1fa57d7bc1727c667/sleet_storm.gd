extends "res://assets/vfx/sources/a4fd0883f0b17d893a03/base.gd"
## Preserved native authoring geometry and material lifecycle, with shared capture/clock ownership.
const SourceMaterials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/eeb1fa57d7bc1727c667/sleet_storm.gd", input)


func prepare_materials(_node: Node) -> void:
	pass


var mats: Array[ShaderMaterial] = []
var mist_mats: Array[ShaderMaterial] = []
var assembly: Node3D


func adapt(m: ShaderMaterial, opacity: float = 1.) -> void:
	var s = Shader.new()
	var code = SourceMaterials.expand_shader(m.shader.code, m.shader.resource_path.get_base_dir())
	code = code.replace("TIME", "weather_clock")
	if not code.contains("uniform float weather_clock"):
		code = (
			code
			. replace(
				"shader_type spatial;",
				"shader_type spatial;\nuniform float weather_clock=0.;\nuniform float weather_age=0.;\nuniform float weather_opacity=1.;\nuniform float weather_mist=0.;\nuniform sampler2D weather_edge_noise:repeat_enable,filter_linear;"
			)
		)
	code = code.replace(
		"render_mode blend_mix;", "render_mode blend_mix,unshaded,cull_disabled,depth_draw_never;"
	)
	var pre = "\nvec3 wp=(INV_VIEW_MATRIX*vec4(VERTEX,1.)).xyz;\nif(length(wp.xz)>8.)discard;\n"
	if side != "ground":
		pre += "if(wp.y<0. || wp.y>3.266)discard;\n"
	if side == "back":
		pre += "if(wp.x+wp.z>=0.)discard;\n"
	if side == "front":
		pre += "if(wp.x+wp.z<0.)discard;\n"
	code = code.replace("void fragment() {", "void fragment(){").replace(
		"void fragment(){", "void fragment(){" + pre
	)
	# Resource retains Binbun's three-mask composition, UV warp, colour interpolation and soft alpha.
	var start = code.find("void fragment(){") + "void fragment(){".length()
	var depth = 1
	var at = start
	while at < code.length() and depth > 0:
		if code[at] == "{":
			depth += 1
		elif code[at] == "}":
			depth -= 1
		at += 1
	at -= 1
	code = (
		code
		. insert(
			at,
			"\nALPHA*=weather_opacity * smoothstep(0.,.8,weather_age)*(1.-smoothstep(3.,4.,weather_age))*(1.-smoothstep(7.0+texture(weather_edge_noise,wp.xz*.23).r*.55,7.55+texture(weather_edge_noise,wp.xz*.23).r*.45,length(wp.xz)));\nALPHA*=mix(1.,smoothstep(.02,.55+texture(weather_edge_noise,wp.xz*.31).r*.60,wp.y)*(1.-smoothstep(2.6,3.266,wp.y)),weather_mist);\n"
		)
	)
	s.code = code
	m.shader = s
	m.set_shader_parameter("weather_opacity", opacity)
	m.set_shader_parameter(
		"weather_edge_noise",
		VfxPackageIO_eeb1fa57d7.resource(
			"res://assets/vfx/sources/900721c102c94ad02849/texture.res"
		)
	)
	mats.append(m)


func custom(code: String) -> ShaderMaterial:
	var m = ShaderMaterial.new()
	var s = Shader.new()
	s.code = (
		code
		. replace(
			"shader_type spatial;",
			"shader_type spatial;\nuniform float weather_clock=0.;\nuniform float weather_age=0.;\nuniform float weather_opacity=1.;\nuniform float weather_mist=0.;\nuniform sampler2D weather_edge_noise:repeat_enable,filter_linear;"
		)
	)
	m.shader = s
	adapt(m)
	return m


func apply_scene_edits(node: Node) -> void:
	assembly = Node3D.new()
	node.add_child(assembly)
	assembly.scale.y = sqrt(2. / 3.)
	if side == "ground":
		ground()
		return
	var rng = RandomNumberGenerator.new()
	rng.seed = 628103
	# Broad source-authored mist at different heights/scales, not tile-centred stamps.
	for i in range(9):
		var a = rng.randf() * TAU
		var r = sqrt(rng.randf()) * 7.0
		var depth_offset = float(i - 4) * 1.85 + rng.randf_range(-.62, .62)
		var q = QuadMesh.new()
		q.size = Vector2(19.5, 8.0)
		var f = MeshInstance3D.new()
		f.mesh = q
		f.position = Vector3(depth_offset / sqrt(2.), 1.8, depth_offset / sqrt(2.))
		assembly.add_child(f)
		var m = VfxPackageIO_eeb1fa57d7.resource("res://assets/vfx/sources/ae7b90df27a2647b2686/mist.tres").duplicate(true)
		m.set_shader_parameter("billboard", true)
		m.set_shader_parameter("emission_strength", 0.)
		m.set_shader_parameter("primary_color", Color(.57, .69, .76))
		m.set_shader_parameter("secondary_color", Color(.39, .51, .59))
		m.set_shader_parameter("tertiary_color", Color(.29, .39, .48))
		m.set_shader_parameter(
			"texture_scale", Vector2(rng.randf_range(2.0, 3.7), rng.randf_range(1.6, 2.8))
		)
		m.set_shader_parameter("mask1_scroll", Vector2.ZERO)
		m.set_shader_parameter("mask2_scroll", Vector2.ZERO)
		m.set_shader_parameter("mask2_blend_mode", 5)
		m.set_shader_parameter("use_mask3", false)
		m.set_shader_parameter("alpha_multiplier", .26)
		m.set_shader_parameter("alpha_cutoff", .0)
		m.set_shader_parameter("proximity_fade", false)
		adapt(m, .80)
		m.set_shader_parameter("weather_mist", 1.)
		f.material_override = m
		mist_mats.append(m)
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	var q = QuadMesh.new()
	q.size = Vector2(.026, .30)
	mm.mesh = q
	mm.instance_count = 2400
	for i in range(mm.instance_count):
		var a = rng.randf() * TAU
		var r = sqrt(rng.randf()) * 8.0
		var v = rng.randf_range(.45, 1.50)
		mm.set_instance_transform(
			i,
			Transform3D(
				(Basis(Vector3.UP, PI / 4.) * Basis(Vector3.FORWARD, -.19)).scaled(
					Vector3(v, v, 1.)
				),
				Vector3(cos(a) * r, 0., sin(a) * r)
			)
		)
		mm.set_instance_custom_data(
			i, Color(rng.randf(), float(1 + rng.randi_range(0, 1)), rng.randf(), 1.)
		)
	var drops = MultiMeshInstance3D.new()
	drops.multimesh = mm
	drops.material_override = custom(
		VfxPackageIO_eeb1fa57d7.text("res://assets/vfx/sources/084590015b416f34e178/sleet_storm_rain.gdshader")
	)
	assembly.add_child(drops)


func ground() -> void:
	var p = PlaneMesh.new()
	p.size = Vector2(16., 16.)
	var f = MeshInstance3D.new()
	f.mesh = p
	f.position.y = .008
	assembly.add_child(f)
	var m = custom(
		VfxPackageIO_eeb1fa57d7.text("res://assets/vfx/sources/97d7a006f6069a9bc4f3/sleet_storm_floor.gdshader")
	)
	(
		m
		. set_shader_parameter(
			"frost",
			VfxPackageIO_eeb1fa57d7.resource(
				"res://assets/vfx/sources/9fb69ffb13aabda6ae8d/texture.res"
			)
		)
	)
	m.set_shader_parameter(
		"noise_tex",
		VfxPackageIO_eeb1fa57d7.resource(
			"res://assets/vfx/sources/900721c102c94ad02849/texture.res"
		)
	)
	f.material_override = m


func advance_lifecycle(_delta: float) -> void:
	if assembly == null:
		return
	tick += 1
	var age = float(tick) / 144.
	var clock = float(tick % 288) / 144.
	for m in mats:
		m.set_shader_parameter("weather_clock", clock)
		m.set_shader_parameter("weather_age", age)
	for i in range(mist_mats.size()):
		var m = mist_mats[i]
		var a = clock * PI + float(i) * 2.399963
		m.set_shader_parameter("mask1_scroll", Vector2.ZERO)
		# Periodic source UV offsets preserve natural evolution across the two-second seam.
		m.set_shader_parameter("mask1_rotation", 0.)
		m.set_shader_parameter(
			"mask1_scale", Vector2(2.0 + .08 * sin(a + float(i)), 1.6 + .08 * cos(a))
		)
		m.set_shader_parameter(
			"mask2_scale", Vector2(1.4 + .09 * cos(a), 1.9 + .09 * sin(a + float(i)))
		)

const VfxPackageIO_eeb1fa57d7 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
