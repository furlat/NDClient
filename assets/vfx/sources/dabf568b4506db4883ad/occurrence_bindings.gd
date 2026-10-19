extends RefCounted
## Cheap displayed-slot identity probes; full discovery belongs to revisions.
static var method_metadata: Dictionary = {}


static func methods(script: Script) -> Array:
	if not method_metadata.has(script):
		var names: Array[String] = []
		var inherited: Script = script
		while inherited != null:
			for method in inherited.get_script_method_list():
				var name: String = method.name
				if (name.begins_with("set_") or name == "body_surface_sample") and name not in names:
					names.append(name)
			inherited = inherited.get_base_script()
		method_metadata[script] = names
	return method_metadata[script]


static func sites(root: Node) -> Array:
	return root.find_children("*", "Node", true, false).filter(func(node: Node) -> bool:
		return node is GeometryInstance3D)


static func signature(nodes: Array) -> Array:
	var result: Array = []
	var seen: Dictionary = {}
	for node in nodes:
		if not is_instance_valid(node) or not node.is_inside_tree():
			result.append(null)
			continue
		result.append(node)
		material_identity(node.material_override, result, seen)
		material_identity(node.material_overlay, result, seen)
		var meshes: Array = []
		if node is MeshInstance3D:
			meshes.append(node.mesh)
			for index in node.get_surface_override_material_count():
				material_identity(node.get_surface_override_material(index), result, seen)
		elif node is MultiMeshInstance3D and node.multimesh != null:
			meshes.append(node.multimesh.mesh)
		elif node is GPUParticles3D:
			material_identity(node.process_material, result, seen)
			for index in node.draw_passes:
				meshes.append(node.get_draw_pass_mesh(index))
		for mesh in meshes:
			if mesh != null:
				for index in mesh.get_surface_count():
					material_identity(mesh.surface_get_material(index), result, seen)
	return result


static func material_identity(material: Material, result: Array, seen: Dictionary) -> void:
	result.append(material)
	if material == null or seen.has(material):
		return
	seen[material] = true
	if material is ShaderMaterial:
		result.append(material.shader)
	material_identity(material.next_pass, result, seen)
