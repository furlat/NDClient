extends "res://assets/vfx/sources/a4fd0883f0b17d893a03/base.gd"
const MaterialRules = preload("res://assets/vfx/sources/0a217498d5d9825135cb/donor_material_rules.gd")
const SourceMaterials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")


func prepare_materials(node: Node) -> void:
	MaterialRules.apply(node, parameters.get("material_rules", []))
	clock_node(node)


func clock_node(node: Node) -> void:
	for p in node.get_property_list():
		if int(p.usage) & PROPERTY_USAGE_STORAGE:
			var r = node.get(p.name)
			if r is Resource:
				clock_resource(r)
	for c in node.get_children():
		clock_node(c)


func clock_resource(r: Resource) -> void:
	if r == null or visited.has(r.get_instance_id()):
		return
	visited[r.get_instance_id()] = true
	if r is ShaderMaterial:
		var code = SourceMaterials.expand_shader(
			r.shader.code, r.shader.resource_path.get_base_dir()
		)
		var token = RegEx.new()
		token.compile("\\bTIME\\b")
		if token.search(code):
			code = token.sub(code, "source_clock", true)
			code = code.replace(
				"shader_type spatial;", "shader_type spatial;\nuniform float source_clock=0.0;"
			)
			var sh = Shader.new()
			sh.code = code
			SourceMaterials.replace_shader(r, sh)
			materials.append(r)
	for p in r.get_property_list():
		if int(p.usage) & PROPERTY_USAGE_STORAGE:
			var v = r.get(p.name)
			if v is Resource:
				clock_resource(v)
	if r is Mesh:
		for i in r.get_surface_count():
			clock_resource(r.surface_get_material(i))


func advance_lifecycle(_d: float) -> void:
	tick += 1
	for m in materials:
		m.set_shader_parameter("source_clock", float(tick) / float(parameters.simulation_hz))


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/048e2881b9068776f055/clocked_source.gd", input)
