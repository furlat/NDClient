extends RefCounted
## The prepared original uses an occurrence-pool clock. This NEW hold source
## owns an explicit absolute clock instead; no mutable pool texture is retained.
const Sources = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
const ABSOLUTE := "item_flame_absolute_seconds"
const POOL_HEADER := "global uniform sampler2D vfx_package_clock;\nuniform int vfx_package_clock_slot=0;\nfloat vfx_package_seconds(){return texelFetch(vfx_package_clock,ivec2(vfx_package_clock_slot,0),0).r;}"
const OWNED_HEADER := "uniform float item_flame_absolute_seconds=0.0;\nfloat vfx_package_seconds(){return item_flame_absolute_seconds;}"


static func local_material(original: ShaderMaterial) -> ShaderMaterial:
	var code: String = original.shader.code
	assert(code.count(POOL_HEADER) == 1, "Only the exact original generated clock interface is admitted")
	var offsets := RegEx.new()
	offsets.compile("uniform float (vfx_package_offset_\\w+)=0.0;")
	var actual_offsets: Array[String] = []
	for found: RegExMatch in offsets.search_all(code):
		var name: String = found.get_string(1)
		var value: Variant = original.get_shader_parameter(name)
		assert(value == null or ((value is float or value is int) and float(value) == 0.0),
			"This source's absolute support clock has no authored nonzero phase offset")
		actual_offsets.append(name)
	assert(actual_offsets.has("vfx_package_offset_support_age"))
	assert(actual_offsets.has("vfx_package_offset_support_clock"))
	var result: ShaderMaterial = original.duplicate(false)
	var shader := Shader.new()
	shader.code = code.replace(POOL_HEADER, OWNED_HEADER)
	Sources.replace_shader(result, shader)
	result.set_shader_parameter("vfx_package_clock_slot", null)
	result.set_shader_parameter(ABSOLUTE, 0.0)
	result.set_meta("factory_prepared_shader", shader)
	result.set_meta("factory_opacity_prepared_shader", shader)
	result.set_meta("factory_clock_names", [])
	result.set_meta("factory_clock_pool_required", false)
	result.set_meta("flame_hold_original_shader_sha256", code.sha256_text())
	assert(not shader.code.contains("global uniform sampler2D vfx_package_clock"))
	assert(not shader.code.contains("vfx_package_clock_slot"))
	assert(shader.code.replace(OWNED_HEADER, POOL_HEADER) == code,
		"Native source expressions, source finish and offset reads remain byte-identical")
	return result
