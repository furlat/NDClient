extends RefCounted
## Source-only material extraction for the three actual on-hit smites. Default
## graph textures survive derivative creation; no source scene is made visible.
const SourceMaterials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
const EnergyPalette = preload("res://assets/vfx/sources/386bc581a35eb3b9ee50/spatial_energy_palette.gd")
const Immutable = preload("res://assets/vfx/sources/c1e0733a7ef81c657ab9/immutable_materials.gd")

static func make(input: Dictionary, motif: String, finish: String) -> ShaderMaterial:
	var recipe := [input, motif, finish]
	var prepared := Immutable.take("smite", recipe)
	if prepared != null:
		return prepared
	var original: ShaderMaterial
	var donor: Node
	if input.has("scene"):
		donor = VfxPackageIO_e0cbef75c1.resource(str(input.scene)).instantiate()
		original = donor.get_node(str(input.node)).material_override
	else:
		original = ShaderMaterial.new()
		original.shader = VfxPackageIO_e0cbef75c1.resource(str(input.shader))
	var material: ShaderMaterial = original.duplicate(true)
	var code := SourceMaterials.expand_shader(original.shader.code,original.shader.resource_path.get_base_dir())
	code = code.replace("TIME","smite_clock")
	# Particle COLOR was an explicit carrier in these inspected graphs. A native
	# ribbon supplies the selected carrier directly instead of inheriting white
	# defaults that would clamp the original scrolling mask outside its domain.
	code = code.replace("COLOR", "smite_source_colour")
	code = code.replace("depth_draw_opaque","depth_draw_never").replace("cull_back","cull_disabled")
	# TypeA7's source is also a shadow catcher. That mode consumes fragment alpha
	# after the shader in the isolated native effect pass and made all Searing
	# pixels empty in v63. Opt out only for that explicitly selected derivative.
	if bool(input.get("remove_shadow_catcher",false)):
		code = code.replace(", shadow_to_opacity", "")
	# Inspected fire and windflow sources use particle billboards. These native
	# ribbon/measured vertices already own their geometry and must retain it.
	var vertex := code.find("void vertex()")
	var fragment := code.find("void fragment()")
	if vertex >= 0 and fragment > vertex:
		code = code.substr(0,vertex) + "void vertex() {}\n" + code.substr(fragment)
	code = code.replace("shader_type spatial;","shader_type spatial;\nuniform float smite_clock=0.0;\nuniform float smite_envelope=0.0;\nuniform vec4 smite_source_colour=vec4(1.0);\n"+motif)
	code = SourceMaterials.finish_fragment(code,finish)
	var shader := Shader.new()
	shader.code = code
	SourceMaterials.replace_shader(material,shader)
	var carrier: Array = input.get("source_colour",[1.0,1.0,1.0,1.0])
	material.set_shader_parameter("smite_source_colour",Color(carrier[0],carrier[1],carrier[2],carrier[3]))
	for name in input.get("uniforms",{}):
		var value: Variant = input.uniforms[name]
		if value is Array and value.size() == 2:
			value = Vector2(value[0],value[1])
		elif value is Array and value.size() == 4:
			value = Color(value[0],value[1],value[2],value[3])
		elif value is String and value.begins_with("res://"):
			value = VfxPackageIO_e0cbef75c1.resource(value)
		material.set_shader_parameter(name,value)
	EnergyPalette.apply(material,input.palette,{"quantize":false,"emission_gain":0.0})
	material.render_priority = 1
	if donor != null:
		donor.free()
	return Immutable.capture("smite", recipe, material)

const VfxPackageIO_e0cbef75c1 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
