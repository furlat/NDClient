extends "res://assets/vfx/sources/a4fd0883f0b17d893a03/base.gd"
## Port of the accepted Finger hit's donor, compression shell and rigid shards.
## Source equations are retained; only world registration belongs to the host.
var pulse: MeshInstance3D
var shards: Array[MeshInstance3D] = []

static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/beb8f110e25cf563f964/skeletal_impact.gd", input)

func prepare_materials(_node: Node) -> void:
	pass

func tint(colour: Color) -> Color:
	return Color(colour.v, colour.v, colour.v, colour.a)

func apply_scene_edits(node: Node) -> void:
	var donor: Node3D = VfxPackageIO_beb8f110e2.resource(settings.source_path).instantiate()
	ResourceGraph.isolate_node(donor, {})
	node.add_child(donor)
	donor.scale = Vector3.ONE * float(settings.source_scale)
	donor.position.y = float(settings.height)
	donor.get_node("stars").hide()
	donor.get_node("torus").hide()
	var aura: GPUParticles3D = donor.get_node("Pruple Expansion")
	aura.position.z = 0.
	aura.lifetime = .60
	aura.amount = 1
	aura.process_material = aura.process_material.duplicate(true)
	aura.process_material.scale_min = 2.1
	aura.process_material.scale_max = 2.4
	for child in donor.find_children("*", "", true, false):
		if child is GeometryInstance3D:
			if "distort" in String(child.name).to_lower():
				child.layers = 0
			if child.material_override is ShaderMaterial and "hint_screen_texture" in child.material_override.shader.code:
				child.layers = 0
		if child is GPUParticles3D:
			child.fixed_fps = 144
			child.use_fixed_seed = true
			child.seed = 52917
			child.restart()
		for property in child.get_property_list():
			if int(property.usage) & PROPERTY_USAGE_STORAGE and child.get(property.name) is Resource:
				recolor(child.get(property.name))
		if child is AnimationPlayer and child.has_animation("Init"):
			child.play("Init")
	pulse = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.
	sphere.height = 2.
	sphere.radial_segments = 64
	sphere.rings = 32
	pulse.mesh = sphere
	pulse.position.y = 1.
	pulse.material_override = VfxPackageIO_beb8f110e2.resource(settings.shell_material).duplicate(true)
	pulse.material_override.set_shader_parameter("style", 3)
	adapt_shader(pulse.material_override)
	node.add_child(pulse)
	for index in 26:
		var shard := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.
		mesh.bottom_radius = .045
		mesh.height = .60
		mesh.radial_segments = 3
		shard.mesh = mesh
		shard.material_override = VfxPackageIO_beb8f110e2.resource(settings.shard_material).duplicate(true)
		adapt_shader(shard.material_override)
		node.add_child(shard)
		shards.append(shard)

func advance_lifecycle(_delta: float) -> void:
	tick += 1
	var age := float(tick) / float(parameters.simulation_hz)
	var envelope := smoothstep(0., .04, age) * (1. - smoothstep(.65, 1.35, age))
	for material in materials:
		material.set_shader_parameter("support_clock", age)
		material.set_shader_parameter("support_envelope", envelope)
	var radius := lerpf(1.15, .45, smoothstep(0., .27, age))
	pulse.scale = Vector3(radius, 1.25, radius)
	for index in shards.size():
		var shard: MeshInstance3D = shards[index]
		var angle := float(index) * 2.399963
		var direction := Vector3(sin(angle), -.15 + float(index % 5) * .21, cos(angle)).normalized()
		var travel := maxf(0., age - .18)
		shard.position = Vector3(0, 1., 0) + direction * (.5 + travel * 2.6) - Vector3.UP * travel * travel * .8
		shard.rotation = Vector3(angle * .3, angle, age * 2. + angle)
		shard.scale = Vector3(.6, 1. + float(index % 4) * .28, .6) * (1. - smoothstep(.55, 1.2, age))

const VfxPackageIO_beb8f110e2 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
