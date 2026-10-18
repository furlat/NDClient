extends "res://assets/vfx/sources/a4fd0883f0b17d893a03/base.gd"
## Native source authoring; shared stage, process clock, palette and capture.
const SourceMaterials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/eccdd7fc27b746bb3958/compact_flame.gd", input)


func prepare_materials(_node: Node) -> void:
	pass


var root: Node3D
var asset: Node3D
var mats: Array = []
var seen = {}
var palette = ["662718", "a73d1c", "db6722", "ef9834", "f1bd59", "f9dd91"]


func apply_scene_edits(node: Node) -> void:
	root = Node3D.new()
	root.scale.y = .816496580927726
	node.add_child(root)
	var path = (
		"res://assets/vfx/sources/4896594714cd8d777830/VFX_FireProjectile_Red_C.tscn"
		if settings.kind != "produce-hit"
		else "res://assets/vfx/sources/0cb53083431ed3458839/VFX_FireHit_Red.tscn"
	)
	asset = VfxPackageIO_eccdd7fc27.resource(path).instantiate()
	root.add_child(asset)
	asset.scale = Vector3.ONE * (.32 if settings.kind != "produce-hit" else .035)
	if settings.kind != "produce-hit":
		asset.rotation.y = -PI / 2.
		asset.position = Vector3(.55, .9, -.1)
		asset.get_node("FireTorch_AC8").position = Vector3.ZERO
		var trail = asset.get_node("GPUTrail3D")
		trail.length_seconds = .035
		trail.length = 8
		var sparks = asset.get_node("smallparticles_constant8")
		sparks.amount = 9
		sparks.lifetime = .10
	else:
		asset.position = Vector3(0., .85, 0.)
	if settings.kind == "produce":
		asset.position = Vector3.ZERO
		asset.get_node("GPUTrail3D").visible = false
		asset.get_node("smallparticles_constant8").visible = false
	for child in asset.find_children("*", "GeometryInstance3D", true, false):
		child.layers = 1
		child.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if child is GPUParticles3D:
			child.fixed_fps = 144
			child.use_fixed_seed = true
			child.seed = 72273
			if settings.kind == "produce-hit":
				child.local_coords = true
				child.emitting = true
				child.restart()
			if child.process_material is ParticleProcessMaterial:
				child.process_material = child.process_material.duplicate(true)
				recolor(child.process_material)
		if child.material_override is ShaderMaterial:
			child.material_override = child.material_override.duplicate(true)
			adapt(child.material_override)
		if child is GPUParticles3D:
			for i in range(child.draw_passes):
				var mesh = child.get("draw_pass_" + str(i + 1))
				if mesh:
					mesh = mesh.duplicate(true)
					child.set("draw_pass_" + str(i + 1), mesh)
					for j in range(mesh.get_surface_count()):
						var mat = mesh.surface_get_material(j)
						if mat is ShaderMaterial:
							adapt(mat)
	for l in asset.find_children("*", "Light3D", true, false):
		l.visible = false
	for ap in asset.find_children("*", "AnimationPlayer", true, false):
		ap.stop()


func tint(c: Color) -> Color:
	return Color.from_hsv(.035, c.s, c.v, c.a) if c.s > .08 else c


func recolor(r: Resource) -> void:
	if r == null or seen.has(r.get_instance_id()):
		return
	seen[r.get_instance_id()] = true
	for p in r.get_property_list():
		if not (int(p.usage) & PROPERTY_USAGE_STORAGE):
			continue
		var v = r.get(p.name)
		if v is Color:
			r.set(p.name, tint(v))
		elif v is PackedColorArray:
			var a = PackedColorArray()
			for c in v:
				a.append(tint(c))
			r.set(p.name, a)
		elif v is Resource:
			recolor(v)


func adapt(mat: ShaderMaterial) -> void:
	if mats.has(mat):
		return
	recolor(mat)
	var original = mat.shader
	var params = {}
	var defaults = {}
	for u in original.get_shader_uniform_list():
		params[u.name] = mat.get_shader_parameter(u.name)
		if u.type == TYPE_OBJECT:
			var tex = original.get_default_texture_parameter(u.name)
			if tex != null:
				defaults[u.name] = tex
	var code = (
		original
		. code
		. replace("TIME", "fx_clock")
		. replace(
			"shader_type spatial;",
			"shader_type spatial;uniform float fx_clock=0.;uniform float opacity=1.;uniform float split_center=.45;"
		)
	)
	var re = RegEx.new()
	re.compile("void\\s+fragment\\s*\\(\\s*\\)\\s*\\{")
	var f = re.search(code)
	if f:
		var at = f.get_end()
		var split = (
			"vec3 wp=(INV_VIEW_MATRIX*vec4(VERTEX,1.)).xyz;if((wp.x+wp.z-split_center>=0.)!="
			+ ("true" if (side == "front") else "false")
			+ ")discard;"
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
		code = code.insert(
			end - 1, "ALPHA*=opacity*smoothstep(.008,.04,max(ALBEDO.r,max(ALBEDO.g,ALBEDO.b)));"
		)
	var sh = Shader.new()
	sh.code = code
	mat.shader = sh
	for k in params:
		if params[k] != null:
			mat.set_shader_parameter(k, params[k])
	for k in defaults:
		if mat.get_shader_parameter(k) == null:
			mat.set_shader_parameter(k, defaults[k])
	for k in ["Use_Proximity_Fade", "Enable_Proximity_Fade", "proximity_fade"]:
		mat.set_shader_parameter(k, false)
	mats.append(mat)


func advance_lifecycle(_delta: float) -> void:
	if asset == null:
		return
	tick += 1
	var age = float(tick) / float(parameters.simulation_hz)
	var center = 0.
	var fade = 1. - smoothstep(.15, .40, age)
	var clock = age
	if settings.kind == "produce":
		fade = smoothstep(0., 1., age) * (1. - smoothstep(3., 4., age))
		clock = fposmod(age - 1., 2.) if age >= 1. else age
	elif settings.kind != "produce-hit":
		var f = minf(age / .45, 1.)
		var z = lerpf(-.1, .65, f) if settings.kind == "produce-miss" else -.1
		asset.position = Vector3(lerpf(.55, 4.2, f), .9, z)
		center = asset.position.x + asset.position.z
		if age >= .45:
			asset.get_node("FireTorch_AC8").visible = false
			asset.get_node("smallparticles_constant8").emitting = false
		fade = 1. - smoothstep(.45, .70, age)
	if settings.kind == "produce-hit":
		for child in asset.find_children("*", "GeometryInstance3D", true, false):
			child.transparency = 1. - fade
	for mat in mats:
		mat.set_shader_parameter("fx_clock", clock)
		mat.set_shader_parameter("opacity", fade)
		mat.set_shader_parameter("split_center", center)
	if (
		age
		>= (4. if settings.kind == "produce" else .40 if settings.kind == "produce-hit" else .95)
	):
		asset.visible = false

const VfxPackageIO_eccdd7fc27 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
