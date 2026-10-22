extends "res://assets/vfx/extensions/spirit-receiver-20261022/sources/79a8b97b54c4891730ea/bank_v3.gd"
## Prepare the actual RID restore operands, never the unused Node restore inventories.
const OperandReferences = preload("res://assets/vfx/extensions/owner-fields-v2-20261021/sources/718478933d60b6c71150/scene_operand_references.gd")
const Bindings = preload("res://assets/vfx/sources/dabf568b4506db4883ad/occurrence_bindings.gd")
const SourceMaterials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
const Clock = preload("res://assets/vfx/sources/c0017ad639184b208deb/occurrence_clock.gd")
@export var required_operand_indices := PackedInt32Array()
var references_restored := false
var required_resources: Array[Resource] = []
var prepared_rids: Dictionary = {}
var prepare_at := 0
var preparation_error := ""


func prepare_immutable_interface() -> void:
	while not interface_ready:
		var result := prepare_immutable_interface_step()
		if not str(result.get("error", "")).is_empty():
			push_error(result.error)
			return


func _collect_required(value: Variant, seen: Dictionary) -> bool:
	if value is Resource:
		if not (value is Shader or value is Mesh or value is Texture or value is Shape3D):
			preparation_error = "Unqualified resource operand in the actual Spirit material/mesh program"
			return false
		if not seen.has(value):
			seen[value] = true
			required_resources.append(value)
	elif value is Array:
		for child: Variant in value:
			if not _collect_required(child, seen):
				return false
	elif value is Dictionary:
		for child: Variant in value.values():
			if not _collect_required(child, seen):
				return false
	return true


func prepare_immutable_interface_step() -> Dictionary:
	if not preparation_error.is_empty():
		return {"complete": false, "error": preparation_error}
	if interface_ready:
		return {"complete": true}
	if not references_restored:
		if source_bank == null or source_bank.construction_source == null or material_program == null or transform_publisher == null:
			preparation_error = "Missing exact original Spirit resource/program operands"
			return {"complete": false, "error": preparation_error}
		# First restore the exact saved original resource addresses. This does
		# not claim that the unused DirectRestore bank's interface is prepared.
		OperandReferences.restore(source_bank.construction_source, source_bank.source_operand_references, source_bank.construction_operands)
		var seen := {}
		for index: int in required_operand_indices:
			if index < 0 or index >= source_bank.construction_operands.size():
				preparation_error = "Unqualified actual Spirit operand ordinal"
				return {"complete": false, "error": preparation_error}
			if not _collect_required(source_bank.construction_operands[index], seen):
				return {"complete": false, "error": preparation_error}
		for index: int in mesh_operand_indices:
			var value: Variant = source_bank.construction_operands[index]
			if not value is Mesh or not seen.has(value):
				preparation_error = "Actual original Spirit mesh is absent from declared program operands"
				return {"complete": false, "error": preparation_error}
			meshes.append(value)
		# These exact source templates already receive reflection/RID admission
		# in the original path. Keep only templates for an actually used Shader,
		# rather than moving that first native program work to a private owner.
		for material: ShaderMaterial in source_bank.native_material_templates:
			if seen.has(material.shader) and not seen.has(material):
				seen[material] = true
				required_resources.append(material)
		required_resources.append(material_program)
		required_resources.append(transform_publisher)
		required_resources.append(VfxPackageIO_0228862d32.resource(_controller_path()))
		if source_bank.provenance.get("requires_shared_clock", false):
			Clock.ensure_pool()
		references_restored = true
		return {"complete": false, "unit": "restore_original_operand_references", "resources": required_resources.size()}
	if prepare_at < required_resources.size():
		var value: Resource = required_resources[prepare_at]
		if value is Script:
			Bindings.methods(value)
		else:
			if value is ShaderMaterial:
				value.get_property_list()
			var rid: RID = value.get_rid()
			if not rid.is_valid():
				preparation_error = "Actual Spirit native resource has no admitted RID"
				return {"complete": false, "error": preparation_error}
			prepared_rids[value] = rid
			if value is Shader:
				SourceMaterials.declared_uniforms(value)
			elif value is ShaderMaterial:
				SourceMaterials.declared_uniforms(value.shader)
			elif value is Mesh:
				value.get_aabb()
				value.get_surface_count()
		prepare_at += 1
		return {"complete": false, "unit": value.get_class(), "resource": value.resource_path,
			"prepared": prepare_at, "resources": required_resources.size()}
	for mesh: Mesh in meshes:
		mesh_rids.append(prepared_rids[mesh])
	interface_ready = true
	return {"complete": true, "resources": required_resources.size(), "original_node_bank_ready": source_bank.interface_ready}

const VfxPackageIO_0228862d32 = preload("res://assets/vfx/extensions/spirit-receiver-20261022/scoped_resource_io.gd")
