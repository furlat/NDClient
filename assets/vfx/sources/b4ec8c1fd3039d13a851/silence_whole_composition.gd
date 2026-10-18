extends "res://assets/vfx/sources/0738ff2d24aa41b1b963/native_review_composition.gd"
## Whole-source admission for the two original shell hemispheres. The source
## still owns mesh/noise/alpha/clock; only its old export-half discard is removed.
const SourceMaterials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
const HALF_CUT := "if((front&&dep<0.0)||(!front&&dep>=0.0))discard;"
var whole_admitted: bool = false
var material_repairs: Array = []

static func make_component(input: Dictionary) -> Node3D:
	var node := VfxPackageIO_b4ec8c1fd3.resource("res://assets/vfx/sources/b4ec8c1fd3039d13a851/silence_whole_composition.gd").new() as Node3D
	node.definition = input.duplicate(true)
	return node

func sample(seconds: float) -> void:
	super.sample(seconds)
	if whole_admitted:
		return
	if composition == null or not adapted:
		return
	if definition.components.size() != 1 or definition.components[0].input.get("side", "") != "full" or definition.components[0].input.settings.get("kind", "") != "silence":
		push_error("Whole shell admission requires the original full-side silence source")
		return
	if source_materials.size() != 2:
		push_error("Whole shell admission requires exactly two original hemisphere materials")
		return
	for material: ShaderMaterial in source_materials:
		var original := material.shader.code
		if original.count(HALF_CUT) != 1:
			push_error("Whole shell exact original export mask changed")
			return
		var shader := Shader.new()
		shader.code = original.replace(HALF_CUT, "")
		SourceMaterials.replace_shader(material, shader)
		material_repairs.append({"before_SHA256":original.sha256_text(),"after_SHA256":shader.code.sha256_text()})
	whole_admitted = true

func capture_observation() -> Dictionary:
	var observation := super.capture_observation()
	var rows: Array = []
	for material: ShaderMaterial in source_materials:
		var matrix: Variant = material.get_shader_parameter("factory_world_to_source")
		rows.append({"clock":material.get_shader_parameter("clock"),"front":material.get_shader_parameter("front"),
			"remaining_export_half_cuts":material.shader.code.count(HALF_CUT),
			"matrix_type":type_string(typeof(matrix)),"matrix_equals_source_inverse":matrix is Projection and matrix == Projection(global_transform.affine_inverse())})
	observation.whole_admitted = whole_admitted
	observation.material_repairs = material_repairs.duplicate(true)
	observation.material_samples = rows
	return observation

const VfxPackageIO_b4ec8c1fd3 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
