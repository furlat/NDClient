extends "res://assets/vfx/extensions/wall-child-v3-20261021/sources/0738ff2d24aa41b1b963/native_review_composition.gd"
## Private Wind-only correction of the inspected source-position roundtrip.
const ShaderBindings = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
const ORIGINAL_RETURN := "VERTEX=(inverse(MODEL_MATRIX)*vec4(wp,1.0)).xyz;"
const CORRECTED_RETURN := "VERTEX=(inverse(MODEL_MATRIX)*inverse(factory_world_to_source)*vec4(wp,1.0)).xyz;"
const SOURCE_POSITION := "vec3 wp=(factory_world_to_source * MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;"
var roundtrip_prepared := false
var corrected_materials := 0

static func make_component(input: Dictionary) -> Node3D:
	var node := VfxPackageIO_3e50ff948f.resource("res://assets/vfx/extensions/wall-child-v3-20261021/sources/3e50ff948fb18da9b909/wind_wall_composition.gd").new() as Node3D
	node.definition = input.duplicate(true)
	return node

static func corrected_code(code: String) -> String:
	# Match only Wind's known deformation, after the shared forward conversion.
	# Other inverse uses (billboards, view rays, normals) are not this roundtrip.
	if code.count(ORIGINAL_RETURN) != 1 or not code.contains(SOURCE_POSITION):
		return ""
	if not code.contains("float near_body=") or not code.contains("uniform float wind_clock="):
		return ""
	return code.replace(ORIGINAL_RETURN, CORRECTED_RETURN)

func sample(seconds: float) -> void:
	super.sample(seconds)
	if not adapted or roundtrip_prepared:
		return
	roundtrip_prepared = true
	for material: ShaderMaterial in source_materials:
		var code := corrected_code(material.shader.code)
		if code.is_empty():
			continue
		var shader := Shader.new()
		shader.code = code
		ShaderBindings.replace_shader(material, shader)
		corrected_materials += 1
	if corrected_materials == 0:
		set_meta("native_construction_error", "Private Wind source roundtrip was not found")
		push_error("Private Wind source roundtrip was not found")

const VfxPackageIO_3e50ff948f = preload("res://assets/vfx/extensions/wall-child-v3-20261021/scoped_resource_io.gd")
