extends "res://assets/vfx/sources/a4fd0883f0b17d893a03/base.gd"
var seen: Dictionary = {}
var haste_mesh: MeshInstance3D


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/2df94cf76d6f9f33bf21/movement_wind.gd", input)


func prepare_materials(_node: Node) -> void:
	pass


func apply_scene_edits(node: Node) -> void:
	node.scale = Vector3(.40, .40 * .816496580927726, .40)
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
				child.material_override = child.material_override.duplicate(true)
				adapt(child.material_override)
			elif side == "back":
				child.layers = 0


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
					name, Vector2(round(value.x * 2.0) / 2.0, round(value.y * 2.0) / 2.0)
				)
	var code = mat.shader.code.replace("TIME", "movement_clock")
	if settings.name == "VFX_WindAura_1":
		code = code.replace("n_out3p1 + n_out5p1", "smoothstep(0.24, 0.68, n_out3p1)")
		code = code.replace(
			"ALPHA = n_out27p0;",
			"ALPHA = n_out27p0 * smoothstep(0.02,0.18,UV.y) * (1.0-smoothstep(0.78,0.98,UV.y));"
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
	var shader = Shader.new()
	shader.code = code
	mat.shader = shader
	materials.append(mat)


func advance_lifecycle(_delta: float) -> void:
	if materials.is_empty():
		return
	tick += 1
	if is_instance_valid(haste_mesh):
		haste_mesh.visible = true
		haste_mesh.layers = 1
		haste_mesh.material_override.set_shader_parameter("Opacity", 1.0)
	var age = float(tick) / 144.0
	var phase = fmod(age, 2.0)
	for mat in materials:
		mat.set_shader_parameter("movement_clock", phase)
		mat.set_shader_parameter(
			"movement_fade", smoothstep(0., .65, age) * (1. - smoothstep(3., 4., age)) * .72
		)
