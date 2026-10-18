extends RefCounted
## Explicit material substitution on fresh scene instances; original resources stay read-only.
static func apply(root: Node3D, rules: Array) -> void:
	var geometry_nodes: Array[Node] = root.find_children("*", "GeometryInstance3D", true, false)
	if root is GeometryInstance3D:
		geometry_nodes.append(root)
	for rule in rules:
		var shader := Shader.new()
		shader.code = VfxPackageIO_95fc365541.text(rule.shader_source)
		for node in geometry_nodes:
			var original: Material = node.material_override
			if not original is BaseMaterial3D:
				continue
			if original.blend_mode != int(rule.match.blend_mode):
				continue
			if rule.match.requires_texture and original.albedo_texture == null:
				continue
			var material := ShaderMaterial.new()
			material.shader = shader
			material.render_priority = original.render_priority
			for uniform in rule.source_parameters:
				material.set_shader_parameter(uniform, original.get(rule.source_parameters[uniform]))
			for uniform in rule.parameters:
				material.set_shader_parameter(uniform, rule.parameters[uniform])
			node.material_override = material

const VfxPackageIO_95fc365541 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
