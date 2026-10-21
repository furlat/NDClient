extends RefCounted
## Binding is explicit: no rewriting TIME, blanket animation seeks, or seed traversal.
var components: Dictionary = {}
var bindings: Array[Dictionary] = []
var resolved_emitters: Array[Dictionary] = []
var material_sets: Dictionary = {}

func make(parent: Node3D, contract: Dictionary) -> String:
	for specification in contract.components:
		var script: Script = VfxPackageIO_628b95849d.resource(specification.script)
		if script == null or not script.has_method("make_component"):
			return "Missing component constructor: " + str(specification.script)
		var component: Node3D = script.make_component(specification.input.duplicate(true))
		if component == null:
			return "Component construction failed: " + str(specification.id)
		# Source-local recording and live import require deterministic node paths.
		component.name = str(specification.id)
		component.rotation_degrees = Vector3(specification.rotation_degrees[0], specification.rotation_degrees[1], specification.rotation_degrees[2])
		parent.add_child(component)
		components[specification.id] = component
	for specification in contract.emitters:
		var emitter: Node = components[specification.component].get_node_or_null(NodePath(specification.path))
		if not emitter is GPUParticles3D:
			return "Missing GPU emitter: " + str(specification.path)
		emitter.use_fixed_seed = true
		emitter.seed = int(specification.seed)
		emitter.fixed_fps = int(specification.fixed_fps)
		resolved_emitters.append(specification.duplicate(true))
	for specification in contract.bindings:
		var binding: Dictionary = specification.duplicate(true)
		binding.node = components[binding.component]
		match binding.kind:
			"sample":
				if not binding.node.has_method("sample"):
					return "Missing explicit sample method"
			"shader_uniform":
				if not material_sets.has(binding.component):
					var materials: Array = []
					_isolate_materials(binding.node, materials)
					material_sets[binding.component] = materials
				binding.materials = material_sets[binding.component]
				if binding.materials.is_empty():
					return "No ShaderMaterials for declared binding"
				for material in binding.materials:
					var found: bool = false
					for uniform in material.shader.get_shader_uniform_list():
						if uniform.name == binding.uniform:
							found = true
					if not found:
						return "Declared shader clock uniform is absent: " + str(binding.uniform)
			"animation_seek":
				binding.player = binding.node.get_node_or_null(NodePath(binding.path))
				if not binding.player is AnimationPlayer or not binding.player.has_animation(binding.clip):
					return "Missing animation binding"
				binding.player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
				binding.player.play(binding.clip)
		bindings.append(binding)
	for component_id in components:
		if not components[component_id].has_method("sample"):
			continue
		var has_sample_binding: bool = false
		for binding in bindings:
			if binding.component == component_id and binding.kind == "sample":
				has_sample_binding = true
		if not has_sample_binding:
			return "Dynamic component has no explicit sample binding: " + str(component_id)
	return ""

func _isolate_materials(node: Node, result: Array) -> void:
	if node is MeshInstance3D:
		if node.material_override is ShaderMaterial:
			node.material_override = node.material_override.duplicate(true)
			result.append(node.material_override)
		elif node.mesh != null:
			for surface in node.mesh.get_surface_count():
				var material: Material = node.get_active_material(surface)
				if material is ShaderMaterial:
					var isolated: ShaderMaterial = material.duplicate(true)
					node.set_surface_override_material(surface, isolated)
					result.append(isolated)
	for child in node.get_children():
		_isolate_materials(child, result)

func sample(seconds: float) -> void:
	for binding in bindings:
		var local_time: float = seconds * float(binding.rate) + float(binding.offset_seconds)
		match binding.kind:
			"sample":
				binding.node.sample(local_time)
			"shader_uniform":
				for material in binding.materials:
					material.set_shader_parameter(binding.uniform, local_time)
			"animation_seek":
				binding.player.seek(local_time, true)
				binding.player.pause()

## Preparation traverses actual recipe data and loads no scene/occurrence.
static func preparation_resources(contract: Dictionary) -> Array:
	var paths := []
	for specification in contract.get("components", []):
		var script: Script = VfxPackageIO_628b95849d.resource(specification.script)
		if script.has_method("preparation_resources"):
			for path in script.preparation_resources(specification.input):
				if path not in paths:
					paths.append(path)
	return paths

func source_bindings() -> Dictionary:
	if not resolved_emitters.is_empty():
		return {}
	var result := {"geometry": [], "materials": [], "lights": [], "players": [], "static_material_topology": true, "static_geometry_layers": true}
	var present := {"geometry": {}, "materials": {}, "lights": {}, "players": {}}
	for component in components.values():
		if not component.has_method("source_bindings"):
			return {}
		var declared: Dictionary = component.source_bindings()
		if not declared.get("static_material_topology", false):
			return {}
		result.static_geometry_layers = result.static_geometry_layers and declared.get("static_geometry_layers", true)
		for field in ["geometry", "materials", "lights", "players"]:
			for value in declared.get(field, []):
				# Real role members are live Nodes/Resources with identity semantics.
				# Keep the former equality path for an unknown non-object operand.
				if value is Object:
					if present[field].has(value):
						continue
					present[field][value] = true
					result[field].append(value)
				elif value not in result[field]:
					result[field].append(value)
	return result

const VfxPackageIO_628b95849d = preload("res://assets/vfx/extensions/spirit-runtime-20261021/scoped_resource_io.gd")
