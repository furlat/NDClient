extends "res://assets/vfx/sources/048e2881b9068776f055/clocked_source.gd"
## Accepted LeLu flamethrower construction; the shared stage owns capture/cameras.
var breath_materials: Array[ShaderMaterial] = []

static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/e92e35dad9736cc32c30/native_fire_breath.gd", input)

static func inject_end(code: String, function_name: String, addition: String) -> String:
	var begin: int = code.find(function_name)
	assert(begin >= 0, "Declared donor shader function is missing")
	var brace: int = code.find("{", begin)
	var depth: int = 0
	for index in range(brace, code.length()):
		if code[index] == "{":
			depth += 1
		elif code[index] == "}":
			depth -= 1
			if depth == 0:
				return code.substr(0, index) + addition + code.substr(index)
	assert(false, "Unclosed donor shader function")
	return code

static func warm_ramp() -> GradientTexture1D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.12, 0.35, 0.65, 0.85, 1.0])
	gradient.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0.13, 0.018, 0.004, 0.2), Color(0.55, 0.07, 0.005, 0.75), Color(1.4, 0.26, 0.018, 1), Color(2, 0.85, 0.075, 1), Color(2, 1.5, 0.3, 1)])
	var texture := GradientTexture1D.new()
	texture.gradient = gradient
	texture.use_hdr = true
	return texture

func clip_shader(material: ShaderMaterial, direction: Vector2, cone: bool) -> void:
	var shader := Shader.new()
	var code: String = SourceMaterials.expand_shader(material.shader.code, material.shader.resource_path.get_base_dir())
	code = code.replace("shader_type spatial;", "shader_type spatial;\nvarying vec3 breath_world;\nuniform vec3 breath_origin=vec3(0.0);\nuniform vec2 breath_direction;\nuniform float breath_range;\nuniform bool breath_cone;\n")
	if code.contains("void vertex"):
		code = inject_end(code, "void vertex", "\nbreath_world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;\n")
	else:
		code += "\nvoid vertex(){breath_world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}\n"
	var start: String = "void fragment() {\nvec3 relative_breath=breath_world-breath_origin;float a=dot(relative_breath.xz,breath_direction);float s=abs(dot(relative_breath.xz,vec2(-breath_direction.y,breath_direction.x)));float width=breath_cone?max(.05,a*.5):.5;if(a<-.025||a>breath_range||s>width){discard;}float tail=(breath_cone?.32:.25)+.065*sin(relative_breath.y*7.+UV.y*5.);float breath_cover=(1.-smoothstep(breath_range-tail,breath_range,a))*(1.-smoothstep(max(.005,width-.03),width,s));\n"
	assert(code.contains("void fragment() {"))
	code = code.replace("void fragment() {", start)
	code = inject_end(code, "void fragment", "\nALPHA *= breath_cover;\n")
	shader.code = code
	SourceMaterials.replace_shader(material, shader)
	material.set_shader_parameter("breath_direction", direction)
	material.set_shader_parameter("breath_range", float(settings.range_units))
	material.set_shader_parameter("breath_cone", cone)
	breath_materials.append(material)

func apply_scene_edits(node: Node) -> void:
	var cone: bool = settings.shape == "cone"
	var angle: float = float(settings.heading) * PI / 4.0 - PI / 4.0
	var direction := Vector2(cos(angle), sin(angle))
	node.scale.y = 0.866025403784
	node.look_at(node.global_position + Vector3(direction.x, 0, direction.y))
	node.get_node("AnimationPlayer").stop()
	for part in node.find_children("*", "GPUParticles3D", true, false):
		if part.name in ["distortion_hit", "VFX_sub_fireB"]:
			part.visible = false
			part.emitting = false
			continue
		part.local_coords = true
		part.fixed_fps = 32
		part.use_fixed_seed = true
		part.seed = 4173
		part.preprocess = 0.0
		part.one_shot = false
		part.emitting = false
		part.lifetime = 0.58
		part.process_material = part.process_material.duplicate(true)
		var process: ParticleProcessMaterial = part.process_material
		if part.name == "fire":
			process.initial_velocity_min = 5.5 if cone else 9.0
			process.initial_velocity_max = 7.0 if cone else 12.0
			process.spread = 19.0 if cone else 3.29
			process.scale_min = 0.36 if cone else 0.30
			process.scale_max = 0.54 if cone else 0.42
			part.amount = 78
		elif part.name == "sparks5":
			process.color_ramp = warm_ramp()
			process.scale_min = 0.55
			process.scale_max = 0.8
			part.amount = 45
			process.initial_velocity_min = 4.5 if cone else 7.0
			process.initial_velocity_max = 7.0 if cone else 10.0
		if part.material_override is ShaderMaterial:
			part.material_override = part.material_override.duplicate(true)
			part.material_override.set_shader_parameter("gradient_1d_texture", warm_ramp())
			clip_shader(part.material_override, direction, cone)
		part.restart()
		part.emitting = true

func advance_lifecycle(delta: float) -> void:
	super.advance_lifecycle(delta)
	if tick == int(settings.stop_tick):
		for part in subject.find_children("*", "GPUParticles3D", true, false):
			part.emitting = false
