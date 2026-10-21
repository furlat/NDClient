extends Node3D
## Shared recipient composition; no recorder, camera or file output.
const ResourceGraph = preload("res://assets/vfx/sources/1d02b6d800655ef86df2/resource_graph.gd")
const DonorScene = preload("res://assets/vfx/sources/7fb2e55699a318c2dafb/donor_scene.gd")
const NativeShaderBindings = preload("res://assets/vfx/extensions/source-preparation-20261020/sources/5d620fd9a64eea66a8cb/source_materials.gd")
const NativePalette = preload("res://assets/vfx/extensions/source-preparation-20261020/sources/a88cc0b6fd9f8a77e483/spatial_energy_palette.gd")
var settings: Dictionary
var side: String
var parameters: Dictionary
var subject: Node3D
var tick: int = 0
var materials: Array[ShaderMaterial] = []
var visited: Dictionary = {}
var initialized: bool = false
var prepared: bool = false
var seeds: Array = []


static func construct(script_path: String, input: Dictionary) -> Node3D:
	var instance: Node3D = VfxPackageIO_a4fd0883f0.resource(script_path).new()
	instance.parameters = input.duplicate(true)
	instance.settings = input.settings.duplicate(true)
	instance.side = input.side
	instance.subject = DonorScene.instantiate(
		VfxPackageIO_a4fd0883f0.resource(input.scene), input.get("disabled_script_paths", [])
	)
	if instance.subject == null:
		instance.free()
		return null
	instance.subject.name = "Donor"
	instance._isolate(instance.subject, {})
	instance.add_child(instance.subject)
	if input.get("preparation_stage", "after_ready") == "before_tree":
		instance.prepare_subject()
	return instance


func _isolate(node: Node, resources: Dictionary) -> void:
	ResourceGraph.isolate_node(node, resources)


func _apply_particle_seed(node: Node) -> void:
	var emitters: Array[Node] = node.find_children("*", "GPUParticles3D", true, false)
	if node is GPUParticles3D:
		emitters.append(node)
	for index in emitters.size():
		var emitter: GPUParticles3D = emitters[index]
		emitter.use_fixed_seed = true
		emitter.seed = int(parameters.seed) + index
		seeds.append({"path": str(get_path_to(emitter)), "seed": emitter.seed})


func prepare_subject() -> void:
	if prepared:
		return
	prepared = true
	_apply_particle_seed(subject)
	apply_scene_edits(subject)
	prepare_materials(subject)


func sample(seconds: float) -> void:
	if not initialized:
		initialized = true
		prepare_subject()
		var matched: bool = settings.animation.is_empty()
		for player in subject.find_children("*", "AnimationPlayer", true, false):
			if parameters.get("refresh_animation_caches", false):
				player.clear_caches()
			if settings.animation.is_empty():
				continue
			if player.has_animation(settings.animation):
				player.play(settings.animation)
				matched = true
			elif parameters.get("animation_missing_policy", "error") == "first_available":
				var clips: PackedStringArray = player.get_animation_list()
				if not clips.is_empty():
					player.play(clips[0])
					matched = true
		if not matched:
			push_error("Declared native animation missing from donor: " + settings.animation)
	var desired_tick: int = int(round(seconds * float(parameters.simulation_hz)))
	if parameters.get("lifecycle_sampling", "fixed_step") == "analytical" and tick < desired_tick:
		if not sample_analytical_tick(desired_tick) or tick != desired_tick:
			push_error("Invalid analytical source-clock contract: " + str(get_script().resource_path))
			return
	while tick < desired_tick:
		var previous_tick: int = tick
		advance_lifecycle(1.0 / float(parameters.simulation_hz))
		if tick <= previous_tick:
			push_error("Native lifecycle failed to advance: " + str(get_script().resource_path))
			return
	# Geometry follows current owner/socket data even when the source clock is
	# paused or samples the same tick twice. Simulation and placement differ.
	update_geometry()


func sample_analytical_tick(_desired_tick: int) -> bool:
	# Stateful source simulation keeps every step. Audited analytical leaves
	# override this hook, retaining their original integer clock quantization.
	return false


func update_geometry() -> void:
	pass


func capture_observation() -> Dictionary:
	return {"native_tick": tick, "seeded_emitters": seeds.size(), "materials": materials.size()}


func apply_scene_edits(_node: Node) -> void:
	pass


func prepare_materials(node: Node) -> void:
	for child in node.find_children("*", "", true, false):
		if child is GeometryInstance3D:
			if "distort" in String(child.name).to_lower():
				child.layers = 0
			if (
				child.material_override is ShaderMaterial
				and "hint_screen_texture" in child.material_override.shader.code
			):
				child.layers = 0
		for p in child.get_property_list():
			if int(p.usage) & PROPERTY_USAGE_STORAGE:
				var v = child.get(p.name)
				if v is Resource:
					recolor(v)
		if child is GeometryInstance3D and side == "back":
			var has_shader = child.material_override is ShaderMaterial
			if child is GPUParticles3D:
				for i in child.draw_passes:
					var mesh = child.get_draw_pass_mesh(i)
					if mesh:
						for j in mesh.get_surface_count():
							if mesh.surface_get_material(j) is ShaderMaterial:
								has_shader = true
			if not has_shader:
				child.layers = 0


func tint(c: Color) -> Color:
	if c.s < 0.08 or not settings.has("hue"):
		return c
	return Color.from_hsv(float(settings.hue), c.s * 0.85, c.v, c.a)


func recolor(r: Resource) -> void:
	if r == null or visited.has(r.get_instance_id()):
		return
	visited[r.get_instance_id()] = true
	for p in r.get_property_list():
		if not (int(p.usage) & PROPERTY_USAGE_STORAGE):
			continue
		var v = r.get(p.name)
		if v is Color:
			r.set(p.name, tint(v))
		elif v is PackedColorArray:
			var colors = PackedColorArray()
			for c in v:
				colors.append(tint(c))
			r.set(p.name, colors)
		elif v is Resource:
			recolor(v)
	if r is Mesh:
		for i in r.get_surface_count():
			recolor(r.surface_get_material(i))
	if r is ShaderMaterial:
		adapt_shader(r)


func expand_includes(code: String, base: String) -> String:
	var result = ""
	for line in code.split("\n"):
		if line.strip_edges().begins_with("#include"):
			var path = line.get_slice('"', 1)
			if not path.begins_with("res://"):
				path = base.path_join(path)
			result += (
				expand_includes(VfxPackageIO_a4fd0883f0.text(path), path.get_base_dir()) + "\n"
			)
		else:
			result += line + "\n"
	return result


func adapt_shader(mat: ShaderMaterial) -> void:
	var shader = Shader.new()
	var code: String = expand_includes(mat.shader.code, mat.shader.resource_path.get_base_dir())
	# The tiny floor seal used non-mipmapped alpha scissoring and wrote depth.
	# At recipient scale it became glitter and cut into overlapping floor waves.
	if settings.get("name", "") == "VFX_Healing_Area" and code.contains("uniform float Base_intensity"):
		code = code.replace("filter_linear;", "filter_linear_mipmap_anisotropic;")
		code = code.replace("depth_draw_opaque", "depth_draw_never")
		code = code.replace(
			"ALPHA_SCISSOR_THRESHOLD = n_out55p0;",
			"ALPHA *= smoothstep(n_out55p0, n_out55p0 + 0.08, n_out74p1);"
		)
	# Source-relative includes must resolve from the copied shader resource.
	code = code.replace("TIME", "support_clock")
	code = (
		code
		. replace(
			"shader_type spatial;",
			"shader_type spatial;\nuniform float support_clock=0.0;\nuniform float support_envelope=1.0;"
		)
	)
	var split = "<" if side == "front" else ">="
	var prefix = (
		"\nvec3 support_world=(INV_VIEW_MATRIX*vec4(VERTEX,1.0)).xyz;\nif(dot(support_world,vec3(0.70710678,0.0,0.70710678)) "
		+ split
		+ " 0.0) discard;\n"
	)
	if mat.get_meta("support_ground", false):
		prefix = "\ndiscard;\n" if side == "front" else "\n"
	if side == "full":
		prefix = ""
	else:
		prefix = prefix.replace(
			"vec3(0.70710678,0.0,0.70710678)", "vec3(%s,%s,%s)" % parameters.clip_normal
		)
	var regex = RegEx.new()
	regex.compile("void\\s+fragment\\s*\\(\\s*\\)\\s*\\{")
	var match0 = regex.search(code)
	if match0:
		var pos = match0.get_end()
		code = code.insert(pos, prefix)
		var depth = 1
		var end = pos + prefix.length()
		while end < code.length() and depth > 0:
			if code[end] == "{":
				depth += 1
			elif code[end] == "}":
				depth -= 1
			end += 1
		code = code.insert(end - 1, "\nALPHA *= support_envelope;\n")
	if parameters.get("material_family", "") == "healing" and settings.get("pack", "") == "binbun-statusfxfull":
		code = code.replace("pow((1.0 - abs(uv.y * 2.0 - 1.0) - 0.5) / 0.5, 0.2)", "pow(max((1.0 - abs(uv.y * 2.0 - 1.0) - 0.5) / 0.5, 0.0), 0.2)")
		# Keep donor noise and motion, but fill the body surface instead of retaining
		# only its overexposed speckled peaks at game size.
		if not settings.get("preserve_native_noise_density", false):
			code = code.replace("smoothstep(0.5, 0.8, value)", "smoothstep(0.25, 0.70, value)")
		mat.set_shader_parameter("primary_color", Color(0.85, 0.85, 0.85))
		mat.set_shader_parameter("secondary_color", Color(0.38, 0.38, 0.38))
		mat.set_shader_parameter("tertiary_color", Color(0.48, 0.48, 0.48))
		mat.set_shader_parameter("emission", 1.0)
		mat.set_shader_parameter("hue_variation", 0.0)
		mat.set_shader_parameter("proximity_fade", false)
	shader.code = code
	NativeShaderBindings.replace_shader(mat, shader)
	if parameters.has("native_palette"):
		NativePalette.apply(mat, parameters.native_palette)
	materials.append(mat)


func advance_lifecycle(_delta: float) -> void:
	if not is_instance_valid(subject):
		return
	tick += 1
	var age = float(tick) / 144.0
	var fade = float(settings.get("alphaGain", 1.0))
	if int(settings.close) > 0 and tick > int(settings.close):
		fade *= (
			1.0
			- smoothstep(float(settings.close) / 144.0, float(settings.frames - 12) / 144.0, age)
		)
	for mat in materials:
		mat.set_shader_parameter("support_clock", age)
		mat.set_shader_parameter("support_envelope", fade)
	if tick == int(settings.close):
		for particles in subject.find_children("*", "GPUParticles3D", true, false):
			particles.emitting = false
		for player in subject.find_children("*", "AnimationPlayer", true, false):
			for ending in ["close", "End"]:
				if player.has_animation(ending):
					player.play(ending)
					break

const VfxPackageIO_a4fd0883f0 = preload("res://assets/vfx/extensions/source-preparation-20261020/scoped_resource_io.gd")
