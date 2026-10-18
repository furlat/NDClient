extends RefCounted
## Local material extraction for two authored projectile candidates.
## Source shaders, samplers and mask math survive; instances own clock/alpha.
const Graph = preload("res://assets/vfx/sources/1d02b6d800655ef86df2/resource_graph.gd")
const SourceMaterials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
const Palette = preload("res://assets/vfx/sources/386bc581a35eb3b9ee50/spatial_energy_palette.gd")


static func extract(original: ShaderMaterial, colors: Array, gain: float) -> ShaderMaterial:
	assert(original != null and original.shader != null, "Native projectile material is missing")
	var material: ShaderMaterial = Graph.clone_value(original, {})
	var code: String = SourceMaterials.expand_shader(original.shader.code, original.shader.resource_path.get_base_dir())
	var token := RegEx.new()
	token.compile("\\bTIME\\b")
	code = token.sub(code, "projectile_clock_seconds", true)
	code = code.replace("shader_type spatial;", "shader_type spatial;\nuniform float projectile_clock_seconds=0.0;\nuniform float projectile_envelope=0.0;")
	code = SourceMaterials.finish_fragment(code, "\nALPHA *= projectile_envelope;\n")
	var shader := Shader.new()
	shader.code = code
	SourceMaterials.replace_shader(material, shader)
	Palette.apply(material, colors, {"quantize": false, "emission_gain": gain})
	return material


static func load_selected(path: String, colors: Array, gain: float) -> ShaderMaterial:
	var original: ShaderMaterial = VfxPackageIO_0f15a3f72a.resource(path)
	return extract(original, colors, gain)


static func draw(parent: Node3D, label: String, mesh: Mesh, material: ShaderMaterial) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.mesh = mesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.hide()
	parent.add_child(instance)
	return instance


static func clock(material: ShaderMaterial, seconds: float, envelope: float) -> void:
	material.set_shader_parameter("projectile_clock_seconds", seconds)
	material.set_shader_parameter("projectile_envelope", clampf(envelope, 0.0, 1.0))

const VfxPackageIO_0f15a3f72a = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
