extends "res://assets/vfx/sources/a4fd0883f0b17d893a03/base.gd"
## Accepted native curse geometry and lifecycle. Variant glyphs and donor choices are data.
const SourceMaterials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
const CurseFinish = preload("res://assets/vfx/sources/68c612e2b1c79af74401/curse_rings.gd")


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/fa9dad58889076b2bc78/curse_application.gd", input)


func prepare_materials(_node: Node) -> void:
	pass


var aura: Node3D
var shadow: Node3D
var seal: Node3D
var pieces: Array[Node3D] = []
var ash: Array[MeshInstance3D] = []
var folds: Array[MeshInstance3D] = []
var receiving_surface: Dictionary = {}


func set_live_endpoints(value: Array) -> void:
	receiving_surface = {}
	for endpoint in value:
		var surface: Dictionary = endpoint.get("surface", {})
		if surface.get("actor", "") == settings.get("receiving_actor", "") and not surface.get("points", []).is_empty():
			receiving_surface = surface
			return


func update_geometry() -> void:
	if not settings.get("native_curse_finish", false):
		return
	if receiving_surface.is_empty():
		subject.hide()
		return
	var top := -INF
	for point in receiving_surface.points:
		# Measure in the occurrence frame, before the fitted subject scale.
		# Repeated current-pose updates must not divide by the previous fit.
		top = maxf(top, to_local(point.position).y)
	var reference_top := float(settings.receiving_reference_top_cells)
	assert(reference_top > 0.0, "Curse application requires its original proxy height")
	subject.scale = Vector3.ONE * top / reference_top
	subject.show()


func recolor(r: Resource) -> void:
	if not r or visited.has(r.get_instance_id()):
		return
	visited[r.get_instance_id()] = true
	for p in r.get_property_list():
		if not (int(p.usage) & PROPERTY_USAGE_STORAGE):
			continue
		var v = r.get(p.name)
		if v is Color:
			r.set(p.name, Color(v.v, v.v, v.v, v.a))
		elif v is Resource:
			recolor(v)
		elif v is PackedColorArray:
			var values = PackedColorArray()
			for c in v:
				values.append(Color(c.v, c.v, c.v, c.a))
			r.set(p.name, values)
	if r is Mesh:
		for i in r.get_surface_count():
			recolor(r.surface_get_material(i))
	if r is ShaderMaterial:
		adapt_shader(r)


func prepare_curse(root: Node) -> void:
	for c in [root] + root.find_children("*", "", true, false):
		if c is AnimationPlayer:
			c.stop()
		if c is GPUParticles3D:
			c.fixed_fps = 144
			c.use_fixed_seed = true
			c.seed = 73217
			c.process_material = c.process_material.duplicate(true)
		for p in c.get_property_list():
			if int(p.usage) & PROPERTY_USAGE_STORAGE and c.get(p.name) is Resource:
				recolor(c.get(p.name))


func apply_scene_edits(node: Node) -> void:
	var mode = settings.curseMode
	aura = DonorScene.instantiate(VfxPackageIO_fa9dad5888.resource(settings.aura_scene), [])
	ResourceGraph.isolate_node(aura, {})
	node.add_child(aura)
	aura.set_process(false)
	aura.set_physics_process(false)
	aura.get_node("Mesh").visible = false
	aura.position.y = 1.15
	aura.scale = Vector3.ONE * .48
	prepare_curse(aura)
	for m in materials:
		m.set_shader_parameter("primary_color", Vector3(.72, .72, .72))
		m.set_shader_parameter("secondary_color", Vector3(.30, .30, .30))
		m.set_shader_parameter("tertiary_color", Vector3(.12, .12, .12))
		m.set_shader_parameter("emission", 1.0)
		m.set_shader_parameter("hue_variation", 0.)
	for c in aura.find_children("*", "GPUParticles3D", true, false):
		c.amount = 10 if c.name == "Particles" else 6
		c.emitting = true
		c.preprocess = 1.4 if mode == "loop" else 0.
		c.process_material.emission_sphere_radius = .65
		c.process_material.initial_velocity_min *= .35
		c.process_material.initial_velocity_max *= .35
		c.restart()
	if mode in ["apply", "resisted"]:
		shadow = DonorScene.instantiate(VfxPackageIO_fa9dad5888.resource(settings.shadow_scene), [])
		ResourceGraph.isolate_node(shadow, {})
		node.add_child(shadow)
		shadow.position.y = .70
		shadow.scale = Vector3.ONE * (.10 if mode == "apply" else .075)
		prepare_curse(shadow)
		for p in shadow.find_children("*", "GPUParticles3D", true, false):
			p.amount = maxi(1, int(p.amount * .45))
			p.restart()
		shadow.get_node("streaks").visible = false
		shadow.get_node("trails_p").visible = false
		shadow.get_node("smokeball").visible = false
		shadow.get_node("sparks2_dynamic").visible = false
		var player = shadow.get_node("AnimationPlayer")
		player.clear_caches()
		player.play("Init")
	if mode == "apply":
		for i in range(3):
			var fold = MeshInstance3D.new()
			var ring = TorusMesh.new()
			ring.inner_radius = .50
			ring.outer_radius = .53
			ring.rings = 32
			ring.ring_segments = 6
			fold.mesh = ring
			node.add_child(fold)
			fold.position.y = .65 + float(i) * .23
			fold.rotation = Vector3(.12 * float(i - 1), 0, .15 * float(i - 1))
			var mat = ShaderMaterial.new()
			var sh = Shader.new()
			sh.code = CONVERGENCE
			mat.shader = sh
			adapt_shader(mat)
			fold.material_override = mat
			folds.append(fold)
	if mode == "touch":
		aura.position.y = 0.
		aura.scale = Vector3.ONE * .30
	if mode in ["loop", "release", "resisted"]:
		seal = Node3D.new()
		node.add_child(seal)
		var q = int(settings.cameraQuarter)
		var sx = [1., 1., -1., -1.][q]
		var sz = [1., -1., -1., 1.][q]
		seal.position = Vector3(sx * .25, .86, sz * .25)
		seal.look_at(
			seal.global_position + Vector3(12. * sx, 9.797958971, 12. * sz), Vector3.UP, true
		)
		for quadrant in range(4):
			var part = Node3D.new()
			seal.add_child(part)
			pieces.append(part)
			var angle = float(quadrant) * TAU / 4.
			var p0 = Vector3(cos(angle) * .23, sin(angle) * .23, 0.)
			var p1 = Vector3(cos(angle + TAU / 8.) * .23, sin(angle + TAU / 8.) * .23, 0.)
			var p2 = Vector3(cos(angle + TAU / 4.) * .23, sin(angle + TAU / 4.) * .23, 0.)
			line(part, p0.lerp(p1, .15), p1, .014)
			line(part, p1, p1.lerp(p2, .85), .014)
			line(part, p1 * .46, p1, .022)
			line(
				part,
				p1 * .46,
				p1 * .46 + Vector3(-sin(angle + TAU / 8.) * .085, cos(angle + TAU / 8.) * .085, 0),
				.018
			)
		line(seal, Vector3(0, -.16, 0), Vector3(0, .16, 0), .022)
		line(seal, Vector3(-.105, .065, 0), Vector3(.105, .065, 0), .022)
		line(seal, Vector3(-.085, -.045, 0), Vector3(.085, -.045, 0), .022)
		for i in range(12):
			var mote = MeshInstance3D.new()
			var mesh = SphereMesh.new()
			mesh.radius = .018
			mesh.height = .036
			mesh.radial_segments = 6
			mesh.rings = 3
			mote.mesh = mesh
			node.add_child(mote)
			var mat = ShaderMaterial.new()
			var sh = Shader.new()
			sh.code = STONE
			mat.shader = sh
			adapt_shader(mat)
			mote.material_override = mat
			ash.append(mote)


func line(parent: Node3D, a: Vector3, b: Vector3, radius: float) -> void:
	var outline = CylinderMesh.new()
	outline.top_radius = radius * 1.30
	outline.bottom_radius = radius * 1.30
	outline.height = a.distance_to(b)
	outline.radial_segments = 6
	var border = MeshInstance3D.new()
	border.mesh = outline
	parent.add_child(border)
	border.position = (a + b) * .5 - Vector3(0, 0, .018)
	border.quaternion = Quaternion(Vector3.UP, (b - a).normalized())
	var bm = ShaderMaterial.new()
	var bs = Shader.new()
	bs.code = "shader_type spatial;render_mode unshaded,cull_disabled;void fragment(){ALBEDO=vec3(.012);ALPHA=.98;}"
	bm.shader = bs
	adapt_shader(bm)
	border.material_override = bm
	var mesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = a.distance_to(b)
	mesh.radial_segments = 4
	var item = MeshInstance3D.new()
	item.mesh = mesh
	parent.add_child(item)
	item.position = (a + b) * .5
	item.quaternion = Quaternion(Vector3.UP, (b - a).normalized())
	var m = ShaderMaterial.new()
	var sh = Shader.new()
	sh.code = SEAL
	m.shader = sh
	adapt_shader(m)
	item.material_override = m


func advance_lifecycle(_dt: float) -> void:
	tick += 1
	var age = float(tick) / float(parameters.simulation_hz)
	var mode = settings.curseMode
	var env = 1.
	if mode == "touch":
		env = smoothstep(0., .16, age) * (1. - smoothstep(.68, 1.15, age))
	elif mode == "apply":
		env = smoothstep(0., .06, age) * (1. - smoothstep(1.15, 1.8, age))
	elif mode == "loop":
		env = smoothstep(0., .12, age)
	elif mode == "release":
		env = 1. - smoothstep(.20, 1.15, age)
	elif mode == "resisted":
		env = smoothstep(0., .08, age) * (1. - smoothstep(.25, .9, age))
	for mat in materials:
		mat.set_shader_parameter("support_clock", age)
		mat.set_shader_parameter("support_envelope", env)
	for i in range(folds.size()):
		var phase = smoothstep(.05, .72, age)
		folds[i].scale = Vector3.ONE * (1. - phase * .62)
		folds[i].rotation.y = age * .7 + float(i) * .5
	if seal:
		seal.rotation.z = .03 * sin(age * TAU / 2.)
		var opening = (
			.012 + .009 * sin(age * TAU / 2.) + .055 * (1. - smoothstep(.0, .45, age))
			if mode == "loop"
			else (
				.055 + .13 * smoothstep(.1, .8, age)
				if mode == "release"
				else .08 + .16 * smoothstep(.05, .65, age)
			)
		)
		for i in range(pieces.size()):
			var a = float(i) * TAU / 4. + TAU / 8.
			pieces[i].position = Vector3(cos(a), sin(a), 0) * opening
		for i in range(ash.size()):
			var a = float(i) * 2.399963 + age * TAU / 2.
			var radius = .38 + .09 * sin(age * TAU / 2. + float(i))
			var spread = .4 * smoothstep(.1, 1., age) if mode == "release" else 0.
			ash[i].position = Vector3(
				sin(a) * (radius + spread),
				.78 + float(i % 4) * .24 + .06 * sin(a * 2.),
				cos(a) * (radius + spread)
			)
			ash[i].scale = Vector3.ONE * (.65 + .25 * sin(a))


const CONVERGENCE = """shader_type spatial;render_mode unshaded,cull_disabled;varying vec3 local_position;void vertex(){local_position=VERTEX;}void fragment(){float stroke=sin(atan(local_position.z,local_position.x)*8.-TIME*5.);ALBEDO=vec3(.42+.15*smoothstep(.1,.9,stroke));EMISSION=vec3(.015);ALPHA=.85*(1.-smoothstep(.6,.85,TIME));}"""
const SEAL = """shader_type spatial;render_mode unshaded,cull_disabled;
varying vec3 local_position;void vertex(){local_position=VERTEX;}
void fragment(){float path=sin(local_position.y*27.-TIME*3.14159265);float glow=.78+.12*smoothstep(.55,.85,path);ALBEDO=vec3(glow);EMISSION=vec3(.05);ALPHA=.95;}
"""
const STONE = """shader_type spatial;render_mode unshaded,cull_disabled;
void fragment(){ALBEDO=vec3(.52);ALPHA=.85;}
"""


func adapt_shader(mat: ShaderMaterial) -> void:
	var shader = Shader.new()
	var code: String = SourceMaterials.expand_shader(
		mat.shader.code, mat.shader.resource_path.get_base_dir()
	)
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
		var correction = "ALBEDO*=.18; EMISSION*=.18;" if settings.curseMode == "apply" else ""
		code = code.insert(end - 1, "\n" + correction + "\nALPHA *= support_envelope;\n")
	code = code.replace("vec3(0.70710678,0.0,0.70710678)", settings.clip_vector)
	shader.code = code
	if settings.get("native_curse_finish", false):
		SourceMaterials.replace_shader(mat, shader)
		CurseFinish.finish_material(mat, settings)
	else:
		mat.shader = shader
	materials.append(mat)

const VfxPackageIO_fa9dad5888 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
