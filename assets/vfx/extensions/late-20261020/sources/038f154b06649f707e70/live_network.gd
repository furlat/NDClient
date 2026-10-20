extends Node3D
## Native, endpoint-driven electric geometry. No cameras, actors, rules or export.
## Boringdev ribbon/material lineage; endpoint topology and timing are caller data.
const Paths = preload("res://assets/vfx/extensions/late-20261020/sources/e6719ff212d75b074b38/electric_paths.gd")
const RibbonSource = preload("res://assets/vfx/extensions/late-20261020/sources/df180467412a5071502b/lightning_base.gd")
const DONOR := "res://assets/vfx/extensions/late-20261020/sources/4605c79d25e73430b93b/lightning_chain.tscn"
const CORE := "res://assets/vfx/extensions/late-20261020/sources/f3839fa028bc09fe2beb/lightning_bolt_blue_yellow.gdshader"

var settings: Dictionary = {}
var endpoints: Array = []
var ribbons: Array = []
var contact_draws: Array = []
var contact_arcs: MeshInstance3D
var hand_arcs: MeshInstance3D
var drawer: Node3D
var materials: Array[ShaderMaterial] = []
var last_paths: Array = []
var contact_state: Array = []

static func make_component(input: Dictionary) -> Node3D:
	var node := VfxPackageIO_038f154b06.resource("res://assets/vfx/extensions/late-20261020/sources/038f154b06649f707e70/live_network.gd").new() as Node3D
	node.settings = input.duplicate(true)
	node._build()
	return node

func _build() -> void:
	drawer = RibbonSource.new()
	var donor: Node3D = VfxPackageIO_038f154b06.resource(DONOR).instantiate()
	var core: ShaderMaterial = donor.get_node("BoltCore").material_override.duplicate(true)
	core.shader = _clock_shader(VfxPackageIO_038f154b06.resource(CORE))
	core.set_shader_parameter("core_color", Color(settings.get("core_color", "198fe1")))
	core.set_shader_parameter("glow_color", Color(settings.get("glow_color", "07499f")))
	core.set_shader_parameter("emission", float(settings.get("emission", .82)))
	var glow: ShaderMaterial = donor.get_node("BoltGlow").material_override.duplicate(true)
	glow.shader = _clock_shader(glow.shader)
	glow.set_shader_parameter("color", Color(settings.get("glow_color", "07499f")))
	glow.set_shader_parameter("emission", .7)
	for edge in settings.edges:
		ribbons.append({"core": _draw(core.duplicate(true)), "glow": _draw(glow.duplicate(true)), "edge": edge})
	contact_arcs = _draw(core.duplicate(true))
	hand_arcs = _draw(core.duplicate(true))
	for index in int(settings.get("endpoint_count", 4)):
		var group: Array = []
		for kind in ["glow", "star", "streak"]:
			var material := ShaderMaterial.new()
			material.shader = VfxPackageIO_038f154b06.resource("res://assets/vfx/extensions/late-20261020/sources/491789dcfd7b96ffa1f6/lightning_spark.gdshader")
			material.set_shader_parameter("tex", VfxPackageIO_038f154b06.resource("factory-path:library/selected/project_authored_godot_library_projects_boringdev_collection_eb22c84b/vfx_1/lightning/textures/" + kind + ".png"))
			material.set_shader_parameter("color", Color("187cdd") if kind == "glow" else Color("efb955"))
			material.set_shader_parameter("emission", .75)
			material.set_shader_parameter("alpha_mult", 0.0)
			var mesh := QuadMesh.new()
			mesh.size = Vector2.ONE
			var draw := MeshInstance3D.new()
			draw.mesh = mesh
			draw.material_override = material
			draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(draw)
			group.append(draw)
		contact_draws.append(group)
	donor.free()

func _exit_tree() -> void:
	if is_instance_valid(drawer):
		drawer.free()

func _clock_shader(source: Shader) -> Shader:
	var shader := Shader.new()
	shader.code = source.code.replace("void vertex()", "uniform float electric_clock = 0.;\nvoid vertex()").replace("TIME", "electric_clock")
	if settings.get("density_mask", false):
		shader.code = shader.code.replace("void vertex()", "uniform vec4 field_fluid[160];\nvarying vec2 field_point;\nvoid vertex()")
		shader.code = shader.code.replace("vec4 vp =", "field_point=VERTEX.xz;\n\tvec4 vp =")
		shader.code = shader.code.replace("void fragment() {", """void fragment() {
	float density=0.;
	for(int i=0;i<160;i++){
		float on_floor=1.-smoothstep(.03,.09,field_fluid[i].y);
		float d=length(field_point-field_fluid[i].xz)/.26;
		density+=pow(max(0.,1.-d*d),2.)*on_floor;
	}
	if(density<.48)discard;""")
	return shader

func _draw(material: ShaderMaterial) -> MeshInstance3D:
	var draw := MeshInstance3D.new()
	draw.mesh = ImmediateMesh.new()
	draw.material_override = material
	draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	materials.append(material)
	add_child(draw)
	return draw

func set_live_endpoints(value: Array) -> void:
	# Input points stay in world space until sample, after the occurrence's actual
	# placement transform has been applied by the shared native sampler.
	endpoints = value

func set_density_field(value: PackedVector4Array) -> void:
	for material in materials:
		material.set_shader_parameter("field_fluid", value)

func _local_point(index: int) -> Vector3:
	return global_transform.affine_inverse() * endpoints[index].point

func _paths(a: Vector3, b: Vector3, time: float, edge_index: int, heavy: bool) -> Array:
	var bucket := floori(time * 11.0)
	var weight := smoothstep(0.0, 1.0, fposmod(time * 11.0, 1.0))
	var seed_value: int = int(settings.get("seed", 47291)) + edge_index * 773
	var first: Array
	var second: Array
	if heavy:
		first = Paths.heavy_bolt(a, b, seed_value + bucket).slice(0, 5)
		second = Paths.heavy_bolt(a, b, seed_value + bucket + 1).slice(0, 5)
	else:
		first = Paths.chain([a, b], [[0, 1]], seed_value + bucket)
		second = Paths.chain([a, b], [[0, 1]], seed_value + bucket + 1)
	for index in first.size():
		for point in first[index].points.size():
			first[index].points[point] = first[index].points[point].lerp(second[index].points[point], weight)
	var primary: Array = first[0].points
	var count := primary.size() - 1
	var random := RandomNumberGenerator.new()
	random.seed = seed_value
	# Anchors are stable across morphology changes. Forks are rebuilt from the
	# interpolated spine so they cannot detach while two shapes blend.
	for fork in maxi(2, ceili(a.distance_to(b) * 1.2)):
		var anchor := 1 + random.randi_range(0, maxi(0, count - 3))
		var branch_end: Vector3 = first[(fork + 2) % 5].points[mini(count, anchor + 1)] if heavy else primary[anchor] + Vector3(random.randf_range(-.20, .20), random.randf_range(.09, .25), random.randf_range(-.20, .20))
		var branch := Paths.jagged(primary[anchor], branch_end, random, .035)
		first.append({"points": branch, "width": .16, "role": "fork", "attach": float(anchor) / count})
	if settings.get("plane_y") != null:
		for path in first:
			for index in path.points.size():
				path.points[index].y = float(settings.plane_y)
	return first

func _reveal(points: Array, ratio: float) -> Array:
	var count := points.size() - 1
	var cursor := ratio * count
	var result: Array = points.slice(0, floori(cursor) + 1)
	if ratio < 1.0:
		result.append(points[floori(cursor)].lerp(points[mini(count, floori(cursor) + 1)], fposmod(cursor, 1.0)))
	return result

func sample(seconds: float) -> void:
	last_paths.clear()
	contact_state.clear()
	for material in materials:
		material.set_shader_parameter("electric_clock", seconds)
	for ribbon in ribbons:
		(ribbon.core.mesh as ImmediateMesh).clear_surfaces()
		(ribbon.glow.mesh as ImmediateMesh).clear_surfaces()
	(contact_arcs.mesh as ImmediateMesh).clear_surfaces()
	(hand_arcs.mesh as ImmediateMesh).clear_surfaces()
	for group in contact_draws:
		for draw in group:
			draw.material_override.set_shader_parameter("alpha_mult", 0.0)
	if endpoints.size() < 2:
		return
	var contacts: Dictionary = {}
	for index in ribbons.size():
		var ribbon: Dictionary = ribbons[index]
		var edge: Dictionary = ribbon.edge
		if int(edge.from) < 0 or int(edge.to) < 0 or int(edge.from) >= endpoints.size() or int(edge.to) >= endpoints.size():
			continue
		var a := _local_point(int(edge.from))
		var b := _local_point(int(edge.to))
		var delay: float = edge.get("delay", 0.0)
		var travel: float = maxf(.045, a.distance_to(b) / float(settings.get("speed", 26.0)))
		var age := seconds - delay
		var reached := delay + travel
		var envelope := smoothstep(-.025, .015, age)
		if not settings.get("persistent", false):
			envelope *= 1.0 - smoothstep(travel + .30, travel + .60, age)
		envelope *= float(settings.get("opacity", 1.0))
		for draw in [ribbon.core, ribbon.glow]:
			draw.material_override.set_shader_parameter("alpha_mult", envelope)
		if age >= 0.0 and envelope > .001:
			var heavy: bool = settings.get("heavy", false)
			var paths := _paths(a, b, seconds, index, heavy)
			for path in paths:
				var ratio := clampf(age / travel, 0.0, 1.0)
				if path.get("role") == "fork":
					ratio = clampf((ratio - float(path.attach)) * 8.0, 0.0, 1.0)
				var points := _reveal(path.points, ratio)
				if points.size() < 2 or points.front().is_equal_approx(points.back()):
					continue
				var width: float = float(settings.get("width", .32)) * float(path.get("width", .52)) / .52
				drawer._emit_trail(ribbon.glow.mesh, points, width * 1.7, 0.0)
				for layer_width in [.5, .28, .13]:
					drawer._emit_trail(ribbon.core.mesh, points, width * layer_width, 0.0)
				last_paths.append({"edge": index, "start": a, "target": b, "tip": points.back(), "reveal": ratio})
		if seconds >= reached and settings.get("contact_from_edges",true):
			contacts[edge.to] = maxf(float(contacts.get(edge.to, -INF)), reached)
	for contact in settings.get("contact_schedule",[]):
		if seconds>=float(contact.at):
			contacts[contact.endpoint]=maxf(float(contacts.get(contact.endpoint,-INF)),float(contact.at))
	for index in contacts:
		if int(index)<endpoints.size() and endpoints[index].get("contact_enabled",true):
			_contact(int(index), seconds - float(contacts[index]))
	var hand_amount := smoothstep(-.28, -.04, seconds) * (1.0 - smoothstep(.12, .45, seconds)) if settings.get("charge_coil", true) else 0.0
	hand_amount *= float(settings.get("opacity", 1.0))
	hand_arcs.material_override.set_shader_parameter("alpha_mult", hand_amount)
	if hand_amount > .001:
		for loop_index in 2:
			var coil: Array = []
			for step in 18:
				var angle := TAU * float(step) / 17.0 + seconds * 8.0
				coil.append(_local_point(0) + Vector3(cos(angle), sin(angle), sin(angle * 2.0) * .4) * (.11 + loop_index * .035))
			drawer._emit_trail(hand_arcs.mesh, coil, .035, 0.0)

func _contact(index: int, age: float) -> void:
	var envelope := (1.0 - smoothstep(.20, .72, age)) * smoothstep(0.0, .025, age)
	envelope *= float(settings.get("opacity", 1.0))
	if envelope < .001:
		return
	var point := _local_point(index)
	contact_state.append({"endpoint": index, "age": age, "strength": envelope})
	if index < contact_draws.size():
		for draw_index in contact_draws[index].size():
			var draw: MeshInstance3D = contact_draws[index][draw_index]
			draw.position = point
			draw.scale = Vector3.ONE * [.72, .40, .85][draw_index] * (1.0 + age * .25)
			draw.material_override.set_shader_parameter("alpha_mult", envelope * [.55, .42, .18][draw_index])
	var surface: Dictionary = endpoints[index].get("surface", {})
	var points: Array = surface.get("points", [])
	if points.is_empty():
		return
	# Connected crawling arcs on measured outfit surfaces, with a normal offset.
	# No screen-space specks or uniform noise film, and no invented condition.
	contact_arcs.material_override.set_shader_parameter("alpha_mult", envelope * .8)
	for strand in 5:
		var arc: Array = []
		var start := (strand * 97 + floori(age * 8.0) * 23) % points.size()
		var end := (start + 71 + strand * 11) % points.size()
		var a: Vector3 = points[start].position + points[start].normal * .035
		var b: Vector3 = points[end].position + points[end].normal * .035
		var random := RandomNumberGenerator.new()
		random.seed = 6121 + strand
		arc.assign(Paths.jagged(global_transform.affine_inverse() * a, global_transform.affine_inverse() * b, random, .035))
		drawer._emit_trail(contact_arcs.mesh, arc, .035, 0.0)

const VfxPackageIO_038f154b06 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
