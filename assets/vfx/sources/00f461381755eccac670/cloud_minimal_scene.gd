extends RefCounted
## Exact immutable node/material specifications. No source equations are changed.
## Capturing is offline; construction creates private nodes and mutable uniforms.
const Profile = preload("res://assets/vfx/sources/5e6062cb1efe781a65b7/construction_profile.gd")
const SKIP := ["owner", "script", "name", "scene_file_path", "unique_name_in_owner"]

static func _same_uniform(a: Variant, b: Variant) -> bool:
	if (a is float or b is float) and (a is float or a is int) and (b is float or b is int):
		return PackedFloat32Array([float(a)]).to_byte_array() == PackedFloat32Array([float(b)]).to_byte_array()
	return a == b

static func _default_uniform(shader: Shader, name: String) -> Variant:
	var texture := shader.get_default_texture_parameter(name)
	return texture if texture != null else RenderingServer.shader_get_parameter_default(shader.get_rid(), name)

static func _material(material: ShaderMaterial, data: Dictionary) -> int:
	if data.seen_materials.has(material):
		return data.seen_materials[material]
	assert(material.next_pass == null, "Cloud multi-pass source needs explicit private pass preparation")
	var index: int = data.materials.size()
	data.seen_materials[material] = index
	var parameters := {}
	for uniform in material.shader.get_shader_uniform_list():
		var name: String = uniform.name
		var value: Variant = material.get_shader_parameter(name)
		var original_default: Variant = _default_uniform(material.shader, name)
		if value != null and not _same_uniform(value, original_default):
			parameters[name] = value
	var metadata := {}
	for key in material.get_meta_list():
		metadata[key] = material.get_meta(key)
	data.materials.append({"shader": material.shader, "parameters": parameters,
		"render_priority": material.render_priority, "metadata": metadata, "immutable_native_process": false})
	return index

static func _value(value: Variant, data: Dictionary) -> Dictionary:
	if value is ShaderMaterial:
		return {"kind": "private_material", "index": _material(value, data)}
	if value is Mesh:
		var surfaces := []
		for surface in value.get_surface_count():
			var material: Material = value.surface_get_material(surface)
			if material is ShaderMaterial:
				surfaces.append({"surface": surface, "index": _material(material, data)})
		if not surfaces.is_empty():
			return {"kind": "private_surface_mesh", "mesh": value, "surfaces": surfaces}
	return {"kind": "immutable_value", "value": value}

static func _node(node: Node, root: Node, data: Dictionary) -> void:
	assert(node.get_script() == null, "Original cloud node script must stay explicit")
	var defaults: Node = ClassDB.instantiate(node.get_class())
	var properties := []
	for property in node.get_property_list():
		var name: String = property.name
		if not int(property.usage) & PROPERTY_USAGE_STORAGE or name in SKIP:
			continue
		var value: Variant = node.get(name)
		if value != defaults.get(name):
			var operand := _value(value, data)
			if data.share_native_process and node is GPUParticles3D and name == "process_material":
				assert(node.local_coords and value is ShaderMaterial, "Shared process requires local-coordinate native ShaderMaterial")
				assert(value.has_meta("factory_native_process_source"), "Shared process must retain actual native capture provenance")
				value.resource_local_to_scene = false
				value.set_meta("factory_immutable_native_process", "local_coords_static_native_operands")
				data.materials[int(operand.index)].immutable_native_process = true
				data.materials[int(operand.index)].immutable_material = value
			properties.append({"field": name, "operand": operand})
	defaults.free()
	data.nodes.append({"class": node.get_class(), "name": String(node.name),
		"parent": "root" if node == root else String(root.get_path_to(node.get_parent())),
		"path": String(root.get_path_to(node)), "properties": properties})
	for child in node.get_children():
		_node(child, root, data)

static func capture(root: Node3D, share_native_process: bool = false) -> Dictionary:
	var data := {"nodes": [], "materials": [], "seen_materials": {}, "share_native_process": share_native_process}
	_node(root, root, data)
	data.erase("seen_materials")
	data.erase("share_native_process")
	return data

static func instantiate(nodes: Array, material_definitions: Array, profile_details: bool = false) -> Node3D:
	var materials := []
	for definition in material_definitions:
		if definition.get("immutable_native_process", false):
			assert(definition.immutable_material.get_meta("factory_immutable_native_process", "") == "local_coords_static_native_operands")
			materials.append(definition.immutable_material)
			continue
		if profile_details: Profile.begin("cloud_material_new")
		var material := ShaderMaterial.new()
		if profile_details: Profile.end("cloud_material_new")
		if profile_details: Profile.begin("cloud_material_shader_assignment")
		material.shader = definition.shader
		if profile_details: Profile.end("cloud_material_shader_assignment")
		if int(definition.render_priority) != 0:
			material.render_priority = definition.render_priority
		if profile_details: Profile.begin("cloud_material_uniform_setters")
		for name in definition.parameters:
			material.set_shader_parameter(name, definition.parameters[name])
		if profile_details: Profile.end("cloud_material_uniform_setters")
		if profile_details: Profile.begin("cloud_material_metadata_setters")
		for key in definition.metadata:
			material.set_meta(key, definition.metadata[key])
		if profile_details: Profile.end("cloud_material_metadata_setters")
		materials.append(material)
	var root: Node3D
	var by_path := {}
	var private_meshes := {}
	for definition in nodes:
		if profile_details: Profile.begin("cloud_node_new")
		var node: Node = ClassDB.instantiate(definition["class"])
		if profile_details: Profile.end("cloud_node_new")
		node.name = definition.name
		if profile_details: Profile.begin("cloud_node_property_setters")
		for record in definition.properties:
			var operand: Dictionary = record.operand
			var value: Variant
			match operand.kind:
				"private_material":
					value = materials[int(operand.index)]
				"private_surface_mesh":
					if not private_meshes.has(operand.mesh):
						var mesh: Mesh = operand.mesh.duplicate(false)
						for surface in operand.surfaces:
							mesh.surface_set_material(int(surface.surface), materials[int(surface.index)])
						private_meshes[operand.mesh] = mesh
					value = private_meshes[operand.mesh]
				"immutable_value":
					value = operand.value
				_:
					assert(false, "Unknown immutable cloud operand")
			if profile_details: Profile.begin("cloud_node_set_" + str(record.field))
			node.set(record.field, value)
			if profile_details: Profile.end("cloud_node_set_" + str(record.field))
		if profile_details: Profile.end("cloud_node_property_setters")
		if profile_details: Profile.begin("cloud_node_parent_insertion")
		if definition.parent == "root":
			root = node
		else:
			assert(by_path.has(definition.parent), "Prepared cloud child order is invalid")
			by_path[definition.parent].add_child(node)
		if profile_details: Profile.end("cloud_node_parent_insertion")
		by_path[definition.path] = node
	return root
