extends "res://assets/vfx/sources/02e8eda447821da38634/necrotic.gd"


## Native portal donor, side partition, deterministic particles and closing lifecycle.
static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/b84738a9d299dde07220/banishment.gd", input)


func apply_scene_edits(node: Node) -> void:
	donor = VfxPackageIO_b84738a9d2.resource(settings.source_path).instantiate()
	ResourceGraph.isolate_node(donor, {})
	node.add_child(donor)
	donor.scale = Vector3.ONE * settings.source_scale
	donor.position.y = settings.height
	for c in [donor] + donor.find_children("*", "", true, false):
		if c is GeometryInstance3D:
			if "distort" in String(c.name).to_lower():
				c.layers = 0
			if (
				c.material_override is ShaderMaterial
				and "hint_screen_texture" in c.material_override.shader.code
			):
				c.layers = 0
		if c is GPUParticles3D:
			c.fixed_fps = 144
			c.use_fixed_seed = true
			c.seed = 52917
			c.process_material = c.process_material.duplicate(true)
			c.restart()
			seeds.append({"path": str(node.get_path_to(c)), "seed": 52917})
		if c is CPUParticles3D:
			c.color = Color.WHITE
		for p in c.get_property_list():
			if int(p.usage) & PROPERTY_USAGE_STORAGE and c.get(p.name) is Resource:
				recolor(c.get(p.name))
		if c is AnimationPlayer and c.has_animation("Init"):
			c.play("Init")
		if c is GeometryInstance3D and side == "back" and not c.material_override is ShaderMaterial:
			c.layers = 0


func advance_lifecycle(_delta: float) -> void:
	tick += 1
	var age = float(tick) / float(parameters.simulation_hz)
	var env = smoothstep(0., .18, age) * (1. - smoothstep(1.12, 1.70, age))
	for mat in materials:
		mat.set_shader_parameter("support_clock", age)
		mat.set_shader_parameter("support_envelope", env)
	var close = 1. - smoothstep(.52, 1.02, age)
	donor.scale = Vector3(max(.03, close), 1., 1.) * settings.source_scale

const VfxPackageIO_b84738a9d2 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
