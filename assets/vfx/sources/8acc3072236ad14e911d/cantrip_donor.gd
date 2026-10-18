extends "res://assets/vfx/sources/e212c77ca5bf64639ea0/base.gd"
## Native source authoring; shared stage, process clock, palette and capture.
const SourceMaterials = preload("res://assets/vfx/sources/5f45d57a61f8be02c69c/source_materials.gd")


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/8acc3072236ad14e911d/cantrip_donor.gd", input)


func prepare_materials(_node: Node) -> void:
	pass


var source: Node


func apply_scene_edits(node: Node) -> void:
	source = node
	if settings.kind == "sacred_flame":
		pass
		node.scale = Vector3(0.62, 1.25, 0.62)
		node.position.y = -1.4
		for name in ["Ground", "Glow", "Pillar_03", "Light"]:
			node.get_node(name).visible = false
	if settings.kind == "shocking_grasp":
		node.scale = Vector3(1.3, 2.1, 1.3)
		node.get_node("sparks3").amount = 16
		var sparks = node.get_node("sparks3")
		var electric = sparks.process_material.duplicate(true)
		electric.color = Color.WHITE
		var gradient = Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
		gradient.colors = PackedColorArray(
			[Color(0.3, 0.9, 2.5), Color(3.0, 2.7, 0.12), Color(3.0, 2.7, 0.12)]
		)
		gradient.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
		var ramp = GradientTexture1D.new()
		ramp.gradient = gradient
		ramp.use_hdr = true
		electric.color_initial_ramp = ramp
		sparks.process_material = electric
		node.get_node("sparks3").explosiveness = 0.1
	if settings.kind == "poison_spray":
		node.get_node("acidcone").visible = false
		var puff = node.get_node("VFX_Smoke_A15")
		var pm = puff.process_material.duplicate(true)
		pm.initial_velocity_min = 6.0
		pm.initial_velocity_max = 7.0
		pm.spread = 12.0
		puff.process_material = pm
		puff.amount = 12
	for child in node.find_children("*", "GeometryInstance3D", true, false):
		if child.material_override is ShaderMaterial:
			var mat: ShaderMaterial = child.material_override.duplicate(true)
			var shader := Shader.new()
			var code: String = mat.shader.code

			code = code.replace("TIME", "source_clock")
			code = code.replace(
				"shader_type spatial;", "shader_type spatial;\nuniform float source_clock=0.0;"
			)
			if side != "full":
				var sign = "<" if side == "front" else ">="
				var clip = (
					"\nvec3 split_world=(INV_VIEW_MATRIX*vec4(VERTEX,1.0)).xyz;\nif (dot(split_world,vec3(0.70710678,0.0,0.70710678)) "
					+ sign
					+ " 0.0) discard;\n"
				)
				code = code.replace("void fragment() {", "void fragment() {" + clip)
			if settings.kind == "shocking_grasp":
				code = code.replace("ALPHA = n_out4p0;", "ALPHA = min(1.0, n_out4p0 * 2.2);")
			code = SourceMaterials.expand_shader(code, mat.shader.resource_path.get_base_dir())
			shader.code = code
			mat.shader = shader
			if settings.kind == "sacred_flame":
				mat.set_shader_parameter("emission_strength", 1.25)
				for key in ["mask2_scroll", "mask3_scroll"]:
					var scroll = mat.get_shader_parameter(key)
					if scroll is Vector2:
						mat.set_shader_parameter(key, Vector2(scroll.x, -abs(scroll.y)))
			child.material_override = mat
			materials.append(mat)


func advance_lifecycle(_delta: float) -> void:
	if not is_instance_valid(source):
		return
	tick += 1
	for mat in materials:
		mat.set_shader_parameter("source_clock", float(tick) / float(parameters.simulation_hz))
	if settings.kind == "poison_spray" and tick == 45:
		for p in source.find_children("*", "AnimationPlayer", true, false):
			p.play("End")
	if settings.kind == "shocking_grasp" and tick == 180:
		for p in source.find_children("*", "GPUParticles3D", true, false):
			p.emitting = false
