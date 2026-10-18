extends "res://assets/vfx/sources/a4fd0883f0b17d893a03/base.gd"
## Native source authoring; shared stage, process clock, palette and capture.
const SourceMaterials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/b7e4f5e433685cdff4bb/cloud_cohorts.gd", input)


func prepare_materials(_node: Node) -> void:
	pass


const INSPECT = false
var cloud: Node3D
var mats: Array[ShaderMaterial] = []
var banks: Array = []
var last_emission = -1
var kind = 0
var radius = 4.0


func apply_scene_edits(node: Node) -> void:
	cloud = node
	cloud.set_script(null)
	kind = (
		{"fog_cloud": 0, "cloudkill": 1, "stinking_cloud": 2, "darkness": 3, "incendiary_cloud": 4}
		. get(settings.spell, 0)
	)
	radius = 3.0 if settings.spell == "darkness" else 4.0
	var animation = cloud.get_node("AnimationPlayer")
	animation.stop()
	animation.process_mode = Node.PROCESS_MODE_DISABLED
	cloud.get_node("Glow").hide()
	var i = 0
	for name in ["Clouds_01", "Clouds_02"]:
		var part: GPUParticles3D = cloud.get_node(name)
		part.use_fixed_seed = true
		part.seed = 8121 + i * 119
		part.fixed_fps = 144
		part.local_coords = true
		part.amount = 64 if i == 0 else 44
		part.lifetime = float(settings.get("cohort_lifetime_seconds", 2.8125))
		part.preprocess = part.lifetime
		part.visibility_aabb = AABB(Vector3(-5, -2, -5), Vector3(10, 8, 10))
		var process = part.process_material.duplicate(true)
		part.process_material = process
		process.emission_sphere_radius = (2.3 if i == 0 else 1.9) * radius / 4.0
		process.emission_shape_scale = Vector3(1, .65, 1)
		process.scale_min = .85
		process.scale_max = 1.25
		part.position.y = .95 if i == 0 else 1.55
		if kind == 2:
			part.position.y = .5 if i == 0 else .85
			process.emission_shape_scale = Vector3(1, .3, 1)
		if kind == 3:
			part.amount = 96 if i == 0 else 68
			process.emission_sphere_radius *= .95
		if kind == 4:
			part.position.y = 1.35 if i == 0 else 2.0
			process.emission_shape_scale = Vector3(.85, 1.1, .85)
			part.amount = 76 if i == 0 else 52
		var mat: ShaderMaterial = part.material_override.duplicate(true)
		part.material_override = mat
		var palettes = [
			["c0cbd0", "95a9b3", "53636d"],
			["cad35a", "82912a", "303d24"],
			["cdc06c", "867b33", "302a16"],
			["424d58", "202832", "05070b"],
			["f39e3a", "633c2b", "1c1a1e"]
		]
		var pal = palettes[kind]
		mat.set_shader_parameter("primary_color", Color(pal[0]))
		mat.set_shader_parameter("secondary_color", Color(pal[1]))
		mat.set_shader_parameter("tertiary_color", Color(pal[2]))
		mat.set_shader_parameter("cloud_kind", kind)
		mat.set_shader_parameter("cloud_radius", radius)
		mat.set_shader_parameter("emission_strength", .2)
		mat.set_shader_parameter("alpha_multiplier", 2.4)
		mat.set_shader_parameter("proximity_fade", false)
		mats.append(mat)
		i += 1
	# Low perimeter billows occupy the full ground footprint without a flat shell.
	# Their overlapping volumes share the same formation and rolling phase.
	var source: GPUParticles3D = cloud.get_node("Clouds_02")
	for j in range(20):
		var edge: GPUParticles3D = source.duplicate()
		edge.name = "BoundaryBillow%d" % j
		cloud.add_child(edge)
		var angle = TAU * float(j) / 20.
		edge.position = Vector3(
			cos(angle) * (radius - .9), .65 + sin(angle * 3.) * .12, sin(angle) * (radius - .9)
		)
		if kind == 2:
			edge.position.y = .35 + sin(angle * 3.) * .08
		if kind == 4:
			edge.position.y = .9 + sin(angle * 2.) * .3
		edge.amount = 10
		edge.seed = 2107 + j * 131
		var process = edge.process_material.duplicate(true)
		edge.process_material = process
		process.emission_sphere_radius = .38
		process.emission_shape_scale = Vector3(1, .65, 1)
		process.scale_min = .65
		process.scale_max = .9
		var mat: ShaderMaterial = edge.material_override.duplicate(true)
		edge.material_override = mat
		mats.append(mat)
	if kind == 4:
		_replace_with_fire()
	for m in mats:
		var selected_shader: String = settings.fire_volume_shader if kind == 4 and settings.has("fire_volume_shader") else settings.volume_shader
		SourceMaterials.replace_shader(m, VfxPackageIO_b7e4f5e433.resource(selected_shader))
		if settings.has("carrier_feather_uv"):
			_feather_carrier(m, float(settings.carrier_feather_uv))
		if settings.has("retire_begin_seconds"):
			var shader := Shader.new()
			shader.code = SourceMaterials.expand_shader(m.shader.code, m.shader.resource_path.get_base_dir())
			shader.code = shader.code.replace("shader_type spatial;", "shader_type spatial;\nuniform float cloud_retirement=0.0;\nvarying flat float cloud_retire_seed;")
			# Retire whole moving billows at staggered times. A world-coordinate
			# erosion field cut the cloud into artificial vertical pillars.
			shader.code = SourceMaterials.finish_function(shader.code, "vertex", "\ncloud_retire_seed=fract(sin(float(INSTANCE_ID)*12.9898+71.3)*43758.5453);\n")
			var retirement: String = "\nfloat retirement_start=cloud_retire_seed*.65;\nALPHA*=1.0-smoothstep(retirement_start,retirement_start+.35,cloud_retirement);\nfloat retirement_remaining=1.0-clamp(cloud_retirement,0.0,1.0);\nALPHA*=retirement_remaining*retirement_remaining*retirement_remaining;\n"
			shader.code = SourceMaterials.finish_fragment(shader.code, retirement)
			SourceMaterials.replace_shader(m, shader)
		# New uniforms are absent from the donor shader; duplicates can omit them.
		# Bind after installing the selected shader on every boundary material.
		m.set_shader_parameter("cloud_kind", kind)
		m.set_shader_parameter("cloud_radius", radius)
	for original in cloud.find_children("*", "GPUParticles3D", false, false):
		if not original.visible:
			continue
		original.one_shot = true
		original.restart(true)
		var second = original.duplicate() as GPUParticles3D
		second.name = str(original.name) + "_next_cohort"
		second.material_override = original.material_override
		second.preprocess = 0.0
		second.emitting = false
		cloud.add_child(second)
		var group: Array = [original, second]
		var cohort_count: int = int(settings.get("cohort_count", 2))
		if cohort_count > 2:
			var source_material: Material = original.material_override
			if source_material == null:
				source_material = original.draw_pass_1.material
			for index in cohort_count:
				var cohort: GPUParticles3D
				if index < 2:
					cohort = group[index]
				else:
					cohort = original.duplicate() as GPUParticles3D
					cohort.name = str(original.name) + "_staggered_" + str(index - 2)
					cohort.preprocess = 0.0
					cohort.emitting = false
					cloud.add_child(cohort)
					group.append(cohort)
				cohort.material_override = source_material.duplicate(true)
				mats.append(cohort.material_override)
		banks.append(group)


## Moving source noise can remain nonzero at a billboard's finite edge. Fade
## its carrier after the source alpha remap, without cutting the actual world
## field or changing the donor's texture, phase, palette or retirement clock.
func _feather_carrier(material: ShaderMaterial, feather_uv: float) -> void:
	assert(feather_uv > 0.0 and feather_uv < 0.5, "Cloud carrier feather must fit inside its UVs")
	var shader := Shader.new()
	shader.code = SourceMaterials.expand_shader(material.shader.code, material.shader.resource_path.get_base_dir())
	shader.code = shader.code.replace("shader_type spatial;", "shader_type spatial;\nuniform float cloud_carrier_feather_uv=0.12;")
	shader.code = SourceMaterials.finish_fragment(shader.code, "\nvec2 carrier_edge=min(UV,vec2(1.0)-UV);\nALPHA*=smoothstep(0.0,cloud_carrier_feather_uv,carrier_edge.x)*smoothstep(0.0,cloud_carrier_feather_uv,carrier_edge.y);\n")
	SourceMaterials.replace_shader(material, shader)
	material.set_shader_parameter("cloud_carrier_feather_uv", feather_uv)


func _replace_with_fire() -> void:
	for child in cloud.get_children():
		if child is Node3D:
			child.hide()
	mats.clear()
	var source = (
		VfxPackageIO_b7e4f5e433.resource(
			"res://assets/vfx/sources/b3d00490a497bf6bdabb/fire_08.tscn"
		)
		. instantiate()
	)
	var flame: GPUParticles3D = source.get_node("Flame").duplicate()
	cloud.add_child(flame)
	source.free()
	flame.sub_emitter = NodePath("")
	flame.amount = int(settings.get("fire_particle_amount", 480))
	flame.lifetime = 1.625
	flame.preprocess = 1.625
	flame.fixed_fps = 144
	flame.use_fixed_seed = true
	flame.seed = 4412
	flame.local_coords = true
	flame.position = Vector3(0, .25, 0)
	flame.visibility_aabb = AABB(Vector3(-5, -1, -5), Vector3(10, 7, 10))
	var pm = flame.process_material.duplicate(true)
	flame.process_material = pm
	pm.emission_sphere_radius = 3.3
	pm.emission_shape_scale = Vector3(1, .1, 1)
	pm.spread = 25.
	pm.initial_velocity_min = 1.3
	pm.initial_velocity_max = 2.5
	pm.scale_min = 1.0
	pm.scale_max = 1.65
	pm.sub_emitter_mode = 0
	var mesh = flame.draw_pass_1.duplicate(true)
	mesh.size = Vector2(1.8, 2.8)
	flame.draw_pass_1 = mesh
	var mat: ShaderMaterial = mesh.material.duplicate(true)
	mat.shader = VfxPackageIO_b7e4f5e433.resource(settings.get("fire_volume_shader", "res://assets/vfx/sources/a7e05a0ae1d036958f66/fire-volume.gdshader"))
	mesh.material = mat
	mats.append(mat)


func advance_lifecycle(_delta: float) -> void:
	if not is_instance_valid(cloud):
		return
	tick += 1
	if tick == 2:
		for pair in banks:
			pair[0].preprocess = 0.0
	var k: int = tick - 1
	var interval: int = int(settings.get("cohort_interval_ticks", 405))
	var cohort_count: int = int(settings.get("cohort_count", 2))
	var emission: int = k / interval
	if emission != last_emission:
		last_emission = emission
		for pair in banks:
			var part: GPUParticles3D = pair[(emission + 1) % cohort_count]
			part.restart(true)
			part.emitting = true
			if cohort_count > 2:
				for index in cohort_count:
					pair[index].material_override.render_priority = cohort_count - 1 - (((emission + 1) % cohort_count - index + cohort_count) % cohort_count)
	var age: float = maxf(0.0, float(tick) / float(parameters.simulation_hz) - float(settings.get("age_offset_seconds", 0.0)))
	var loop_ticks: int = int(settings.get("cloud_loop_ticks", 810))
	for material in mats:
		material.set_shader_parameter("cloud_clock", float(tick % loop_ticks) / float(parameters.simulation_hz))
		material.set_shader_parameter("cloud_age", age)
		material.set_shader_parameter("roll_weight", 0.0)
		material.set_shader_parameter("cloud_opacity", 1.0)
		if settings.has("retire_begin_seconds"):
			var retirement: float = clampf((age - float(settings.retire_begin_seconds)) / float(settings.retire_seconds), 0.0, 1.0)
			material.set_shader_parameter("cloud_retirement", retirement)

const VfxPackageIO_b7e4f5e433 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
