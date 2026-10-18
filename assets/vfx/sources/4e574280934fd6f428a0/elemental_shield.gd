extends "res://assets/vfx/sources/a4fd0883f0b17d893a03/base.gd"
var mats: Array = []
var shell: ShaderMaterial
var root: Node3D
var palette = []


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/4e574280934fd6f428a0/elemental_shield.gd", input)


func prepare_materials(_node: Node) -> void:
	pass


func apply_scene_edits(node: Node) -> void:
	var cold = parameters.kind.begins_with("chill")
	palette = (
		["233c53", "356083", "518eaa", "7cbdcd", "b8d9df", "deebdf"]
		if cold
		else ["662718", "a73d1c", "db6722", "ef9834", "f1bd59", "f9dd91"]
	)
	root = Node3D.new()
	root.scale.y = .816496580927726
	node.add_child(root)
	var path = parameters.donors.shield
	if parameters.kind.ends_with("reaction"):
		path = parameters.donors.reaction
	if parameters.kind.ends_with("contact"):
		path = parameters.donors.contact
	var asset = VfxPackageIO_4e57428093.resource(path).instantiate()
	ResourceGraph.isolate_node(asset, {})
	root.add_child(asset)
	asset.position.y = .86
	asset.scale = Vector3(.68, .84, .68)
	if parameters.kind.ends_with("contact"):
		asset.scale = Vector3.ONE * .32
		asset.rotation.y = -PI / 2.
		asset.position.y = .70
	if parameters.kind.ends_with("reaction"):
		asset.scale = Vector3(.69, .85, .69)
	if asset is Node3D and asset.get_script() != null:
		asset.set_script(null)
	for child in (
		asset.find_children("*", "GeometryInstance3D", true, false)
		+ ([asset] if asset is GeometryInstance3D else [])
	):
		if str(child.name).contains("Distortion") or child.name == "GPUParticles3D":
			child.visible = false
			continue
		child.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if child is GPUParticles3D:
			child.fixed_fps = 144
			child.use_fixed_seed = true
			child.seed = 27493
			child.explosiveness = (
				1.0 if parameters.kind.ends_with("reaction") else child.explosiveness
			)
			child.emitting = true
			child.restart()
		if child.material_override is StandardMaterial3D:
			child.material_override = convert_standard(child.material_override)
		if child.material_override is ShaderMaterial:
			child.material_override = child.material_override.duplicate(true)
			adapt(child.material_override, cold)
			if child.name == "ShieldSphere_1":
				shell = child.material_override
				shell.set_shader_parameter("Size_Sphere", 0.)
	for a in asset.find_children("*", "AnimationPlayer", true, false):
		a.stop()
	# The professional impact scene starts its particles here; its light tracks stay disabled.
	for l in asset.find_children("*", "Light3D", true, false):
		l.visible = false


func ramp(cold: bool, line: bool = false) -> GradientTexture1D:
	var g = Gradient.new()
	g.offsets = PackedFloat32Array([0., .14, .35, .62, .85, 1.])
	g.colors = PackedColorArray(
		(
			[
				Color(.08, .21, .32, .05),
				Color(.14, .38, .55, .35),
				Color(.24, .57, .76, .6),
				Color(.58, .80, .89, .95),
				Color(.30, .66, .81, .8),
				Color(.82, .93, .95, 1.)
			]
			if cold
			else [
				Color(.25, .025, .009, .05),
				Color(.48, .065, .009, .30),
				Color(.86, .22, .018, .65),
				Color(1., .57, .075, .95),
				Color(.95, .35, .026, .8),
				Color(1., .85, .35, 1.)
			]
		)
	)
	var t = GradientTexture1D.new()
	t.gradient = g
	return t


func adapt(mat: ShaderMaterial, cold: bool) -> void:
	var original = mat.shader
	var params = {}
	var defaults = {}
	for u in original.get_shader_uniform_list():
		params[u.name] = mat.get_shader_parameter(u.name)
		if u.type == TYPE_OBJECT:
			var tex = original.get_default_texture_parameter(u.name)
			if tex != null:
				defaults[u.name] = tex
	var code = original.code.replace("shadow_to_opacity, ", "").replace("TIME", "fx_clock")
	code = code.replace(
		"shader_type spatial;",
		"shader_type spatial;uniform float fx_clock=0.;uniform float opacity=1.;"
	)
	var re = RegEx.new()
	re.compile("void\\s+fragment\\s*\\(\\s*\\)\\s*\\{")
	var f = re.search(code)
	if f:
		var at = f.get_end()
		var split = (
			"vec3 wp=(INV_VIEW_MATRIX*vec4(VERTEX,1.)).xyz;if((dot(wp-vec3(0.,.702187,0.),vec3(.6123724,.5,.6123724))>=0.)!="
			+ ("true" if (side == "front") else "false")
			+ ")discard;"
		)
		if parameters.kind.ends_with("contact"):
			split = split.replace(".702187", ".571548")
		if parameters.kind.ends_with("reaction"):
			split += "if(wp.x<.18 || abs(wp.z)>.50)discard;"
		code = code.insert(at, split)
		var depth = 1
		var end = at + split.length()
		while end < code.length() and depth > 0:
			if code[end] == "{":
				depth += 1
			elif code[end] == "}":
				depth -= 1
			end += 1
		# Preserve the donor's texture masks, fresnel, dissolution and particles; palette only changes hue.
		var tint = (
			"float v=max(ALBEDO.r,max(ALBEDO.g,ALBEDO.b));ALBEDO=mix(vec3(.025,.14,.35),vec3(.20,.57,.82),clamp(v,0.,1.));"
			if cold
			else "float v=max(ALBEDO.r,max(ALBEDO.g,ALBEDO.b));ALBEDO=mix(vec3(.48,.025,.003),vec3(.98,.28,.012),clamp(v,0.,1.));"
		)
		var cut = "ALPHA*=smoothstep(.018,.08,v);" if parameters.kind.ends_with("contact") else ""
		var boost = "ALPHA=min(1.,ALPHA*3.);" if parameters.kind.ends_with("reaction") else ""
		code = code.insert(end - 1, tint + cut + boost + "ALPHA*=opacity;")
	var sh = Shader.new()
	sh.code = code
	mat.shader = sh
	for k in params:
		if params[k] != null:
			mat.set_shader_parameter(k, params[k])
	for k in defaults:
		if mat.get_shader_parameter(k) == null:
			mat.set_shader_parameter(k, defaults[k])
	for key in ["Gradient_1D_Color", "Line_Gradient", "Gradient_Color_1D"]:
		if params.has(key):
			mat.set_shader_parameter(key, ramp(cold, key == "Line_Gradient"))
	# Integer texture movement produces a continuous, exact two-second hold cycle.
	if params.has("Overlay_Velocity"):
		mat.set_shader_parameter("Overlay_Velocity", Vector2(.5, .5))
	mats.append(mat)


func advance_lifecycle(_d: float) -> void:
	if root == null:
		return
	tick += 1
	var age = float(tick) / 144.
	var env = smoothstep(0., .18, age) * (1. - smoothstep(3., 4., age))
	if parameters.kind.ends_with("contact") or parameters.kind.ends_with("reaction"):
		env = 1. - smoothstep(.65, 1., age)
	for m in mats:
		m.set_shader_parameter("fx_clock", fmod(age, 2.))
		m.set_shader_parameter("opacity", env)
	if shell:
		shell.set_shader_parameter(
			"Gradient_Line",
			lerpf(-.005, .84, smoothstep(0., .60, age)) * (1. - smoothstep(3., 4., age))
		)


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

const VfxPackageIO_4e57428093 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
