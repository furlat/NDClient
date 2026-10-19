extends RefCounted
## One texel per occurrence; one texture upload per rendered frame. Components
## may retain authored local time uniforms; offsets preserve those exact values.
const SourceMaterials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
const CAPACITY := 2048
static var image: Image
static var texture: ImageTexture
static var free_slots: Array[int] = []
static var dirty := false
static var programs: Dictionary = {}
var slot := -1
var bindings: Array = []
var seen_materials: Dictionary = {}


static func ensure_pool() -> void:
	if image != null:
		return
	image = Image.create_empty(CAPACITY, 1, false, Image.FORMAT_RGBAF)
	texture = ImageTexture.create_from_image(image)
	for index in CAPACITY:
		free_slots.append(CAPACITY - index - 1)
	# A receiving project may already declare this sampler in shader_globals.
	# Registering it twice is an error even before the first source is drawn.
	if ProjectSettings.has_setting("shader_globals/vfx_package_clock"):
		RenderingServer.global_shader_parameter_set("vfx_package_clock", texture)
	else:
		RenderingServer.global_shader_parameter_add("vfx_package_clock", RenderingServer.GLOBAL_VAR_TYPE_SAMPLER2D, texture)
	RenderingServer.frame_pre_draw.connect(flush)


static func flush() -> void:
	if dirty:
		texture.update(image)
		dirty = false


func prepare(materials: Array) -> void:
	ensure_pool()
	if slot < 0:
		assert(not free_slots.is_empty(), "VFX occurrence clock capacity exceeded")
		slot = free_slots.pop_back()
		image.set_pixel(slot, 0, Color(0.0, 0.0, 0.0, 0.0))
		dirty = true
	for material in materials:
		if not material is ShaderMaterial or material.shader == null:
			continue
		if seen_materials.get(material) == material.shader:
			continue
		bindings = bindings.filter(func(binding: Dictionary) -> bool: return binding.material != material)
		if material.has_meta("factory_prepared_shader") and material.get_meta("factory_prepared_shader") == material.shader:
			var prepared_names: Array = material.get_meta("factory_clock_names", [])
			seen_materials[material] = material.shader
			if not prepared_names.is_empty() or material.shader.code.contains("float vfx_package_seconds()"):
				material.set_shader_parameter("vfx_package_clock_slot", slot)
				bindings.append({"material": material, "names": prepared_names, "offsets": {}})
			continue
		var code: String = material.shader.code
		if code.contains("float vfx_package_seconds()"):
			var wrapped_names := []
			var offsets := RegEx.new()
			offsets.compile("uniform\\s+float\\s+vfx_package_offset_(\\w+)")
			for match_value in offsets.search_all(code):
				wrapped_names.append(match_value.get_string(1))
			material.set_shader_parameter("vfx_package_clock_slot", slot)
			seen_materials[material] = material.shader
			bindings.append({"material": material, "names": wrapped_names, "offsets": {}})
			continue
		var time_pattern := RegEx.new()
		time_pattern.compile("\\bTIME\\b")
		var declaration := RegEx.new()
		declaration.compile("uniform\\s+(?:(?:lowp|mediump|highp)\\s+)?float\\s+(\\w*_(?:age|time|seconds|clock)|clock|age|time|elapsed|progress|phase|u_time)\\b[^;]*;")
		var names := []
		for match_value in declaration.search_all(code):
			names.append(match_value.get_string(1))
		if names.is_empty() and time_pattern.search(code) == null:
			seen_materials[material] = material.shader
			continue
		code = time_pattern.sub(code, "vfx_package_seconds()", true)
		var prefix := "\nglobal uniform sampler2D vfx_package_clock;\nuniform int vfx_package_clock_slot=0;\nfloat vfx_package_seconds(){return texelFetch(vfx_package_clock,ivec2(vfx_package_clock_slot,0),0).r;}\n"
		for name in names:
			prefix += "uniform float vfx_package_offset_" + name + "=0.0;\n"
			# Keep the original uniform accessible to the source controller, but
			# all shader reads use the occurrence's texel plus its authored offset.
			var token := RegEx.new()
			token.compile("\\b" + name + "\\b")
			var original_declaration: String = ""
			for match_value in declaration.search_all(code):
				if match_value.get_string(1) == name:
					original_declaration = match_value.get_string()
					break
			code = code.replace(original_declaration, "__VFX_TIME_DECLARATION__")
			code = token.sub(code, "(vfx_package_seconds()+vfx_package_offset_" + name + ")", true)
			code = code.replace("__VFX_TIME_DECLARATION__", original_declaration)
		var at := code.find(";") + 1
		code = code.insert(at, prefix)
		if not programs.has(code):
			var shader := Shader.new()
			shader.code = code
			programs[code] = shader
		SourceMaterials.replace_shader(material, programs[code])
		seen_materials[material] = material.shader
		material.set_shader_parameter("vfx_package_clock_slot", slot)
		bindings.append({"material": material, "names": names, "offsets": {}})


func sample(seconds: float) -> void:
	image.set_pixel(slot, 0, Color(seconds, 0.0, 0.0, 0.0))
	dirty = true
	for binding in bindings:
		for name in binding.names:
			var value: Variant = binding.material.get_shader_parameter(name)
			if value is float or value is int:
				var offset: float = float(value) - seconds
				if not is_equal_approx(float(binding.offsets.get(name, INF)), offset):
					binding.material.set_shader_parameter("vfx_package_offset_" + name, offset)
					binding.offsets[name] = offset


func retain_materials(materials: Array) -> void:
	bindings = bindings.filter(func(binding: Dictionary) -> bool: return binding.material in materials)
	for material in seen_materials.keys():
		if material not in materials:
			seen_materials.erase(material)


func release() -> void:
	if slot >= 0:
		free_slots.append(slot)
		slot = -1
