extends "res://assets/vfx/extensions/wall-child-v3-20261021/sources/7a9446a55e1774fc82be/wind_bank.gd"
## Original immutable Wind bank plus its exact native debris display program.
## Original StandardMaterial remains the controller's actual colour writer.
@export var original_bank: Resource
@export var debris_material: ShaderMaterial
@export var native_program_sha256 := ""
@export var native_uniforms: PackedStringArray = []
@export var albedo_uniform := "albedo"


func prepare_immutable_interface_step() -> Dictionary:
	if original_bank == null or debris_material == null or debris_material.shader == null:
		return {"complete": false, "error": "Exact Wind debris program bank is missing"}
	if debris_material.shader.code.sha256_text() != native_program_sha256:
		return {"complete": false, "error": "Exact Wind debris program changed"}
	if albedo_uniform != "albedo" or albedo_uniform not in native_uniforms:
		return {"complete": false, "error": "Actual native Wind albedo binding is missing"}
	prepare_immutable_interface()
	return {"complete": interface_ready, "error": ""}


func prepare_immutable_interface() -> void:
	if interface_ready:
		return
	donor_bank = original_bank.donor_bank
	flow_materials.assign(original_bank.flow_materials)
	hit_materials.assign(original_bank.hit_materials)
	super.prepare_immutable_interface()
	debris_material.get_property_list()
	debris_material.get_rid()
	Interfaces.declared_uniforms(debris_material.shader)
