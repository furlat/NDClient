extends "res://assets/vfx/sources/a4fd0883f0b17d893a03/base.gd"
## Native source authoring; shared stage, process clock, palette and capture.
const SourceMaterials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/41bda60be893f43ae18e/solid_wall.gd", input)


func prepare_materials(_node: Node) -> void:
	pass


const CELL = 2.121320344
const HEIGHT = CELL * 2.0
const WIDTH = CELL * 2.0
var camera_ground = Vector2(1, 1).normalized()
var panels: Array[Node3D] = []
var faces: Array[MeshInstance3D] = []
var mats: Array[ShaderMaterial] = []
var panel_mats: Array[Array] = []
var fragment_mesh: Mesh
var fragment_mat: ShaderMaterial
var fragments: Array[RigidBody3D] = []
var air: Array[MeshInstance3D] = []
var air_mats: Array[ShaderMaterial] = []
var frost_flakes: Array[MeshInstance3D] = []
var flake_mats: Array[ShaderMaterial] = []
var donor_mesh: Mesh
var donor_mat: Material
var report = []
var broken = false
var break_time = 2.5
var thickness = CELL * .8
var pillar_meshes: Array[Mesh] = []
var pillar_textures: Array[Texture2D] = []


func apply_scene_edits(node: Node) -> void:
	subject = node
	var donor = (
		node.find_child("SmRocksStone6002" if settings.kind == "ice" else "stoneK2", true, false)
		as MeshInstance3D
	)
	donor_mesh = donor.mesh
	donor_mat = (
		donor.material_override if donor.material_override else donor.mesh.surface_get_material(0)
	)
	if settings.kind == "ice":
		var chips = node.find_child("debirs_icex", true, false) as GPUParticles3D
		fragment_mesh = chips.draw_pass_1
	else:
		fragment_mesh = VfxPackageIO_41bda60be8.resource(
			"res://assets/vfx/sources/55fd731cb25be138bc7a/sm_debris_1.res"
		)
	if settings.kind == "stone":
		var quarry = (
			(
				VfxPackageIO_41bda60be8.resource(
					"res://assets/vfx/sources/cd887797aaf37f757e0d/VFX_Earth_StonePrison.tscn"
				)
				as PackedScene
			)
			. instantiate()
		)
		for name in ["stone13", "stone9", "stone7"]:
			var rock = quarry.find_child(name, true, false) as MeshInstance3D
			pillar_meshes.append(rock.mesh)
			var rockmat = (
				rock.material_override
				if rock.material_override
				else rock.mesh.surface_get_material(0)
			)
			pillar_textures.append((rockmat as StandardMaterial3D).albedo_texture)
		quarry.free()
	else:
		pillar_meshes.append(
			VfxPackageIO_41bda60be8.resource("res://assets/vfx/sources/0100325de637c6d467b7/sm_rocks_stone4_001.res")
		)
		pillar_meshes.append(
			VfxPackageIO_41bda60be8.resource("res://assets/vfx/sources/cb33c0fa432a9328f94d/sm_rocks_stone5_001.res")
		)
	for child in node.get_children():
		node.remove_child(child)
		child.free()
	node.scale = Vector3.ONE
	node.position = Vector3.ZERO
	var source_variant = int(settings.get("module_variant", 0))
	var endpoints = [Vector4(-3, .5, -1, .5), Vector4(-1, .5, 1, .5), Vector4(1, .5, 3, .5)]
	if settings.get("single_section", false):
		endpoints = [Vector4(-1, .5, 1, .5)]
	if settings.shape == "corner":
		endpoints = [Vector4(-3, .5, -1, .5), Vector4(-1, .5, 1, .5), Vector4(1, .5, 1, 2.5)]
	for i in range(endpoints.size()):
		var e = endpoints[i]
		var a = Vector3(e.x * CELL, 0, e.y * CELL)
		var b = Vector3(e.z * CELL, 0, e.w * CELL)
		var root = Node3D.new()
		node.add_child(root)
		root.position = (a + b) * .5
		root.rotation.y = -atan2(b.z - a.z, b.x - a.x)
		panels.append(root)
		var material = make_material(i + source_variant, false)
		panel_mats.append([material])
		var sculpture = MeshInstance3D.new()
		sculpture.mesh = varied_donor(donor_mesh, i + source_variant)
		sculpture.custom_aabb = sculpture.mesh.get_aabb().grow(.1)
		sculpture.material_override = material
		root.add_child(sculpture)
		faces.append(sculpture)
		sculpture.scale = Vector3(1, .30, .60)
		add_pillars(root, i)
		(
			report
			. append(
				{
					"section": i,
					"startCells": [e.x, e.y],
					"endCells": [e.z, e.w],
					"variant": i,
					"lengthFeet": 10,
					"heightFeet": 10,
					"visualThicknessFeet": 4,
					"srdThicknessFeet": 1 if settings.kind == "ice" else .5,
					"visualThicknessChoice":
					"User requested substantial rock/crystal masses; four directions does not imply thin art",
					"connectorProfileNative": [WIDTH * .5, HEIGHT, thickness * .30],
					"retainsSourceUV": true
				}
			)
		)
	if settings.shape == "corner":
		var join = MeshInstance3D.new()
		var box = BoxMesh.new()
		box.size = Vector3(thickness, HEIGHT, thickness)
		join.mesh = box
		join.position = Vector3(CELL, HEIGHT * .5, .5 * CELL)
		join.material_override = make_material(0, false)
		node.add_child(join)
	var floor = StaticBody3D.new()
	floor.position = Vector3(0, -.25, 0)
	node.add_child(floor)
	var shape = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(40, .5, 40)
	shape.shape = box
	floor.add_child(shape)
	fragment_mat = make_material(1, false)
	if settings.kind == "ice":
		create_air()


func add_pillars(root: Node3D, index: int) -> void:
	for j in range(5):
		var variant = (j + (index + int(settings.get("module_variant", 0))) * 2) % pillar_meshes.size()
		var rock = MeshInstance3D.new()
		rock.mesh = pillar_meshes[variant]
		var bb = rock.mesh.get_aabb()
		var h = HEIGHT * (.87 + .14 * sin(j * 1.7 + index * 1.1))
		var size = Vector3(WIDTH / 5.0 * 1.25, h, thickness * (1.0 + .10 * cos(j * 2.1 + index)))
		rock.scale = size / bb.size
		rock.position = (
			Vector3((float(j) + .5) / 5.0 * WIDTH - WIDTH * .5, 0, .10 * sin(j * 2.1 + index))
			- (bb.position + Vector3(bb.size.x * .5, 0, bb.size.z * .5)) * rock.scale
		)
		rock.rotation.y = .15 * sin(j * 1.9 + index * 1.4)
		var material = make_material(variant, false)
		if settings.kind == "stone":
			material.set_shader_parameter("rock_tex", pillar_textures[variant])
			material.set_shader_parameter("tint", Vector3(4.6, 4.5, 4.0))
		rock.material_override = material
		root.add_child(rock)
		panel_mats[index].append(material)
	# Low irregular original boulders seat the wall on the ground.
	for j in range(4):
		var rock = MeshInstance3D.new()
		rock.mesh = pillar_meshes[(j + index) % pillar_meshes.size()]
		var bb = rock.mesh.get_aabb()
		rock.scale = Vector3(WIDTH * .30, HEIGHT * .17, thickness * 1.10) / bb.size
		rock.position = (
			Vector3((float(j) + .5) / 4 * WIDTH - WIDTH * .5, 0, .16 * cos(j + index))
			- (bb.position + Vector3(bb.size.x * .5, 0, bb.size.z * .5)) * rock.scale
		)
		rock.rotation.y = .25 * sin(j * 2.3 + index)
		var material = make_material(j % pillar_meshes.size(), false)
		if settings.kind == "stone":
			material.set_shader_parameter(
				"rock_tex", pillar_textures[(j + index) % pillar_meshes.size()]
			)
			material.set_shader_parameter("tint", Vector3(4.6, 4.5, 4.0))
		rock.material_override = material
		root.add_child(rock)
		panel_mats[index].append(material)


func varied_donor(original: Mesh, index: int) -> ArrayMesh:
	var mesh = ArrayMesh.new()
	var bounds = original.get_aabb()
	for surface in range(original.get_surface_count()):
		var arrays = original.surface_get_arrays(surface)
		var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for i in range(v.size()):
			var normalized = (v[i] - bounds.position) / bounds.size
			var u = normalized.x
			var y = normalized.y
			var z = normalized.z - .5
			var envelope = pow(sin(PI * u), 2.0) * sin(PI * y)
			v[i] = Vector3(
				(u - .5) * WIDTH,
				(
					y * HEIGHT
					+ envelope * .13 * sin(u * 8.0 + index * 2.1)
					- (
						pow(sin(PI * u), 2.0)
						* (.20 + .13 * sin(u * 15.0 + index * 2.4))
						* pow(y, 4.0)
					)
				),
				(
					z * thickness * (.82 + .12 * sin(u * 11 + index * 1.7))
					+ envelope * .045 * sin(u * 13 + y * 9 + index * 2.3)
				)
			)
		arrays[Mesh.ARRAY_VERTEX] = v
		var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var calibration = Vector3(
			WIDTH / bounds.size.x, HEIGHT / bounds.size.y, thickness / bounds.size.z
		)
		for j in range(norms.size()):
			norms[j] = (norms[j] / calibration).normalized()
		arrays[Mesh.ARRAY_NORMAL] = norms
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func core_mesh(index: int) -> ArrayMesh:
	var tool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var verts: Array[Vector3] = []
	for side in [-1, 1]:
		for i in range(5):
			for j in range(5):
				var u = float(i) / 4
				var v = float(j) / 4
				var e = sin(PI * u) * sin(PI * v)
				verts.append(
					Vector3(
						(u - .5) * WIDTH,
						(
							v * HEIGHT
							- (
								pow(sin(PI * u), 2.0)
								* (.20 + .13 * sin(u * 15.0 + index * 2.4))
								* pow(v, 4.0)
							)
						),
						(
							side
							* (
								thickness * .30
								+ e * thickness * .09 * sin(u * 9 + v * 6 + float(index))
							)
						)
					)
				)
	for side in range(2):
		for i in range(4):
			for j in range(4):
				var k = side * 25 + i * 5 + j
				var ids = (
					[k, k + 1, k + 5, k + 1, k + 6, k + 5]
					if side == 0
					else [k, k + 5, k + 1, k + 1, k + 5, k + 6]
				)
				for id in ids:
					tool.set_uv(Vector2(float((id % 25) / 5) / 4.0, float(id % 5) / 4.0))
					tool.add_vertex(verts[id])
	for i in range(4):
		for edge in [0, 1, 2, 3]:
			var a = i if edge == 0 else 20 + i if edge == 1 else i * 5 if edge == 2 else i * 5 + 4
			var b = a + 1 if edge < 2 else a + 5
			for id in [a, b, a + 25, b, b + 25, a + 25]:
				tool.set_uv(Vector2(0, float(id % 5) / 4.0))
				tool.add_vertex(verts[id])
	tool.generate_normals()
	return tool.commit()


func split_fragment() -> String:
	if side == "whole":
		return "vec3 wp=(INV_VIEW_MATRIX*vec4(VERTEX,1.0)).xyz;if(wp.y<0.0)discard;"
	return (
		"vec3 wp=(INV_VIEW_MATRIX*vec4(VERTEX,1.0)).xyz;if(wp.y<0.0)discard;"
		if settings.kind == "ice"
		else "vec3 wp=(INV_VIEW_MATRIX*vec4(VERTEX,1.0)).xyz;if(wp.y<0.0)discard;if((dot(wp.xz-actor_ground,camera_ground)>0.0)!=foreground)discard;"
	)


func make_material(index: int, core: bool) -> ShaderMaterial:
	var m = ShaderMaterial.new()
	var shader = Shader.new()
	var code = ""
	if settings.kind == "ice":
		m = (donor_mat as ShaderMaterial).duplicate(true)
		code = (
			m
			. shader
			. code
			. replace(
				"shader_type spatial;",
				"shader_type spatial;uniform float wall_clock=0.0;uniform float opacity=1.0;uniform float fracture=0.0;uniform vec2 actor_ground=vec2(0.0);uniform vec2 camera_ground=vec2(.70710678);uniform bool foreground=false;"
			)
		)
		code = (
			code
			. replace("TIME", "wall_clock")
			. replace("float n_out69p0 = BreakFactorLocal;", "float n_out69p0 = 0.0;")
			. replace("float n_out17p0 = wall_clock;", "float n_out17p0 = 1.5;")
		)
		code = code.replace("depth_draw_opaque", "depth_draw_never")
		var end = code.rfind("}")
		code = code.insert(
			end,
			(
				"ALPHA=opacity*(.49+.17*pow(1.0-clamp(dot(NORMAL,VIEW),0.0,1.0),1.5));"
				+ split_fragment()
			)
		)
		m.set_shader_parameter("ColorIntensity", 1.45 if not core else 1.15)
		m.set_shader_parameter("Details_speed", Vector2(0, .02))
		m.set_shader_parameter(
			"Texture_add2_offset", Vector2(2.875 + index * .17, 1.02 + index * .11)
		)
	else:
		code = (
			"shader_type spatial;render_mode blend_mix,depth_draw_opaque,cull_back,unshaded;uniform sampler2D rock_tex:source_color;uniform vec3 tint=vec3(1.0);uniform float opacity=1.0;uniform vec2 actor_ground=vec2(0.0);uniform vec2 camera_ground=vec2(.70710678);uniform bool foreground=false;void fragment(){vec3 wn=normalize((INV_VIEW_MATRIX*vec4(NORMAL,0.0)).xyz);float light=.65+.65*max(dot(wn,normalize(vec3(-.3,.75,.55))),0.0);ALBEDO=texture(rock_tex,UV).rgb*tint*light;ROUGHNESS=.83;ALPHA=opacity;"
			+ split_fragment()
			+ "}"
		)
		m.set_shader_parameter("rock_tex", (donor_mat as StandardMaterial3D).albedo_texture)
		m.set_shader_parameter("tint", Vector3(1.65, 1.62, 1.48) * (1.0 + index * .035))
	shader.code = code
	m.shader = shader
	m.set_shader_parameter("camera_ground", camera_ground)
	m.set_shader_parameter("foreground", side == "front")
	mats.append(m)
	return m


func create_air() -> void:
	var patch = MeshInstance3D.new()
	var volume = BoxMesh.new()
	volume.size = Vector3(WIDTH, HEIGHT, thickness)
	patch.mesh = volume
	patch.position = Vector3(0, HEIGHT * .5, .5 * CELL)
	subject.add_child(patch)
	var material = ShaderMaterial.new()
	var shader = Shader.new()
	shader.code = """shader_type spatial;
render_mode unshaded,blend_mix,depth_draw_never,cull_back;
uniform sampler2D cold_noise:repeat_enable,filter_linear;
uniform float wall_clock=0.0;
uniform float opacity=0.0;
uniform vec2 actor_ground=vec2(0.0);
uniform vec2 camera_ground=vec2(.70710678);
uniform bool foreground=false;
uniform vec3 centre;
uniform vec3 half_extent;
void fragment(){
	vec3 wp=(INV_VIEW_MATRIX*vec4(VERTEX,1.0)).xyz;
	vec3 ray=-normalize((INV_VIEW_MATRIX*vec4(VIEW,0.0)).xyz);
	vec3 safe_ray=sign(ray)*max(abs(ray),vec3(.0001));
	vec3 p=wp-centre;
	vec3 limits=(sign(safe_ray)*half_extent-p)/safe_ray;
	float travel=max(0.0,min(limits.x,min(limits.y,limits.z)));
	float step_size=travel/16.0;
	// The vapour is stationary: no advected fine texture or quantized colour chatter.
	float density=0.0;
	for(int i=0;i<16;i++){
		vec3 sample_point=p+ray*(float(i)+.5)*step_size;
		vec3 world_point=sample_point+centre;
		// Split the completed colour once, after rendering; never reblend the surface layers.
		vec3 edge=(half_extent-abs(sample_point))/half_extent;
		float boundary=smoothstep(0.0,.22,edge.x)*smoothstep(0.0,.20,edge.y)*smoothstep(0.0,.32,edge.z);
		float cloud=.62+.10*cos(sample_point.x*.85+sample_point.y*.40)+.08*cos(sample_point.z*.72-sample_point.y*.55);
		density+=boundary*cloud*step_size;
	}
	ALBEDO=vec3(.49,.76,.87);
	ALPHA=opacity*(1.0-exp(-density*.70));
}
"""
	material.shader = shader
	material.set_shader_parameter(
		"cold_noise",
		VfxPackageIO_41bda60be8.resource("res://assets/vfx/sources/9dd4b1e9c98d16632575/texture.res")
	)
	material.set_shader_parameter("centre", patch.position)
	material.set_shader_parameter("half_extent", volume.size * .5)
	material.set_shader_parameter("camera_ground", camera_ground)
	material.set_shader_parameter("foreground", side == "front")
	patch.material_override = material
	air.append(patch)
	air_mats.append(material)
	create_flakes()


func create_flakes() -> void:
	for i in range(14):
		var flake = MeshInstance3D.new()
		var mesh = QuadMesh.new()
		var size = .065 + .024 * float(i % 3)
		mesh.size = Vector2(size, size)
		flake.mesh = mesh
		subject.add_child(flake)
		var m = ShaderMaterial.new()
		var sh = Shader.new()
		sh.code = (
			"shader_type spatial;render_mode unshaded,blend_mix,depth_draw_never,cull_disabled;uniform float opacity=0.0;uniform vec2 actor_ground=vec2(0.0);uniform vec2 camera_ground=vec2(.70710678);uniform bool foreground=false;void vertex(){MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0],INV_VIEW_MATRIX[1],INV_VIEW_MATRIX[2],MODEL_MATRIX[3]);}void fragment(){vec2 q=UV*2.0-1.0;float soft=(1.0-smoothstep(.15,1.0,length(q)));ALBEDO=vec3(.67,.82,.89);ALPHA=opacity*soft;"
			+ split_fragment()
			+ "}"
		)
		m.shader = sh
		m.set_shader_parameter("camera_ground", camera_ground)
		m.set_shader_parameter("foreground", side == "front")
		flake.material_override = m
		flake_mats.append(m)
		frost_flakes.append(flake)


func update_flakes(age: float, ground: Vector2, removal: float) -> void:
	var clock = float(tick % 576) / float(parameters.simulation_hz)
	for i in range(frost_flakes.size()):
		var phase = fposmod(clock / 4.0 + float(i) * .61803398875, 1.0)
		var u = fposmod(float(i) * .754877666, 1.0)
		var v = fposmod(float(i) * .569840291, 1.0)
		var x = (u - .5) * WIDTH * .80 + .07 * sin(TAU * phase + float(i) * 1.7)
		var z = .5 * CELL + (v - .5) * thickness * .68 + .035 * cos(TAU * phase + float(i) * 2.1)
		frost_flakes[i].position = Vector3(x, HEIGHT * (1.0 - phase), z)
		var fade = smoothstep(0.0, .16, phase) * (1.0 - smoothstep(.78, 1.0, phase))
		flake_mats[i].set_shader_parameter("actor_ground", ground)
		flake_mats[i].set_shader_parameter(
			"opacity", .34 * fade * smoothstep(2.66, 2.95, age) * removal
		)


func shatter() -> void:
	broken = true
	for i in range(24):
		var body = RigidBody3D.new()
		body.mass = .3 if settings.kind == "ice" else 2.0
		body.gravity_scale = 1.2
		body.linear_damp = .25
		body.angular_damp = .7
		body.continuous_cd = true
		body.physics_material_override = PhysicsMaterial.new()
		body.physics_material_override.friction = .8
		body.physics_material_override.bounce = .08
		subject.add_child(body)
		var ix = i % 6
		var iy = i / 6
		body.position = Vector3(
			(float(ix) + .5) / 6 * WIDTH - WIDTH * .5, (float(iy) + .5) / 4 * HEIGHT, .5 * CELL
		)
		var piece = MeshInstance3D.new()
		piece.mesh = fragment_mesh
		var bb = fragment_mesh.get_aabb()
		var size = Vector3(
			.28 + float(i % 3) * .08, .26 + float(i % 4) * .04, .12 + float(i % 2) * .09
		)
		piece.scale = size / bb.size
		piece.position = -(bb.position + bb.size * .5) * piece.scale
		piece.material_override = fragment_mat
		body.add_child(piece)
		var shape = CollisionShape3D.new()
		var box = BoxShape3D.new()
		box.size = size
		shape.shape = box
		body.add_child(shape)
		body.linear_velocity = Vector3(
			.7 * sin(float(i) * 2.399),
			.8 + float(i % 3) * .35,
			(-1 if i % 2 == 0 else 1) * (.7 + float(i % 4) * .2)
		)
		body.angular_velocity = Vector3(2.0 * sin(i * 1.7), 1.6 * cos(i * 2.1), 1.8 * sin(i * .7))
		if settings.get("single_section", false):
			body.linear_velocity = subject.global_basis * body.linear_velocity
			body.angular_velocity = subject.global_basis * body.angular_velocity
		fragments.append(body)


func actor_z(age: float) -> float:
	if age < 3.7:
		return 2.0
	if age < 5.1:
		return 2.0 - (age - 3.7) / 1.4 * 4.0
	return -2.0


func advance_lifecycle(_delta: float) -> void:
	if not is_instance_valid(subject):
		return
	if settings.get("intact_retirement", false):
		advance_intact_retirement()
		return
	tick += 1
	var age = float(tick) / float(parameters.simulation_hz)
	var ground3 = subject.to_global(Vector3(0, 0, actor_z(age) * CELL))
	var ground = Vector2(ground3.x, ground3.z)
	var removal = 1.0 if settings.mode == "hazard" else 1.0 - smoothstep(6.0, 6.85, age)
	for i in range(panels.size()):
		panels[i].position.y = -HEIGHT * (1.0 - removal)
		var grow = smoothstep(float(i) * .10, .95 + float(i) * .10, age)
		panels[i].position.y -= HEIGHT * (1.0 - grow)
		var broken_index = 0 if settings.get("single_section", false) else 1
		panels[i].visible = not (i == broken_index and age >= break_time + .16)
		for material in panel_mats[i]:
			material.set_shader_parameter("fracture", 0.0)
	if not broken and age >= break_time + .13:
		shatter()
	for m in mats:
		m.set_shader_parameter("actor_ground", ground)
		m.set_shader_parameter("opacity", removal)
		m.set_shader_parameter("wall_clock", age)
	for m in air_mats:
		m.set_shader_parameter("actor_ground", ground)
		m.set_shader_parameter("wall_clock", float(tick % 576) / float(parameters.simulation_hz))
		m.set_shader_parameter("opacity", .25 * smoothstep(2.66, 2.95, age) * removal)
	if settings.kind == "ice":
		update_flakes(age, ground, removal)
	if settings.mode == "hazard" and age >= 5.40:
		for body in fragments:
			body.freeze = true


var ownership_sources: Array[MeshInstance3D] = []
var ownership_copies: Array[MeshInstance3D] = []
var ownership_mats: Array[ShaderMaterial] = []


func advance_intact_retirement() -> void:
	# Same source-law removal as the selected production bank: initial intact
	# sample, 850 ms cubic fade/submersion, no fracture or lingering vapour.
	var age = float(tick) / float(parameters.simulation_hz)
	tick += 1
	var u = clampf(age / .85, 0., 1.)
	var fade = 1. - u * u * (3. - 2. * u)
	for panel in panels:
		panel.position.y = -HEIGHT * (1. - fade)
		panel.visible = true
	for material in mats:
		material.set_shader_parameter("wall_clock", 1.5)
		material.set_shader_parameter("fracture", 0.)
		material.set_shader_parameter("opacity", fade)
	for mesh in air + frost_flakes:
		mesh.visible = false

const VfxPackageIO_41bda60be8 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
