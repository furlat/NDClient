extends RefCounted
## Extract only an inspected source material. Geometry, owner clocks and output
## limits belong to the occurrence; a donor scene is never attached.
const SourceMaterials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
const EnergyPalette = preload("res://assets/vfx/sources/386bc581a35eb3b9ee50/spatial_energy_palette.gd")

static func make(input: Dictionary, finish: String) -> ShaderMaterial:
	var donor: Node = VfxPackageIO_77df0f04e1.resource(str(input.scene)).instantiate()
	# Overlay materials are a distinct source property in LeLu's weapon scenes.
	# Select it explicitly; never substitute another material when it is absent.
	var property_name: String = str(input.get("material_property", "material_override"))
	assert(property_name in ["material_override", "material_overlay"])
	var original: ShaderMaterial = donor.get_node(str(input.node)).get(property_name)
	assert(original != null, "Inspected weapon source material missing: " + str(input.scene))
	var material: ShaderMaterial = original.duplicate(true)
	var code := SourceMaterials.expand_shader(original.shader.code,original.shader.resource_path.get_base_dir())
	code = code.replace("TIME","owned_clock").replace("COLOR","owned_source_colour")
	code = code.replace("depth_draw_opaque","depth_draw_never").replace("cull_back","cull_disabled")
	var unshaded_mode := RegEx.new()
	unshaded_mode.compile("\\brender_mode\\b[^;]*\\bunshaded\\b")
	if bool(input.get("unshaded_output",false)) and unshaded_mode.search(code) == null:
		code = code.replace("render_mode ","render_mode unshaded, ")
	code = code.replace("instance uniform", "uniform")
	code = code.replace("shader_type spatial;","shader_type spatial;\nuniform float owned_clock=0.0;\nuniform float owned_envelope=0.0;\nuniform vec4 owned_source_colour=vec4(0.0,0.5,0.5,1.0);\n")
	code = SourceMaterials.finish_fragment(code,finish)
	var shader := Shader.new()
	shader.code = code
	SourceMaterials.replace_shader(material,shader)
	var carrier: Array = input.get("source_colour",[0.0,.5,.5,1.0])
	material.set_shader_parameter("owned_source_colour",Color(carrier[0],carrier[1],carrier[2],carrier[3]))
	for name in input.get("uniforms",{}):
		var value: Variant = input.uniforms[name]
		if value is Array and value.size() == 2:
			value = Vector2(value[0],value[1])
		elif value is Array and value.size() == 3:
			value = Vector3(value[0],value[1],value[2])
		elif value is Array and value.size() == 4:
			value = Color(value[0],value[1],value[2],value[3])
		elif value is String and value.begins_with("res://"):
			value = VfxPackageIO_77df0f04e1.resource(value)
		material.set_shader_parameter(name,value)
	EnergyPalette.apply(material,input.palette,{"quantize":false,"emission_gain":0.0,"energy_exposure":input.get("energy_exposure",1.0)})
	material.render_priority = 1
	donor.free()
	return material

const VfxPackageIO_77df0f04e1 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
