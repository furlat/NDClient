extends Node3D
## Offline native material extraction for current measured recipient surfaces.
## Runtime geometry, owner clock and fade use the existing measured adapter.
const SourceMaterials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
const MaterialValues = preload("res://assets/vfx/sources/601eb8db9c55b6ad084e/shader_material.gd")
const Palette = preload("res://assets/vfx/sources/386bc581a35eb3b9ee50/spatial_energy_palette.gd")
var retained_material: ShaderMaterial


static func make_component(input: Dictionary) -> Node3D:
	var source: ShaderMaterial
	var donor: Node
	if input.has("material_definition"):
		source = MaterialValues.build(input.material_definition)
	elif input.has("source_scene"):
		donor = VfxPackageIO_c7903100e8.resource(input.source_scene).instantiate()
		var selected: GeometryInstance3D = donor.get_node(input.source_node)
		source = selected.material_override
	else:
		source = VfxPackageIO_c7903100e8.resource(input.source_material)
	assert(source != null and source.shader != null, "Explicit native material is required")
	var material: ShaderMaterial = source.duplicate(false)
	var code := SourceMaterials.expand_shader(source.shader.code, source.shader.resource_path.get_base_dir())
	if input.has("native_vertex_colour"):
		# Measured support owns its COLOR border metadata. Preserve the actual
		# donor's independent particle carrier before that vertex stage is added.
		var colour_token := RegEx.new()
		colour_token.compile("\\bCOLOR\\b")
		code = colour_token.sub(code, "recipient_native_colour", true)
		code = code.replace("shader_type spatial;", "shader_type spatial;\nuniform vec4 recipient_native_colour=vec4(1.0);\n")
	for replacement: Dictionary in input.get("source_code_replacements", []):
		assert(code.count(replacement.from) == 1, "Declared native extraction seam changed")
		code = code.replace(replacement.from, replacement.to)
	if input.get("source_vertex_policy", "retain") == "measured_support_only":
		var vertex := RegEx.new()
		vertex.compile("void\\s+vertex\\s*\\(\\s*\\)\\s*\\{")
		var opening := vertex.search(code)
		if opening != null:
			var closing := opening.get_end()
			var depth := 1
			while depth > 0:
				if code[closing] == "{":
					depth += 1
				elif code[closing] == "}":
					depth -= 1
				closing += 1
			code = code.substr(0, opening.get_start()) + code.substr(closing)
	# A static sampled source pattern closes exactly. The owner drives a small
	# four-second exposure breath without resetting its source or actor pose.
	var time_token := RegEx.new()
	time_token.compile("\\bTIME\\b")
	var source_time := "%.9f" % float(input.source_snapshot_seconds)
	if float(input.get("source_flow_span_seconds", 0.0)) > 0.0:
		source_time = "(%.9f+%.9f*sin(owned_clock*1.5707963267948966))" % [float(input.source_snapshot_seconds), float(input.source_flow_span_seconds)]
	code = time_token.sub(code, source_time, true)
	if not code.contains("uniform float owned_clock"):
		code = code.replace("shader_type spatial;", "shader_type spatial;\nuniform float owned_clock=0.;\n")
	code = code.replace("depth_draw_opaque", "depth_draw_never")
	if not str(input.get("source_fragment_finish", "")).is_empty():
		code = SourceMaterials.finish_fragment(code, str(input.source_fragment_finish))
	var gain_finish := "\nfloat recipient_native_gain=%.9f*(.94+.06*cos(owned_clock*1.5707963267948966));\nALPHA *= recipient_native_gain;\n" % float(input.alpha_gain)
	if code.contains("ALPHA_SCISSOR_THRESHOLD"):
		# Preserve the donor's coverage decision when lowering its exposure.
		# Scaling only alpha made quiet physical/psychic sources disappear.
		gain_finish += "ALPHA_SCISSOR_THRESHOLD *= recipient_native_gain;\n"
	code = SourceMaterials.finish_fragment(code, gain_finish)
	var shader := Shader.new()
	shader.code = code
	SourceMaterials.replace_shader(material, shader)
	if input.has("native_vertex_colour"):
		var colour: Array = input.native_vertex_colour
		assert(colour.size() == 4)
		material.set_shader_parameter("recipient_native_colour", Vector4(colour[0], colour[1], colour[2], colour[3]))
	for parameter: String in input.get("uniforms", {}):
		material.set_shader_parameter(parameter, MaterialValues.uniform_value(input.uniforms[parameter]))
	if not input.get("palette", []).is_empty():
		Palette.apply(material, input.palette, {"quantize": false, "emission_gain": input.get("emission_gain", .08)})
	var root: Node3D = VfxPackageIO_c7903100e8.resource("res://assets/vfx/sources/c7903100e89e7c78c542/native_material_receiver.gd").new()
	root.retained_material = material
	material.set_meta("condition_fade_scissor",true)
	var draw := MeshInstance3D.new()
	draw.name = "NativeReceivingMaterial"
	draw.mesh = QuadMesh.new()
	draw.material_override = material
	draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(draw)
	if donor != null:
		donor.free()
	return root


func sample(seconds: float) -> void:
	retained_material.set_shader_parameter("owned_clock", seconds)

const VfxPackageIO_c7903100e8 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
