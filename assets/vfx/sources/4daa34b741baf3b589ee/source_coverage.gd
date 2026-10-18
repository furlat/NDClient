extends Node3D
## Explicit local coverage for selected donor layers; source construction and
## animation remain delegated. No stage, palette, lighting or damage policy.
const SourceBindings = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
var source: Node3D
var targets: Array = []
var specification: Dictionary
var initialized: bool = false


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = VfxPackageIO_4daa34b741.resource("res://assets/vfx/sources/4daa34b741baf3b589ee/source_coverage.gd").new()
	instance.specification = input.duplicate(true)
	var constructor: Script = VfxPackageIO_4daa34b741.resource(input.source.constructor_script)
	instance.source = constructor.make_component(input.source.input)
	assert(instance.source != null, "Coverage source construction failed")
	instance.source.name = "Source"
	instance.add_child(instance.source)
	return instance


func sample(seconds: float) -> void:
	source.sample(seconds)
	if not initialized:
		initialized = true
		for patch in specification.layers:
			var matches: Array[Node] = source.find_children(patch.node_name, "GeometryInstance3D", true, false)
			assert(matches.size() == int(patch.get("count", 1)), "Coverage source layer changed: " + str(patch.node_name))
			for node in matches:
				var material: Material = node.material_override.duplicate(true)
				node.material_override = material
				var original_alpha: float = 1.0
				if material is ShaderMaterial:
					var code: String = SourceBindings.expand_shader(material.shader.code, material.shader.resource_path.get_base_dir())
					code = code.replace("shader_type spatial;", "shader_type spatial; uniform float factory_layer_coverage=1.0;\n")
					var edge: float = float(patch.get("edge_uv", 0.0))
					var alpha_code := "\nALPHA *= factory_layer_coverage;\n"
					if edge > 0.0:
						alpha_code += "vec2 coverage_edge=min(UV,vec2(1.0)-UV);ALPHA*=smoothstep(0.0,%s,min(coverage_edge.x,coverage_edge.y));\n" % edge
					var shader := Shader.new()
					shader.code = SourceBindings.finish_fragment(code, alpha_code)
					SourceBindings.replace_shader(material, shader)
				elif material is BaseMaterial3D:
					assert(material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED, "Coverage needs an existing transparent source")
					original_alpha = material.albedo_color.a
				else:
					assert(false, "Unsupported explicit coverage material")
				targets.append({"material": material, "patch": patch, "original_alpha": original_alpha})
	for target in targets:
		var patch: Dictionary = target.patch
		var alpha: float = float(patch.gain)
		if patch.has("fade_seconds"):
			alpha *= 1.0 - smoothstep(float(patch.fade_seconds[0]), float(patch.fade_seconds[1]), seconds)
		if target.material is ShaderMaterial:
			target.material.set_shader_parameter("factory_layer_coverage", alpha)
		else:
			var color: Color = target.material.albedo_color
			color.a = float(target.original_alpha) * alpha
			target.material.albedo_color = color


func capture_observation() -> Dictionary:
	return {"local_layers": targets.size(), "source": specification.source.constructor_script}

const VfxPackageIO_4daa34b741 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
