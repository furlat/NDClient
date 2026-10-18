extends "res://assets/vfx/sources/a4fd0883f0b17d893a03/base.gd"
## Native accepted source functions; capture and finishing belong to the shared exporter.
const SourceMaterials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
const SpatialEnergyPalette = preload("res://assets/vfx/sources/386bc581a35eb3b9ee50/spatial_energy_palette.gd")


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/ef1a35639fac2e7e0962/slow.gd", input)


func prepare_materials(_node: Node) -> void:
	pass


var seen = {}
var haste_mesh: MeshInstance3D
var sparks: Array[MeshInstance3D] = []


func apply_scene_edits(node: Node) -> void:
	var source = DonorScene.instantiate(VfxPackageIO_ef1a35639f.resource(settings.wind_scene), [])
	ResourceGraph.isolate_node(source, {})
	node.add_child(source)
	node = source
	for player in node.find_children("*", "AnimationPlayer", true, false):
		player.stop()
		player.active = false
	node.scale *= float(settings.scale)
	node.scale *= Vector3(.90, .55, .90)
	var keep = []
	if settings.name == "VFX_WindAura_1":
		keep = ["SmCylinder3"]
		haste_mesh = node.get_node("SmCylinder3")
	if settings.name == "VFX_WindExtras_2":
		keep = ["windsoil"]
	if settings.name == "VFX_AirFlowUP":
		keep = ["windflowz"]
		var p = node.get_node("windflowz")
		p.amount = 2
		p.lifetime = 0.95
		p.one_shot = true
		p.explosiveness = 0.35
		p.process_material = p.process_material.duplicate(true)
		p.process_material.scale_min = 0.8
		p.process_material.scale_max = 1.2
		p.process_material.lifetime_randomness = 0.0
		if settings.kind == "trail":
			node.rotation.x = PI / 2.0
			node.position.y = 0.35
	if settings.name == "VFX_WindArea_Jump":
		keep = ["clouds_external2", "VFX_Smoke_A2"]
	for child in node.find_children("*", "", true, false):
		if child is Light3D:
			child.visible = false
		if child is GPUParticles3D:
			child.fixed_fps = 144
		if child is GeometryInstance3D:
			child.layers = 1 if String(child.name) in keep else 0
		if child is GeometryInstance3D:
			if child.material_override is ShaderMaterial:
				child.material_override = VfxPackageIO_ef1a35639f.resource(settings.surface_material).duplicate(true)
				child.material_override.set_shader_parameter("Size_Sphere", 0.0)
				child.material_override.set_shader_parameter("Overlay_Velocity", Vector2(.25, -.5))
				child.material_override.set_shader_parameter("Gradient_Line", 1.0)
				child.material_override.set_shader_parameter("fresnel_power", 1.6)
				adapt(child.material_override)
			elif side == "back":
				child.layers = 0
	# Small pulses travel on the surface, following the same sagging bands.
	var glow = SourceMaterials.raw_texture(settings.glow_texture)
	for i in range(32):
		var m = MeshInstance3D.new()
		var quad = QuadMesh.new()
		quad.size = Vector2(.10, .10)
		m.mesh = quad
		# This original glow PNG is an opaque grayscale mask, not RGBA colour.
		# Its luminance owns alpha; using it as albedo exposed black square cards.
		var material = ShaderMaterial.new()
		var glow_shader = Shader.new()
		glow_shader.code = "shader_type spatial; render_mode unshaded,cull_disabled; uniform sampler2D glow_mask:filter_linear; uniform vec4 glow_color:source_color; uniform float glow_alpha=0.0; void vertex(){ MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0]*length(MODEL_MATRIX[0].xyz),INV_VIEW_MATRIX[1]*length(MODEL_MATRIX[1].xyz),INV_VIEW_MATRIX[2]*length(MODEL_MATRIX[2].xyz),MODEL_MATRIX[3]); } void fragment(){ ALBEDO=glow_color.rgb; ALPHA=texture(glow_mask,UV).r*glow_alpha; }"
		material.shader = glow_shader
		material.set_shader_parameter("glow_mask", glow)
		material.set_shader_parameter("glow_color", Color(settings.palette[3]))
		m.material_override = material
		node.add_child(m)
		sparks.append(m)


func adapt(mat: ShaderMaterial) -> void:
	if seen.has(mat.get_instance_id()):
		return
	seen[mat.get_instance_id()] = true
	for name in ["Use_Proximity_Fade", "Enable_Proximity_Fade", "proximity_fade"]:
		mat.set_shader_parameter(name, false)
	if settings.kind == "loop":
		for uniform in mat.shader.get_shader_uniform_list():
			var name = String(uniform.name)
			var value = mat.get_shader_parameter(name)
			if value is Vector2 and "speed" in name.to_lower():
				mat.set_shader_parameter(
					name,
					Vector2(-0.25, -0.25) if settings.get("slow", false) else Vector2(0.5, 1.0)
				)
	var code = mat.shader.code.replace("TIME", "movement_clock")
	code = code.replace("VERTEX = n_out3p0;", "VERTEX = n_out3p0;")
	code = (
		code
		. replace(
			"n_out31p0 = clamp(1.0 - smoothstep(__depth_world_pos.z + n_out34p0, __depth_world_pos.z, VERTEX.z), 0.0, 1.0);",
			"n_out31p0 = 1.0;"
		)
	)
	code = code.replace("ALBEDO = n_out63p0;", "ALBEDO = n_out63p0 * 0.32;")
	code = (
		code
		. replace(
			"ALPHA = n_out96p0;",
			"""
	vec3 gp=(INV_VIEW_MATRIX*vec4(VERTEX,1.)).xyz;
	float angle=atan(gp.z,gp.x), height=gp.y/.55;
	float ph=movement_clock*1.57079632679;
	float sag=.27*pow(.5+.5*cos(angle*5.+.3*sin(ph)),5.)*(.75+.25*sin(ph+angle));
	float shape=fract(height*1.06+angle/6.2831853+movement_clock*.25+sag);
	float band=1.-smoothstep(.10,.21,abs(shape-.5));
	float env=smoothstep(.06,.30,height)*(1.-smoothstep(2.15,2.62,height));
	float line=exp(-pow((abs(shape-.5)-.13)/.032,2.));
	float shimmer=texture(Overlay_Texture,UV*vec2(2.,4.)+vec2(movement_clock*.25,-movement_clock*.5)).r;
	ALBEDO += vec3(.12,.22,.25)*line*(.3+.7*shimmer);
	ALPHA=max(n_out96p0*.72,line*.62)*band*env*(.38+.62*smoothstep(.15,.65,shimmer));
	if(ALPHA<.17)discard;
	"""
		)
	)
	code = code.replace(
		"shader_type spatial;",
		"shader_type spatial;\nuniform float movement_clock=0.0;\nuniform float movement_fade=1.0;"
	)
	var re = RegEx.new()
	re.compile("void\\s+fragment\\s*\\(\\s*\\)\\s*\\{")
	var found = re.search(code)
	if found:
		var prefix = (
			"\nvec3 world_pos=(INV_VIEW_MATRIX*vec4(VERTEX,1.0)).xyz;\nif(dot(world_pos,vec3(0.70710678,0.0,0.70710678)) "
			+ ("<" if side == "front" else ">=")
			+ " 0.0) discard;\n"
		)
		var start = found.get_end()
		code = code.insert(start, prefix)
		var level = 1
		var at = start + prefix.length()
		while at < code.length() and level > 0:
			if code[at] == "{":
				level += 1
			elif code[at] == "}":
				level -= 1
			at += 1
		code = code.insert(at - 1, "\nALPHA *= movement_fade;\n")
	code = code.replace("vec3(0.70710678,0.0,0.70710678)", settings.clip_vector)
	var shader = Shader.new()
	shader.code = code
	SourceMaterials.replace_shader(mat, shader)
	SpatialEnergyPalette.apply(mat, settings.palette, settings.get("native_palette_options", {}))
	materials.append(mat)


func advance_lifecycle(_delta: float) -> void:
	tick += 1
	if is_instance_valid(haste_mesh):
		haste_mesh.visible = true
		haste_mesh.layers = 1
		haste_mesh.material_override.set_shader_parameter("Opacity", 1.0)
	var age = float(tick) / float(parameters.simulation_hz)
	var phase = (
		float(tick % 576) / float(parameters.simulation_hz) if settings.kind == "loop" else age
	)
	for i in range(sparks.size()):
		var a = -2.7 + float(i % 4) * 1.5
		var ph = phase * PI / 2.
		var sag = .27 * pow(.5 + .5 * cos(a * 5. + .3 * sin(ph)), 5.) * (.75 + .25 * sin(ph + a))
		var h = (.5 - a / TAU - phase * .25 - sag + float(i / 4) - 2.) / 1.06
		var m = sparks[i]
		m.position = Vector3(cos(a) * .62, h * .55, sin(a) * .62)
		var signx = [1., 1., -1., -1.][int(settings.cameraQuarter)]
		var signz = [1., -1., -1., 1.][int(settings.cameraQuarter)]
		var front = m.position.x * signx + m.position.z * signz >= 0.
		m.visible = side == "full" or (front if side == "front" else not front)
		m.material_override.set_shader_parameter("glow_alpha", (
			smoothstep(.15, .45, h)
			* (1. - smoothstep(2.15, 2.6, h))
			* (.4 + .4 * sin(ph + float(i % 4)))
			* .85
		))
	for mat in materials:
		mat.set_shader_parameter("movement_clock", phase)
		mat.set_shader_parameter("movement_fade", 0.95 if settings.kind == "loop" else 1.0)

const VfxPackageIO_ef1a35639f = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
