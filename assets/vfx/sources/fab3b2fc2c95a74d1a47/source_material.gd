extends RefCounted
## Original native fragment mechanisms on new spatial geometry. No donor scene
## controller, particle layout, light, palette pass or shared material mutation.
const SourceMaterials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
const Values = preload("res://assets/vfx/sources/601eb8db9c55b6ad084e/shader_material.gd")


static func make(specification: Dictionary) -> ShaderMaterial:
	var material: ShaderMaterial
	if specification.has("scene"):
		var donor: Node = VfxPackageIO_fab3b2fc2c.resource(specification.scene).instantiate()
		var original: ShaderMaterial = donor.get_node(specification.node).material_override
		assert(original != null, "Selected support source needs its original native material")
		material = original.duplicate(true)
		donor.free()
	else:
		material = ShaderMaterial.new()
		material.shader = VfxPackageIO_fab3b2fc2c.resource(specification.shader)
	var code := SourceMaterials.expand_shader(material.shader.code, material.shader.resource_path.get_base_dir())
	code = code.replace("TIME", "support_clock")
	if specification.get("fragment_uv_swap",false):
		# The donor rune band's U follows its circumference. On our ribbon,
		# authored path length is V; preserve the native along-band motion.
		code = code.replace("UV.x","support_uv.x").replace("UV.y","support_uv.y")
		code = code.replace("void fragment() {","void fragment() {\nvec2 support_uv=UV.yx;")
	if specification.has("fragment_uv_scale"):
		var scale: Array = specification.fragment_uv_scale
		var uv_token: RegEx = RegEx.new()
		uv_token.compile("\\bUV\\b")
		code = uv_token.sub(code,"support_shape_uv",true)
		code = code.replace("void fragment() {","void fragment() {\nvec2 support_shape_uv=(UV-vec2(.5))*vec2("+str(float(scale[0]))+","+str(float(scale[1]))+")+vec2(.5);")
	code = code.replace("blend_add", "blend_mix").replace("cull_back", "cull_disabled")
	code = code.replace("depth_draw_never", "depth_draw_opaque")
	if specification.has("spatial_vertex"):
		var begin := code.find("void vertex()")
		var end := code.find("void fragment()")
		assert(begin >= 0 and end > begin, "Selected billboard source requires explicit spatial vertex adaptation")
		code = code.substr(0, begin) + str(specification.spatial_vertex) + "\n" + code.substr(end)
	assert(not code.contains("MODELVIEW_MATRIX ="), "Support geometry must remain in actual world space")
	code = SourceMaterials.stable_proximity(code)
	code = code.replace("shader_type spatial;", "shader_type spatial;\nuniform float support_clock=0.0;\nuniform float support_envelope=0.0;\nuniform float support_visibility=1.0;\n")
	var finish := "\n"
	if specification.has("alpha_floor"):
		# A quiet continuous band supports the original sparse runes. Across-
		# ribbon softness and the mesh's tapered ends retain the open lens.
		finish += "ALPHA=max(ALPHA," + str(float(specification.alpha_floor)) + "*pow(max(0.0,1.0-abs(UV.x*2.0-1.0)),.65));\n"
	finish += "ALPHA=clamp(ALPHA,0.0,1.0)*support_envelope*support_visibility*" + str(float(specification.alpha)) + ";\n"
	finish += "ALBEDO*=" + str(float(specification.get("albedo_gain", 1.0))) + ";\n"
	finish += "EMISSION*=" + str(float(specification.get("emission_gain", 0.0))) + ";\n"
	var shader := Shader.new()
	shader.code = SourceMaterials.finish_fragment(code, finish)
	SourceMaterials.replace_shader(material, shader)
	for key in specification.get("uniforms", {}):
		material.set_shader_parameter(key, Values.uniform_value(specification.uniforms[key]))
	for key in specification.get("textures", {}):
		material.set_shader_parameter(key, VfxPackageIO_fab3b2fc2c.resource(str(specification.textures[key])))
	material.set_meta("high_level_support_source", specification.duplicate(true))
	return material

const VfxPackageIO_fab3b2fc2c = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
