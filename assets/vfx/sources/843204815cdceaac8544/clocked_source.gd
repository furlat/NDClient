extends "res://assets/vfx/sources/e212c77ca5bf64639ea0/base.gd"
const MaterialRules = preload("res://assets/vfx/sources/95fc365541b49f145767/donor_material_rules.gd")
const SourceMaterials = preload("res://assets/vfx/sources/5f45d57a61f8be02c69c/source_materials.gd")


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
			# VisualShader omits default samplers from its uniform list. Enumerate
			# the plain replacement, and store values on the material for duplication.
			var defaults = {}
			for uniform in sh.get_shader_uniform_list():
				if int(uniform.type) != TYPE_OBJECT:
					continue
				var texture = r.shader.get_default_texture_parameter(uniform.name)
				if texture != null and r.get_shader_parameter(uniform.name) == null:
					defaults[uniform.name] = texture
			r.shader = sh
			for uniform in defaults:
				r.set_shader_parameter(uniform, defaults[uniform])
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
	return construct("res://assets/vfx/sources/843204815cdceaac8544/clocked_source.gd", input)
