extends RefCounted
## Explicit data only: no shader-name inference, scene scripts or actor input.
const Recorded = preload("res://assets/vfx/extensions/production-review-20261020/sources/c80c403105490edb11e8/baked_effect.gd")
const Materials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")


static func prepare(root: Node3D, declared: Array, private_indices: Variant, indexed: Array = []) -> Dictionary:
	var result := {"bindings": [], "error": ""}
	if declared.is_empty(): return result
	var materials := indexed
	if materials.is_empty():
		materials = Recorded.material_locations(root).map(func(entry: Dictionary) -> Material: return entry.material)
	for record: Dictionary in declared:
		var index := int(record.get("material", -1))
		var uniform := str(record.get("uniform", ""))
		var path := NodePath(str(record.get("path", "")))
		if index < 0 or index >= materials.size() or index not in private_indices or uniform.is_empty() \
				or path.is_empty() or path.is_absolute() or path.get_subname_count() != 0:
			result.error = "Invalid explicit private recorded placement binding"
			return result
		var source: Node3D = root.get_node_or_null(path)
		var material: ShaderMaterial = materials[index] as ShaderMaterial
		if source == null or (source != root and not root.is_ancestor_of(source)) or material == null \
				or uniform not in Materials.declared_uniforms(material.shader):
			result.error = "Missing actual source node/private shader uniform in recorded placement"
			return result
		result.bindings.append({"node": source, "material": material, "uniform": uniform, "last": null})
	return result


static func apply(bindings: Array) -> String:
	for binding: Dictionary in bindings:
		var node: Node3D = binding.node
		if not is_instance_valid(node): return "Recorded source placement owner was released"
		if not node.is_inside_tree(): continue
		var transform: Transform3D = node.global_transform
		if binding.last != null and binding.last == transform: continue
		if not transform.is_finite() or transform.basis.determinant() == 0.0:
			return "Recorded source placement requires a finite invertible actual transform"
		binding.material.set_shader_parameter(binding.uniform, transform.affine_inverse())
		binding.last = transform
	return ""
