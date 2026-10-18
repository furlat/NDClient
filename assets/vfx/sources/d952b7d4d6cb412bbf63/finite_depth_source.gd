extends "res://assets/vfx/sources/843204815cdceaac8544/clocked_source.gd"
## Same pinned source sampler. Opt in to the shared finite depth-fade formula
## where an inspected VisualShader uses reversed smoothstep edges.
const FiniteDepth = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
var finite_depth_materials := 0


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/d952b7d4d6cb412bbf63/finite_depth_source.gd", input)


func clock_resource(resource: Resource) -> void:
	if resource != null and not visited.has(resource.get_instance_id()) and resource is ShaderMaterial and resource.shader != null:
		var source: String = FiniteDepth.expand_shader(resource.shader.code, resource.shader.resource_path.get_base_dir())
		var finite := FiniteDepth.stable_proximity(source)
		if finite != source:
			var shader := Shader.new()
			shader.code = finite
			FiniteDepth.replace_shader(resource, shader)
			finite_depth_materials += 1
	super.clock_resource(resource)


func capture_observation() -> Dictionary:
	var result: Dictionary = super.capture_observation()
	result.finite_depth_materials = finite_depth_materials
	result.source_layers_removed = false
	result.depth_occlusion_disabled = false
	return result
