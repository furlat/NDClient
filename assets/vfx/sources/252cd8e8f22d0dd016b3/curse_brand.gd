extends "res://assets/vfx/sources/a4fd0883f0b17d893a03/base.gd"
## Accepted native curse geometry and lifecycle. Variant glyphs and donor choices are data.
const SourceMaterials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
const CurseFinish = preload("res://assets/vfx/sources/68c612e2b1c79af74401/curse_rings.gd")


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/252cd8e8f22d0dd016b3/curse_brand.gd", input)


func prepare_materials(_node: Node) -> void:
	pass


var aura: Node3D
var shadow: Node3D
var seal: Node3D
var pieces: Array[Node3D] = []
var ash: Array[MeshInstance3D] = []
var folds: Array[MeshInstance3D] = []
var curse_wisps: Array[MeshInstance3D] = []
var head_mark_height = 2.25
var receiving_surface: Dictionary = {}


func set_live_endpoints(value: Array) -> void:
	receiving_surface = {}
	for endpoint in value:
		var surface: Dictionary = endpoint.get("surface", {})
		if surface.get("actor", "") == settings.get("receiving_actor", "") and not surface.get("points", []).is_empty():
			receiving_surface = surface
			return


func update_geometry() -> void:
	if not settings.get("native_curse_finish", false) or not is_instance_valid(seal):
		return
	if receiving_surface.is_empty():
		seal.hide()
		for puff in curse_wisps:
			puff.hide()
		return
	var top := -INF
	for point in receiving_surface.points:
		top = maxf(top, subject.to_local(point.position).y)
	# Original .20 head clearance plus half the original .66 glyph height.
	# The actual current painted head/helmet replaces the fixture's fixed headTop.
	head_mark_height = top + .20 + .33
	seal.show()
	for puff in curse_wisps:
		puff.show()
	_place_mark(float(tick) / float(parameters.simulation_hz))


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
	aura = DonorScene.instantiate(VfxPackageIO_252cd8e8f2.resource(settings.aura_scene), [])
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
		shadow = DonorScene.instantiate(VfxPackageIO_252cd8e8f2.resource(settings.shadow_scene), [])
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
		# Above headwear in world Y. Camera-relative screen offsets are not height.
		head_mark_height = float(settings.get("headTop", 1.72)) + .20 + .33
		seal = Node3D.new()
		node.add_child(seal)
		seal.position.y = head_mark_height
		var texture_noise = SourceMaterials.raw_texture(settings.smoke_texture)
		var glyph = MeshInstance3D.new()
		glyph.name = "CurseChoice" + str(settings.curseOption)
		var plane = QuadMesh.new()
		plane.size = Vector2(.66, .66)
		glyph.mesh = plane
		seal.add_child(glyph)
		var distances = "float d=100.0;\n"
		for s in settings.glyphSegments:
			distances += "d=min(d,stroke(p,vec2(%s,%s),vec2(%s,%s)));\n" % [s[0], s[1], s[2], s[3]]
		var glyph_shader = Shader.new()
		glyph_shader.code = BRAND.replace("// DISTANCES", distances)
		var gm = ShaderMaterial.new()
		gm.shader = glyph_shader
		gm.set_shader_parameter("mark_noise", texture_noise)
		adapt_shader(gm)
		glyph.material_override = gm
		# Bane v17's actual LeLu mesh, UVs and dissolve shader; original Bane unchanged.
		var triangles = JSON.parse_string(VfxPackageIO_252cd8e8f2.text(settings.smoke_geometry))
		var surface = SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for p in triangles:
			surface.set_uv(Vector2(p[3], 1. - p[4]))
			surface.add_vertex(Vector3(p[0], p[1], p[2]))
		var smoke_mesh = surface.commit()
		for i in range(2):
			var puff = MeshInstance3D.new()
			puff.mesh = smoke_mesh
			puff.name = "BaneDerivedWisp" + str(i)
			node.add_child(puff)
			var pm = ShaderMaterial.new()
			var ps = Shader.new()
			ps.code = WISP
			pm.shader = ps
			pm.set_shader_parameter("curse_noise", texture_noise)
			adapt_shader(pm)
			puff.material_override = pm
			curse_wisps.append(puff)
		aura.visible = false


func line(parent: Node3D, a: Vector3, b: Vector3, radius: float, energy: float = .73) -> void:
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
	m.set_shader_parameter("stroke_energy", energy)
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
	_place_mark(age)


func _place_mark(age: float) -> void:
	if seal:
		var phase = age * TAU / 2.
		var departure = .14 * smoothstep(.10, .85, age) if settings.curseMode == "release" else 0.
		seal.position = Vector3(
			.025 * sin(phase), head_mark_height + .015 * cos(phase) + departure, .025 * cos(phase)
		)
		for i in range(curse_wisps.size()):
			var life = fposmod(age + float(i), 2.) / 2.
			var puff = curse_wisps[i]
			var q = int(settings.cameraQuarter)
			var sx = [1., 1., -1., -1.][q]
			var sz = [1., -1., -1., 1.][q]
			var camera_right = Vector3(sz * .70710678, 0., -sx * .70710678)
			var camera_toward = Vector3(sx * .70710678, 0., sz * .70710678)
			if settings.get("native_curse_finish", false):
				var camera: Camera3D = get_viewport().get_camera_3d()
				if camera != null:
					camera_right = subject.global_basis.inverse() * camera.global_basis.x
					camera_toward = subject.global_basis.inverse() * Vector3(camera.global_basis.z.x, 0., camera.global_basis.z.z).normalized()
			puff.position = (
				camera_right * (-.40 if i == 0 else .40)
				- camera_toward * .12
				+ Vector3(0., head_mark_height - .04 + life * .22 + departure, 0.)
			)
			puff.scale = Vector3(
				lerpf(.045, .07, life), lerpf(.065, .11, life), lerpf(.04, .06, life)
			)
			puff.rotation = Vector3(.2 * float(i), .4 * float(i) + life * .2, 0.)
			puff.material_override.set_shader_parameter("puff_life", life)


const CONVERGENCE = """shader_type spatial;render_mode unshaded,cull_disabled;varying vec3 local_position;void vertex(){local_position=VERTEX;}void fragment(){float stroke=sin(atan(local_position.z,local_position.x)*8.-TIME*5.);ALBEDO=vec3(.42+.15*smoothstep(.1,.9,stroke));EMISSION=vec3(.015);ALPHA=.85*(1.-smoothstep(.6,.85,TIME));}"""
const SEAL = """shader_type spatial;render_mode unshaded,cull_disabled;
uniform float stroke_energy=.73;varying vec3 local_position;void vertex(){local_position=VERTEX;}
void fragment(){float path=sin(local_position.y*27.-TIME*3.14159265);float glow=stroke_energy+.06*smoothstep(.55,.85,path);ALBEDO=vec3(glow);EMISSION=vec3(.05);ALPHA=.95;}
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


const BRAND = """shader_type spatial;render_mode unshaded,cull_disabled;
uniform sampler2D mark_noise;
float stroke(vec2 p,vec2 a,vec2 b){vec2 v=b-a;return length(p-a-v*clamp(dot(p-a,v)/dot(v,v),0.,1.));}
void vertex(){MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0],INV_VIEW_MATRIX[1],INV_VIEW_MATRIX[2],MODEL_MATRIX[3]);}
void fragment(){vec2 p=(UV-vec2(.5))*vec2(1.,-1.);
// DISTANCES
float core=1.-smoothstep(.022,.031,d);float rim=1.-smoothstep(.036,.043,d);
float n=texture(mark_noise,UV*1.5+vec2(TIME/2.,-TIME/2.)).r;
float edge_light=smoothstep(.62,.90,n)*.10;
ALBEDO=vec3(mix(.13,.57+edge_light,core))*mix(.65,1.,smoothstep(.2,.8,n));ALPHA=rim;
}"""
const WISP = """shader_type spatial;render_mode unshaded,cull_disabled;
uniform sampler2D curse_noise;uniform float puff_life=0.;
void fragment(){float coarse=texture(curse_noise,UV*1.15+vec2(TIME*.07,-TIME*.045)).r;
float detail=texture(curse_noise,UV*2.7+vec2(-TIME*.12,TIME*.09)).r;
float threshold=mix(.30,.94,puff_life);float body=smoothstep(threshold-.07,threshold+.10,coarse);
body*=smoothstep(.18,.64,detail);float edge=(1.-smoothstep(.035,.10,abs(coarse-threshold)))*body;
float contrast=pow(clamp(detail*1.1,0.,1.),1.8);
ALBEDO=vec3(mix(.12,.52,clamp(edge*.70+contrast*.26,0.,1.)));
ALPHA=body*.34*smoothstep(0.,.08,puff_life)*(1.-smoothstep(.58,1.,puff_life));
}"""

const VfxPackageIO_252cd8e8f2 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
