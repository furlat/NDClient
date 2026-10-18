extends RefCounted
## Native donor material, independent clock/visibility and explicit palette.
## No geometry, owner inference, gameplay timer or optical light lives here.
const SourceMaterials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
const MaterialValues = preload("res://assets/vfx/sources/601eb8db9c55b6ad084e/shader_material.gd")
const NativePalette = preload("res://assets/vfx/sources/386bc581a35eb3b9ee50/spatial_energy_palette.gd")

static func build(specification: Dictionary) -> ShaderMaterial:
	var original: ShaderMaterial
	if specification.has("resource"):
		original = VfxPackageIO_89da09bf4c.resource(specification.resource)
	else:
		var scene: PackedScene = VfxPackageIO_89da09bf4c.resource(specification.scene)
		var source := scene.instantiate()
		original = source.get_node(specification.node).material_override.duplicate(true)
		source.free()
	assert(original != null and original.shader != null)
	var material := original.duplicate(true) as ShaderMaterial
	var code: String = SourceMaterials.expand_shader(original.shader.code, original.shader.resource_path.get_base_dir())
	code = code.replace("TIME", "field_clock").replace("depth_draw_opaque", "depth_draw_never")
	if specification.get("cull_back", false):
		code = code.replace("cull_disabled", "cull_back")
	code = code.replace("shader_type spatial;", "shader_type spatial;\nuniform float field_clock=0.0;\nuniform float field_opacity=0.0;\n")
	if specification.get("local_ground_clip", false):
		code = code.replace("shader_type spatial;", "shader_type spatial;\nvarying float field_local_height;\n")
		if code.contains("void vertex()"):
			code = SourceMaterials.finish_function(code, "vertex", "\nfield_local_height=VERTEX.y;\n")
		else:
			code += "\nvoid vertex(){field_local_height=VERTEX.y;}\n"
		code = SourceMaterials.finish_fragment(code, "\nif(field_local_height<0.0)discard;\n")
	if specification.get("world_ground_clip", false):
		code = code.replace("shader_type spatial;", "shader_type spatial;\nvarying float field_world_height;\nuniform float field_ground_height=0.0;\n")
		if code.contains("void vertex()"):
			code = SourceMaterials.finish_function(code, "vertex", "\nfield_world_height=(MODEL_MATRIX*vec4(VERTEX,1.0)).y;\n")
		else:
			code += "\nvoid vertex(){field_world_height=(MODEL_MATRIX*vec4(VERTEX,1.0)).y;}\n"
		code = SourceMaterials.finish_fragment(code, "\nif(field_world_height<field_ground_height)discard;\n")
	code = SourceMaterials.stable_proximity(code)
	var shader := Shader.new()
	shader.code = SourceMaterials.finish_fragment(code, "\nALPHA*=field_opacity;\n")
	if specification.get("approved_force_surface", false):
		# Exact quiet line/rim colour and alpha base from the accepted native
		# force_construction.gd finish, without its wall-only borders, growth,
		# hemisphere discard or Disintegrate wave. The source overlay remains.
		assert(code.contains("float n_out48p0"))
		shader.code = shader.code.replace("texture(Overlay_Texture, n_out46p0)", "texture(Overlay_Texture, fract(n_out46p0))")
		shader.code = SourceMaterials.finish_fragment(shader.code, """
		float force_line=clamp(n_out48p0,0.0,1.0);
		float force_rim=pow(1.0-abs(dot(NORMAL,VIEW)),2.0);
		ALBEDO=mix(vec3(.07,.26,.49),vec3(.38,.67,1.0),max(force_line*.65,force_rim));
		ALPHA=(.065+.12*force_line+.10*force_rim)*field_opacity;
		""")
	if specification.has("body_opacity_floor"):
		shader.code = SourceMaterials.finish_fragment(shader.code, "\nALPHA=max(ALPHA,field_opacity*" + str(float(specification.body_opacity_floor)) + ");\n")
	SourceMaterials.replace_shader(material, shader)
	for name in specification.get("uniforms", {}):
		material.set_shader_parameter(name, MaterialValues.uniform_value(specification.uniforms[name]))
	if specification.has("palette"):
		NativePalette.apply(material, specification.palette, {"quantize": false, "emission_gain": 0.0})
	material.set_shader_parameter("field_clock", 0.0)
	material.set_shader_parameter("field_opacity", 0.0)
	return material

const VfxPackageIO_89da09bf4c = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
