extends "res://assets/vfx/sources/a4fd0883f0b17d893a03/base.gd"
## Native source authoring; shared stage, process clock, palette and capture.
const SourceMaterials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/fe6a0d81ec5daed7ad4a/force_construction.gd", input)


func prepare_materials(_node: Node) -> void:
	pass


const CELL = 2.121320344
const RADIUS = CELL * 2.0
const HEIGHT = CELL * 2.0
const LENGTH = CELL * 6.0
var camera_sign = Vector2(1, 1)
var surface: ArrayMesh
var points = PackedVector3Array()
var uvs = PackedVector2Array()
var indices = PackedInt32Array()
var links: Array[PackedInt32Array] = []
var weights: Array[PackedFloat32Array] = []
var field = PackedFloat32Array()
var velocity = PackedFloat32Array()
var next_velocity = PackedFloat32Array()
var force_material: ShaderMaterial
var collider: StaticBody3D
var shot: CharacterBody3D
var shot_art: MeshInstance3D
var contact_tick = -1
var contact = Vector3.ZERO
var ray_start = Vector3.ZERO
var ray_end = Vector3.ZERO
var beam: MeshInstance3D
var beam_material: ShaderMaterial
var charge: MeshInstance3D
var burst: MeshInstance3D
var charge_material: ShaderMaterial
var burst_material: ShaderMaterial
var motes: Array[MeshInstance3D] = []
var mote_origins: Array[Vector3] = []
var mote_velocities: Array[Vector3] = []
var mote_material: ShaderMaterial
var impact_mote_material: ShaderMaterial
var beam_corona: MeshInstance3D
var corona_material: ShaderMaterial
var flight_material: ShaderMaterial
var flight_sparks: Array[MeshInstance3D] = []
var flight_velocities: Array[Vector3] = []
var event_report = []
var ice_bodies: Array[RigidBody3D] = []
var ice_material: ShaderMaterial
var ice_broken = false
var ice_whole: MeshInstance3D
var ice_air: MeshInstance3D
var ice_air_material: ShaderMaterial
var ice_flakes: Array[MeshInstance3D] = []
var physics_frames = []
var surface_field_snapshot:=PackedFloat32Array()
var surface_field_known:=false
var ice_flake_materials: Array[ShaderMaterial] = []


func apply_scene_edits(node: Node) -> void:
	subject = node
	for child in node.get_children():
		node.remove_child(child)
		child.free()
	node.scale = Vector3.ONE
	node.position = Vector3.ZERO
	if settings.shape == "panels":
		make_panels()
	elif settings.shape in ["dome", "ice-dome"]:
		make_dome()
	field.resize(points.size())
	field.fill(0)
	velocity.resize(points.size())
	velocity.fill(0)
	next_velocity.resize(points.size())
	next_velocity.fill(0)
	if settings.shape != "creature":
		force_material = force_material_source()
		surface = ArrayMesh.new()
		var visual = MeshInstance3D.new()
		visual.mesh = surface
		visual.material_override = force_material
		node.add_child(visual)
		visual.visible = side != "spell" and settings.shape != "ice-dome"
		update_surface()
		collider = StaticBody3D.new()
		node.add_child(collider)
		var cs = CollisionShape3D.new()
		collider.add_child(cs)
		if settings.shape == "panels":
			var box = BoxShape3D.new()
			box.size = Vector3(LENGTH, HEIGHT, CELL / 240.0)
			cs.shape = box
			cs.position = Vector3(0, HEIGHT * .5, CELL * .5)
		else:
			var sphere = SphereShape3D.new()
			sphere.radius = RADIUS
			cs.shape = sphere
		shot = CharacterBody3D.new()
		node.add_child(shot)
		shot.collision_layer = 2
		shot.collision_mask = 1
		shot.safe_margin = .0001
		var ss = CollisionShape3D.new()
		var ball = SphereShape3D.new()
		ball.radius = .018
		ss.shape = ball
		shot.add_child(ss)
		shot.position = Vector3(0, 1.3, CELL * (4.0 if settings.shape == "dome" else 2.0))
		shot_art = MeshInstance3D.new()
		var arrow = PrismMesh.new()
		arrow.size = Vector3(.07, .07, .48)
		shot_art.mesh = arrow
		shot_art.material_override = flat_material(Vector3(.53, .39, .2))
		shot.add_child(shot_art)
		shot_art.visible = false
		if settings.shape == "ice-dome":
			make_ice_shell()
	ray_end = (
		Vector3(0, 1.8, CELL * .5 + CELL / 480.0)
		if settings.shape == "panels"
		else (
			Vector3(0, 1.8, sqrt(RADIUS * RADIUS - 1.8 * 1.8))
			if settings.shape == "dome"
			else Vector3(0, 1.5, 0)
		)
	)
	ray_start = ray_end + Vector3(0, -.30, CELL * 2)
	make_disintegrate()


func flat_material(color: Vector3) -> ShaderMaterial:
	var m = ShaderMaterial.new()
	var s = Shader.new()
	s.code = "shader_type spatial;render_mode unshaded,cull_disabled;uniform vec3 tint;void fragment(){ALBEDO=tint;}"
	m.shader = s
	m.set_shader_parameter("tint", color)
	return m


func make_panels() -> void:
	const NX = 96
	const NY = 32
	for y in range(NY + 1):
		for x in range(NX + 1):
			points.append(Vector3((float(x) / NX - .5) * LENGTH, float(y) / NY * HEIGHT, CELL * .5))
			uvs.append(Vector2(float(x) / NX * 3.0, 1.0 - float(y) / NY))
			var near = PackedInt32Array()
			var ws = PackedFloat32Array()
			for d in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
				if x + d.x >= 0 and x + d.x <= NX and y + d.y >= 0 and y + d.y <= NY:
					near.append((y + d.y) * (NX + 1) + x + d.x)
					ws.append(1.0 / pow(LENGTH / NX if d.x else HEIGHT / NY, 2.0))
			links.append(near)
			weights.append(ws)
	for y in range(NY):
		for x in range(NX):
			var a = y * (NX + 1) + x
			indices.append_array(
				PackedInt32Array([a, a + 1, a + NX + 1, a + 1, a + NX + 2, a + NX + 1])
			)


func midpoint(a: int, b: int, cache: Dictionary) -> int:
	var key = Vector2i(min(a, b), max(a, b))
	if cache.has(key):
		return cache[key]
	var id = points.size()
	points.append((points[a] + points[b]).normalized())
	cache[key] = id
	return id


func make_dome() -> void:
	var g = (1.0 + sqrt(5.0)) / 2.0
	points = PackedVector3Array(
		[
			Vector3(-1, g, 0),
			Vector3(1, g, 0),
			Vector3(-1, -g, 0),
			Vector3(1, -g, 0),
			Vector3(0, -1, g),
			Vector3(0, 1, g),
			Vector3(0, -1, -g),
			Vector3(0, 1, -g),
			Vector3(g, 0, -1),
			Vector3(g, 0, 1),
			Vector3(-g, 0, -1),
			Vector3(-g, 0, 1)
		]
	)
	for i in range(points.size()):
		points[i] = points[i].normalized()
	var tris = [
		Vector3i(0, 11, 5),
		Vector3i(0, 5, 1),
		Vector3i(0, 1, 7),
		Vector3i(0, 7, 10),
		Vector3i(0, 10, 11),
		Vector3i(1, 5, 9),
		Vector3i(5, 11, 4),
		Vector3i(11, 10, 2),
		Vector3i(10, 7, 6),
		Vector3i(7, 1, 8),
		Vector3i(3, 9, 4),
		Vector3i(3, 4, 2),
		Vector3i(3, 2, 6),
		Vector3i(3, 6, 8),
		Vector3i(3, 8, 9),
		Vector3i(4, 9, 5),
		Vector3i(2, 4, 11),
		Vector3i(6, 2, 10),
		Vector3i(8, 6, 7),
		Vector3i(9, 8, 1)
	]
	for level in range(4):
		var result = []
		var cache = {}
		for t in tris:
			var a = midpoint(t.x, t.y, cache)
			var b = midpoint(t.y, t.z, cache)
			var c = midpoint(t.z, t.x, cache)
			result.append_array(
				[Vector3i(t.x, a, c), Vector3i(t.y, b, a), Vector3i(t.z, c, b), Vector3i(a, b, c)]
			)
		tris = result
	var adjacency = []
	for i in range(points.size()):
		adjacency.append({})
	for t in tris:
		indices.append_array(PackedInt32Array([t.x, t.y, t.z]))
		for edge in [Vector2i(t.x, t.y), Vector2i(t.y, t.z), Vector2i(t.z, t.x)]:
			adjacency[edge.x][edge.y] = true
			adjacency[edge.y][edge.x] = true
	for i in range(points.size()):
		points[i] *= RADIUS
		uvs.append(
			Vector2(
				atan2(points[i].z, points[i].x) / TAU + .5,
				acos(clampf(points[i].y / RADIUS, -1, 1)) / PI
			)
		)
	for i in range(points.size()):
		var ids = PackedInt32Array()
		var ws = PackedFloat32Array()
		for j in adjacency[i]:
			ids.append(j)
			ws.append(
				(
					4.0
					/ float(adjacency[i].size())
					/ max(.001, points[i].distance_squared_to(points[j]))
				)
			)
		links.append(ids)
		weights.append(ws)


func force_material_source() -> ShaderMaterial:
	var m = (
		(
			VfxPackageIO_fe6a0d81ec.resource(
				"res://assets/vfx/sources/5b5a61351d0f2a4281e3/m_basic_blueshield1.tres"
			)
			as ShaderMaterial
		)
		. duplicate(true)
	)
	var original = m.shader
	var defaults = {}
	for uniform in original.get_shader_uniform_list():
		var t = original.get_default_texture_parameter(uniform.name)
		if t != null:
			defaults[uniform.name] = t
	var shader = Shader.new()
	var code = (
		original
		. code
		. replace("shadow_to_opacity, ", "")
		. replace("depth_draw_opaque", "depth_draw_never")
		. replace("TIME", "vfx_clock")
	)
	code = (
		code
		. replace(
			"shader_type spatial;",
			"shader_type spatial;uniform float vfx_clock=0.0;uniform float age=0.0;uniform float opacity=1.0;uniform float destroy_age=-1.0;uniform vec3 impact;uniform vec2 camera_sign;uniform bool front=false;uniform bool dome=false;"
		)
	)
	code = (
		code
		. replace("n_out48p0 + n_out32p0", "n_out48p0 * 0.14 + n_out32p0")
		. replace("n_out84p0 + n_out13p0", "n_out13p0")
		. replace(
			"texture(Overlay_Texture, n_out46p0)", "texture(Overlay_Texture, fract(n_out46p0))"
		)
	)
	var start = code.find("void fragment()")
	var at = code.find("{", start) + 1
	code = (
		code
		. insert(
			at,
			"\nvec3 wp=(INV_VIEW_MATRIX*vec4(VERTEX,1.0)).xyz;if(wp.y<0.0)discard;bool nearest=dot(wp.xz,camera_sign)>0.0;if(nearest!=front)discard;\n"
		)
	)
	var last = code.rfind("}")
	var extra = """
	float growth=smoothstep(0.0,0.85,age);
	if(wp.y>growth*4.242640688)discard;
	float crest=exp(-pow((wp.y-growth*4.242640688)/.14,2.0))*(1.0-smoothstep(.65,.95,age));
	float rim=pow(1.0-abs(dot(NORMAL,VIEW)),2.0);
	float energy=smoothstep(.0008,.009,abs(COLOR.r));
	float distance_from_contact=length(wp-impact);
	float travel=max(0.0,destroy_age)*15.0;
	float dissolution=smoothstep(distance_from_contact*.035,distance_from_contact*.035+.5,destroy_age);
	float destabilize=exp(-pow((distance_from_contact-travel)/.45,2.0))*step(0.0,destroy_age);
	float line=clamp(n_out48p0,0.0,1.0);
	float border=dome?exp(-pow(wp.y/.05,2.0)):max(exp(-pow((abs(wp.x)-6.363961032)/.045,2.0)),max(exp(-pow(wp.y/.045,2.0)),exp(-pow((wp.y-4.242640688)/.045,2.0))));
	ALBEDO=mix(vec3(.07,.26,.49),vec3(.38,.67,1.0),max(max(line*.65,rim),border*.4));
	ALBEDO=mix(ALBEDO,vec3(.65,1.15,1.7),max(crest,max(energy,destabilize)));
	ALPHA=(.065+.12*line+.10*rim+.30*border+.60*crest+.75*energy+.45*destabilize)*opacity*growth*(1.0-dissolution);
	"""
	code = code.insert(last, extra)
	shader.code = code
	m.shader = shader
	for k in defaults:
		if m.get_shader_parameter(k) == null:
			m.set_shader_parameter(k, defaults[k])
	(
		m
		. set_shader_parameter(
			"Overlay_Texture",
			VfxPackageIO_fe6a0d81ec.resource(
				"res://assets/vfx/sources/929cd4ab89324bd78094/texture.res"
			)
		)
	)
	m.set_shader_parameter("Overlay_Scale", Vector2(2, 2))
	m.set_shader_parameter("Overlay_Velocity", Vector2(0, .015))
	m.set_shader_parameter("Gradient_Line", 1.0)
	m.set_shader_parameter("Proximity_light", 0.0)
	m.set_shader_parameter("camera_sign", camera_sign)
	m.set_shader_parameter("front", side == "front")
	m.set_shader_parameter("dome", settings.shape == "dome")
	m.set_shader_parameter(
		"impact", ray_end if ray_end != Vector3.ZERO else Vector3(0, 1.8, CELL * .5)
	)
	return m


func make_disintegrate() -> void:
	beam_material = ShaderMaterial.new()
	beam_material.shader = VfxPackageIO_fe6a0d81ec.resource(
		"res://assets/vfx/sources/b65d035ce244dd31146b/DisintegrateTrail.gdshader"
	)
	(
		beam_material
		. set_shader_parameter(
			"Texture2DParameter",
			(
				ImageTexture
				. create_from_image(
					(
						VfxPackageIO_fe6a0d81ec.image(
							(
								ProjectSettings
								. globalize_path(
									"res://assets/vfx/sources/d398229a9fe6541ac31f/texture.res"
								)
							)
						)
					)
				)
			)
		)
	)
	beam_material.set_shader_parameter("Scale", Vector2(1, 1))
	beam_material.set_shader_parameter("Trail_Speed", Vector2(-1.5, 0))
	beam_material.set_shader_parameter("vfx_clock", 0.0)
	beam_material.set_shader_parameter("opacity", 0.0)
	beam = MeshInstance3D.new()
	subject.add_child(beam)
	beam.mesh = ray_mesh()
	beam.material_override = beam_material
	charge_material = energy_material()
	burst_material = energy_material()
	mote_material = energy_material()
	impact_mote_material = energy_material()
	charge = MeshInstance3D.new()
	var s = SphereMesh.new()
	s.radius = .42
	s.height = .84
	s.radial_segments = 24
	s.rings = 12
	charge.mesh = s
	charge.position = ray_start
	charge.material_override = charge_material
	subject.add_child(charge)
	burst = MeshInstance3D.new()
	var b = SphereMesh.new()
	b.radius = .85
	b.height = 1.70
	b.radial_segments = 24
	b.rings = 12
	burst.mesh = b
	burst.position = ray_end
	burst.material_override = burst_material
	subject.add_child(burst)
	var rng = RandomNumberGenerator.new()
	rng.seed = 61461
	for i in range(120):
		var m = MeshInstance3D.new()
		var q = QuadMesh.new()
		q.size = Vector2(.065, .16) * (1.0 + float(i % 3) * .25)
		m.mesh = q
		m.material_override = impact_mote_material if i < 48 else mote_material
		subject.add_child(m)
		motes.append(m)
		var origin = (
			ray_end
			if i < 48
			else (
				points[rng.randi_range(0, points.size() - 1)]
				if points.size() > 0
				else ray_end + Vector3(rng.randf_range(-.4, .4), rng.randf_range(-1, 1), 0)
			)
		)
		origin.y = max(.02, origin.y)
		mote_origins.append(origin)
		mote_velocities.append(
			Vector3(rng.randf_range(-.9, .9), rng.randf_range(.1, 1.0), rng.randf_range(-.9, .9))
		)
	make_flight_energy()


func make_flight_energy() -> void:
	corona_material = energy_material()
	corona_material.shader = corona_material.shader.duplicate(true)
	corona_material.shader.code = corona_material.shader.code.replace(
		"ALPHA=(.14+.60*plume+.25*rim)*opacity;",
		"ALPHA=(.70*smoothstep(.40,.78,n)+.10*rim)*opacity;"
	)
	beam_corona = MeshInstance3D.new()
	beam_corona.mesh = ray_mesh()
	beam_corona.material_override = corona_material
	beam_corona.visible = false
	subject.add_child(beam_corona)
	flight_material = energy_material()
	var rng = RandomNumberGenerator.new()
	rng.seed = 319482
	for i in range(48):
		var m = MeshInstance3D.new()
		var q = QuadMesh.new()
		q.size = Vector2(.10, .30) * (1.0 + float(i % 4) * .2)
		m.mesh = q
		m.material_override = flight_material
		m.visible = false
		subject.add_child(m)
		flight_sparks.append(m)
		var a = rng.randf_range(0, TAU)
		flight_velocities.append(
			(
				Vector3(cos(a), sin(a), 0) * rng.randf_range(2.0, 4.5)
				+ (ray_end - ray_start).normalized() * rng.randf_range(1.5, 3.0)
			)
		)


func update_flight_energy(age: float, shown: bool) -> void:
	var head = clampf((age - 3.72) / .38, 0.0, 1.0)
	beam_corona.visible = shown and age >= 3.72 and age < 4.16
	if beam_corona.visible:
		beam_corona.mesh = ray_mesh(head, 1.8)
	corona_material.set_shader_parameter("age", age * 2.0)
	corona_material.set_shader_parameter(
		"opacity", .60 * smoothstep(3.72, 3.77, age) * (1.0 - smoothstep(4.08, 4.16, age))
	)
	flight_material.set_shader_parameter("age", age)
	flight_material.set_shader_parameter("opacity", .9)
	for i in range(flight_sparks.size()):
		var birth = 3.72 + float(i) / 48 * .38
		var elapsed = age - birth
		var m = flight_sparks[i]
		m.visible = shown and elapsed >= 0.0 and elapsed < .40
		if not m.visible:
			continue
		var origin = ray_start.lerp(ray_end, clampf((birth - 3.72) / .38, 0.0, 1.0))
		m.position = (
			origin + flight_velocities[i] * elapsed + Vector3(0, -.6 * elapsed * elapsed, 0)
		)
		var face = Vector3(camera_sign.x, .70710678, camera_sign.y).normalized()
		var right = flight_velocities[i].normalized().cross(face).normalized()
		var up = face.cross(right).normalized()
		m.basis = Basis(right, up, face).scaled(Vector3.ONE * (1.0 - smoothstep(.12, .40, elapsed)))


func energy_material() -> ShaderMaterial:
	var m = ShaderMaterial.new()
	var s = Shader.new()
	s.code = "shader_type spatial;render_mode unshaded,cull_disabled,depth_draw_never;uniform sampler2D noise_tex;uniform float age=0.0;uniform float opacity=0.0;uniform bool gold=false;void fragment(){float n=texture(noise_tex,UV*1.5+vec2(age*.14,-age*.18)).r;float rim=pow(1.0-abs(dot(NORMAL,VIEW)),2.0);float plume=smoothstep(.38,.62,n);ALBEDO=gold?mix(vec3(.08,.33,.64),vec3(.65,1.10,1.7),n):mix(vec3(.08,.36,.10),vec3(.55,1.45,.67),n);ALPHA=(.14+.60*plume+.25*rim)*opacity;}"
	m.shader = s
	(
		m
		. set_shader_parameter(
			"noise_tex",
			VfxPackageIO_fe6a0d81ec.resource(
				"res://assets/vfx/sources/9fb31deef39536e38753/texture.res"
			)
		)
	)
	return m


func ray_mesh(head: float = 0.0, width_scale: float = 1.0) -> ArrayMesh:
	var arr = []
	arr.resize(Mesh.ARRAY_MAX)
	var vertices = PackedVector3Array()
	var tex = PackedVector2Array()
	var idx = PackedInt32Array()
	var tail = maxf(0.0, head - .70)
	var count = 16
	for angle in [0.0, PI / 3.0, PI * 2.0 / 3.0]:
		var across = Vector3(cos(angle), sin(angle), 0)
		var k = vertices.size()
		for i in range(count + 1):
			var phase = float(i) / count
			var along = lerpf(tail, head, phase)
			# One connected tapered plasma body; an animated source texture gives it internal flow.
			var width = (
				.52
				* width_scale
				* pow(phase, .65)
				* pow(maxf(0.0, 1.0 - phase), .25)
				* minf(1.0, head / .14)
			)
			var centre = ray_start.lerp(ray_end, along)
			vertices.append_array(
				PackedVector3Array([centre - across * width, centre + across * width])
			)
			tex.append_array(PackedVector2Array([Vector2(phase, 0), Vector2(phase, 1)]))
		for i in range(count):
			var j = k + i * 2
			idx.append_array(PackedInt32Array([j, j + 1, j + 2, j + 1, j + 3, j + 2]))
	arr[Mesh.ARRAY_VERTEX] = vertices
	arr[Mesh.ARRAY_TEX_UV] = tex
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh


func _physics_process(delta: float) -> void:
	if (
		not is_instance_valid(subject)
		or settings.mode in ["loop", "air"]
		or settings.shape == "creature"
	):
		return
	var age = float(tick) / float(parameters.simulation_hz)
	if age >= 1.7 and contact_tick < 0:
		var hit = shot.move_and_collide(Vector3(0, 0, -12) * delta)
		if hit:
			contact_tick = tick
			contact = hit.get_position()
			for i in range(field.size()):
				velocity[i] += 1.2 * exp(-points[i].distance_squared_to(contact) / .08)
			var report = {
				"kind": "ordinary physical contact",
				"tick": tick,
				"position": [contact.x, contact.y, contact.z],
				"ordinaryDamageDestroys": false
			}
			event_report.append(report)
			print("FORCE_CONTACT ", JSON.stringify(report))
	for i in range(field.size()):
		var lap = 0.0
		for j in range(links[i].size()):
			lap += (field[links[i][j]] - field[i]) * weights[i][j]
		next_velocity[i] = velocity[i] + delta * (25.0 * lap - 4.0 * velocity[i] - 4.0 * field[i])
	for i in range(field.size()):
		velocity[i] = next_velocity[i]
		field[i] += velocity[i] * delta


func update_surface() -> void:
	# The source field is unchanged until an actual impulse/physics step. Keep
	# the exact vertex/UV/normal/colour buffer instead of rebuilding that hold.
	if surface_field_known and surface_field_snapshot==field:return
	surface_field_snapshot=field.duplicate()
	surface_field_known=true
	var arr = []
	arr.resize(Mesh.ARRAY_MAX)
	var displaced = PackedVector3Array()
	var colors = PackedColorArray()
	var normals = PackedVector3Array()
	for i in range(points.size()):
		var normal = (
			points[i].normalized() if settings.shape in ["dome", "ice-dome"] else Vector3(0, 0, 1)
		)
		displaced.append(points[i] + normal * clampf(field[i] * .2, -.015, .015))
		normals.append(normal)
		colors.append(Color(abs(field[i]), 0, 0, 1))
	arr[Mesh.ARRAY_VERTEX] = displaced
	arr[Mesh.ARRAY_NORMAL] = normals
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_COLOR] = colors
	arr[Mesh.ARRAY_INDEX] = indices
	surface.clear_surfaces()
	surface.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)


func advance_lifecycle(_delta: float) -> void:
	if not is_instance_valid(subject):
		return
	tick += 1
	var age = float(tick) / float(parameters.simulation_hz)
	if settings.shape == "ice-dome":
		update_flight_energy(age, false)
		update_ice(age)
		beam.visible = false
		charge.visible = false
		burst.visible = false
		for m in motes:
			m.visible = false
		if shot_art:
			shot_art.visible = side == "spell" and age >= 1.7 and contact_tick < 0
		return
	var disintegrate = 4.1
	var green_age = age - 3.2
	var collapse_age = age - disintegrate
	var show_spell = side == "spell" and settings.mode != "loop"
	if settings.shape != "creature":
		var hold = settings.mode == "loop"
		force_material.set_shader_parameter("age", 2.0 if hold else age)
		force_material.set_shader_parameter("vfx_clock", 0.0)
		force_material.set_shader_parameter(
			"opacity", .94 + .06 * cos(TAU * float(tick % 576) / 576.0)
		)
		force_material.set_shader_parameter("destroy_age", -1.0 if hold else collapse_age)
		force_material.set_shader_parameter("impact", ray_end)
		update_surface()
		shot_art.visible = show_spell and age >= 1.7 and contact_tick < 0
	update_flight_energy(age, show_spell)
	beam.visible = show_spell and age >= 3.72 and age < 4.16
	if beam.visible:
		beam.mesh = ray_mesh(clampf((age - 3.72) / .38, 0.0, 1.0))
	beam_material.set_shader_parameter(
		"opacity", smoothstep(3.72, 3.76, age) * (1.0 - smoothstep(4.10, 4.16, age))
	)
	beam_material.set_shader_parameter("vfx_clock", age * 1.3)
	charge.visible = show_spell and green_age >= 0 and age < 3.86
	charge.scale = Vector3.ONE * lerpf(.2, 1.0, smoothstep(0, .65, green_age))
	charge_material.set_shader_parameter("age", green_age)
	charge_material.set_shader_parameter(
		"opacity", smoothstep(0, .5, green_age) * (1.0 - smoothstep(3.72, 3.86, age))
	)
	burst.visible = show_spell and collapse_age >= 0 and collapse_age < .6
	burst.scale = Vector3.ONE * (.45 + max(0.0, collapse_age) * 1.6)
	burst_material.set_shader_parameter("age", collapse_age)
	burst_material.set_shader_parameter(
		"opacity", smoothstep(0, .04, collapse_age) * (1.0 - smoothstep(.22, .60, collapse_age))
	)
	impact_mote_material.set_shader_parameter("age", max(0.0, collapse_age))
	impact_mote_material.set_shader_parameter(
		"opacity", smoothstep(0, .025, collapse_age) * (1.0 - smoothstep(.20, .80, collapse_age))
	)
	mote_material.set_shader_parameter("age", max(0.0, collapse_age))
	mote_material.set_shader_parameter(
		"opacity", smoothstep(0, .03, collapse_age) * (1.0 - smoothstep(.35, 1.20, collapse_age))
	)
	mote_material.set_shader_parameter("gold", settings.shape != "creature")
	for i in range(motes.size()):
		motes[i].visible = show_spell and collapse_age >= 0 and collapse_age < 1.2
		motes[i].position = mote_origins[i] + mote_velocities[i] * max(0.0, collapse_age)
		motes[i].look_at(
			motes[i].position + Vector3(camera_sign.x, .70710678, camera_sign.y), Vector3.UP
		)
	if tick == int(ceil(disintegrate * 144)) and settings.mode != "loop":
		if collider:
			collider.collision_layer = 0
		print(
			"FORCE_DISINTEGRATE ",
			JSON.stringify(
				{
					"tick": tick,
					"wholeOwner": true,
					"allPanelsRetire": true,
					"instantPhysicalRemoval": "native event; visual tail only"
				}
			)
		)


func raw_texture(path: String) -> ImageTexture:
	return ImageTexture.create_from_image(
		VfxPackageIO_fe6a0d81ec.image(ProjectSettings.globalize_path(path))
	)


func make_ice_material() -> ShaderMaterial:
	var m = ShaderMaterial.new()
	m.shader = VfxPackageIO_fe6a0d81ec.resource("res://assets/vfx/sources/24bcc6476514b5cde490/DomeIceSource.gdshader")
	m.set_shader_parameter(
		"AddTexture",
		raw_texture("res://assets/vfx/sources/cc3ee322db85204a95aa/texture.res")
	)
	m.set_shader_parameter(
		"AddTexture2",
		raw_texture("res://assets/vfx/sources/9dd4b1e9c98d16632575/texture.res")
	)
	var n = FastNoiseLite.new()
	n.frequency = .0166
	n.domain_warp_enabled = true
	n.domain_warp_frequency = -.06
	n.domain_warp_fractal_type = 0
	var noise = NoiseTexture2D.new()
	noise.noise = n
	noise.seamless = true
	var ramp = Gradient.new()
	ramp.colors = PackedColorArray([Color(.779292, .779291, .779291), Color.BLACK])
	ramp.offsets = PackedFloat32Array([.00561798, 1])
	noise.color_ramp = ramp
	m.set_shader_parameter("DetailsTexture", noise)
	var gradient = Gradient.new()
	gradient.interpolation_color_space = 2
	gradient.offsets = PackedFloat32Array([0, .640669, .724234, .785515, 1])
	gradient.colors = PackedColorArray(
		[
			Color(.0972, .17208, .27),
			Color(.424525, .485861, .584245),
			Color.WHITE,
			Color(.3285, .3771, .45),
			Color(.694884, .789944, .941747)
		]
	)
	var palette = GradientTexture1D.new()
	palette.gradient = gradient
	m.set_shader_parameter("Color1DGradient", palette)
	m.set_shader_parameter("fresnelpower", 1.36)
	m.set_shader_parameter("Texture_add2_offset", Vector2(2.875, 1.02))
	m.set_shader_parameter("Details_scale", Vector2(1, 1))
	m.set_shader_parameter("Details_speed", Vector2(0, .02))
	m.set_shader_parameter("ColorIntensity", 1.45)
	m.set_shader_parameter("camera_sign", camera_sign)
	m.set_shader_parameter("front", side == "front")
	return m


func sphere_position(theta: float, phi: float, r: float) -> Vector3:
	return Vector3(r * sin(phi) * cos(theta), r * cos(phi), r * sin(phi) * sin(theta))


func ice_piece(theta0: float, theta1: float, phi0: float, phi1: float) -> Dictionary:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var origin = sphere_position((theta0 + theta1) * .5, (phi0 + phi1) * .5, RADIUS)
	var hull = PackedVector3Array()
	# Four smoothly curved cells per patch, two complete physical faces.
	for side in [-1, 1]:
		for u in range(2):
			for v in range(2):
				var a = lerpf(theta0, theta1, float(u) / 2)
				var b = lerpf(theta0, theta1, float(u + 1) / 2)
				var c = lerpf(phi0, phi1, float(v) / 2)
				var d = lerpf(phi0, phi1, float(v + 1) / 2)
				var order = [
					Vector2(a, c),
					Vector2(b, c),
					Vector2(a, d),
					Vector2(b, c),
					Vector2(b, d),
					Vector2(a, d)
				]
				if side < 0:
					order.reverse()
				for uv in order:
					var p = sphere_position(uv.x, uv.y, RADIUS + side * CELL * .10) - origin
					st.set_uv(Vector2(uv.x / TAU, uv.y / PI))
					st.add_vertex(p)
					hull.append(p)
	# Rim faces close each physical piece; connected patches share exact ports.
	for edge in range(4):
		var a = Vector2(theta0, phi0)
		var b = Vector2(theta1, phi0)
		if edge == 1:
			a = Vector2(theta1, phi0)
			b = Vector2(theta1, phi1)
		elif edge == 2:
			a = Vector2(theta1, phi1)
			b = Vector2(theta0, phi1)
		elif edge == 3:
			a = Vector2(theta0, phi1)
			b = Vector2(theta0, phi0)
		for pair in [
			Vector3(0, -1, 0),
			Vector3(1, -1, 0),
			Vector3(0, 1, 0),
			Vector3(1, -1, 0),
			Vector3(1, 1, 0),
			Vector3(0, 1, 0)
		]:
			var uv = a.lerp(b, pair.x)
			st.set_uv(uv / Vector2(TAU, PI))
			st.add_vertex(sphere_position(uv.x, uv.y, RADIUS + pair.y * CELL * .10) - origin)
	st.generate_normals()
	return {"mesh": st.commit(), "hull": hull, "origin": origin}


func make_ice_shell() -> void:
	ice_material = make_ice_material()
	ice_whole = MeshInstance3D.new()
	ice_whole.material_override = ice_material
	subject.add_child(ice_whole)
	var joined = SurfaceTool.new()
	joined.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng = RandomNumberGenerator.new()
	rng.seed = 72510
	for j in range(6):
		for i in range(12):
			var piece = ice_piece(
				float(i) / 12 * TAU,
				float(i + 1) / 12 * TAU,
				float(j) / 6 * PI * .5,
				float(j + 1) / 6 * PI * .5
			)
			var arrays = piece.mesh.surface_get_arrays(0)
			for vertex in range(48):
				joined.set_normal(arrays[Mesh.ARRAY_NORMAL][vertex])
				joined.set_uv(arrays[Mesh.ARRAY_TEX_UV][vertex])
				joined.add_vertex(arrays[Mesh.ARRAY_VERTEX][vertex] + piece.origin)
			var body = RigidBody3D.new()
			body.freeze = true
			body.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
			body.collision_layer = 2
			body.collision_mask = 1
			body.mass = .3
			body.continuous_cd = true
			body.linear_damp = .15
			body.angular_damp = 3.0
			var physical = PhysicsMaterial.new()
			physical.bounce = 0.0
			physical.friction = 1.0
			body.physics_material_override = physical
			subject.add_child(body)
			body.position = piece.origin
			var cs = CollisionShape3D.new()
			var shape = ConvexPolygonShape3D.new()
			var shrink = PackedVector3Array()
			for p in piece.hull:
				shrink.append(p * .94)
			shape.points = shrink
			shape.margin = .002
			cs.shape = shape
			body.add_child(cs)
			var visual = MeshInstance3D.new()
			visual.mesh = piece.mesh
			visual.material_override = ice_material
			visual.visible = side != "spell"
			body.add_child(visual)
			ice_bodies.append(body)
			body.set_meta(
				"angular",
				Vector3(
					rng.randf_range(-.08, .08),
					rng.randf_range(-.08, .08),
					rng.randf_range(-.08, .08)
				)
			)
	ice_whole.mesh = joined.commit()
	var floor = StaticBody3D.new()
	floor.position = Vector3(0, -.25, 0)
	subject.add_child(floor)
	var shape = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(40, .5, 40)
	shape.shape = box
	floor.add_child(shape)
	ice_air = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = RADIUS
	sphere.height = RADIUS * 2
	sphere.radial_segments = 64
	sphere.rings = 32
	ice_air.mesh = sphere
	subject.add_child(ice_air)
	ice_air_material = ShaderMaterial.new()
	var s = Shader.new()
	s.code = "shader_type spatial;render_mode unshaded,depth_draw_never,cull_disabled;uniform float opacity=0.0;uniform vec2 camera_sign;uniform bool front=false;void fragment(){vec3 wp=(INV_VIEW_MATRIX*vec4(VERTEX,1.0)).xyz;if(wp.y<0.0||(dot(wp.xz,camera_sign)>0.0)!=front)discard;float rim=pow(1.0-abs(dot(NORMAL,VIEW)),1.8);ALBEDO=vec3(.45,.69,.80);ALPHA=(.02+.07*rim)*opacity;}"
	ice_air_material.shader = s
	ice_air_material.set_shader_parameter("camera_sign", camera_sign)
	ice_air_material.set_shader_parameter("front", side == "front")
	ice_air.material_override = ice_air_material
	ice_air.visible = side != "spell"
	for i in range(24):
		var flake = MeshInstance3D.new()
		var q = QuadMesh.new()
		q.size = Vector2(.065, .065)
		flake.mesh = q
		subject.add_child(flake)
		var mat = ShaderMaterial.new()
		var sh = Shader.new()
		sh.code = "shader_type spatial;render_mode unshaded,depth_draw_never,cull_disabled;uniform float opacity=0.0;uniform vec2 camera_sign;uniform bool front=false;void vertex(){MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0],INV_VIEW_MATRIX[1],INV_VIEW_MATRIX[2],MODEL_MATRIX[3]);}void fragment(){vec3 wp=(INV_VIEW_MATRIX*vec4(VERTEX,1.0)).xyz;if((dot(wp.xz,camera_sign)>0.0)!=front)discard;vec2 q=UV*2.0-1.0;ALBEDO=vec3(.67,.82,.89);ALPHA=opacity*(1.0-smoothstep(.15,1.0,length(q)));}"
		mat.shader = sh
		mat.set_shader_parameter("camera_sign", camera_sign)
		mat.set_shader_parameter("front", side == "front")
		flake.material_override = mat
		flake.visible = side != "spell"
		ice_flakes.append(flake)
		ice_flake_materials.append(mat)


func update_ice(age: float) -> void:
	var hold = settings.mode == "loop"
	var air_only = settings.mode == "air"
	var break_age = age - 4.1
	if not ice_broken and (break_age >= 0 and not hold or air_only):
		ice_broken = true
		collider.collision_layer = 0
		for b in ice_bodies:
			b.freeze = false
			b.angular_velocity = b.get_meta("angular")
			b.linear_velocity = (
				Vector3(b.position.x, 0, b.position.z).normalized() * 1.2 + Vector3(0, -.5, 0)
			)
		print(
			"ICE_DOME_SHARED_POOL ",
			JSON.stringify(
				{
					"initialHP": 120,
					"remainingHP": 0,
					"wholeShell": true,
					"bodies": ice_bodies.size(),
					"nativeTick": tick,
					"createsHollowResidualAir": true
				}
			)
		)
	if tick % 18 == 0:
		var poses = []
		for b in ice_bodies:
			poses.append(
				[b.position.x, b.position.y, b.position.z, b.rotation.x, b.rotation.y, b.rotation.z]
			)
		physics_frames.append({"tick": tick, "iceBroken": ice_broken, "poses": poses})
	var expiry = 1.0 if hold or air_only else 1.0 - smoothstep(7.2, 7.95, age)
	ice_material.set_shader_parameter("age", 2.0 if hold else age)
	ice_material.set_shader_parameter(
		"opacity", expiry * (1.0 if not ice_broken else 1.0 - smoothstep(1.5, 2.3, break_age))
	)
	ice_whole.visible = side != "spell" and not ice_broken and not air_only
	for b in ice_bodies:
		b.visible = side != "spell" and ice_broken and not air_only
	var air_opacity = 0.0 if hold else expiry * (1.0 if air_only else smoothstep(0, .4, break_age))
	ice_air_material.set_shader_parameter("opacity", air_opacity)
	var clock = fposmod(age, 4.0) / 4.0
	for i in range(ice_flakes.size()):
		var phase = fposmod(clock + float(i) * .61803398875, 1.0)
		var a = float(i) / 24 * TAU
		var phi = .25 + float(i % 6) / 6 * 1.20
		var p = sphere_position(a, phi, RADIUS)
		p.y -= .25 * phase
		ice_flakes[i].position = p
		ice_flake_materials[i].set_shader_parameter(
			"opacity",
			air_opacity * .36 * smoothstep(0, .14, phase) * (1.0 - smoothstep(.8, 1, phase))
		)

const VfxPackageIO_fe6a0d81ec = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
