extends "res://assets/vfx/sources/1e83a91767b68e67396e/healing.gd"
## Family-local source layer fitting; source geometry/textures/clocks stay intact.
const ReceiveSource = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/1f4996c92ad61d6c5518/healing_pulse.gd", input)


func apply_scene_edits(node: Node) -> void:
	super.apply_scene_edits(node)
	for adjustment in parameters.get("receive_layers", []):
		var layer: GeometryInstance3D = node.get_node(adjustment.node)
		if adjustment.has("scale"):
			var axes: Array = adjustment.scale
			layer.scale *= Vector3(float(axes[0]), float(axes[1]), float(axes[2]))
		if adjustment.has("position_gain"):
			layer.position *= float(adjustment.position_gain)
		var alpha: float = float(adjustment.alpha)
		if layer.material_override is ShaderMaterial:
			layer.material_override.set_meta("receive_layer_alpha", alpha)
		elif layer.material_override is BaseMaterial3D:
			layer.material_override.albedo_color.a *= alpha


func adapt_shader(material: ShaderMaterial) -> void:
	super.adapt_shader(material)
	var gain: float = float(material.get_meta("receive_layer_alpha", 1.0))
	if gain == 1.0:
		return
	var code: String = material.shader.code.replace("shader_type spatial;", "shader_type spatial;\nuniform float receive_layer_alpha=1.0;")
	code = ReceiveSource.finish_fragment(code, "\nALPHA *= receive_layer_alpha;\n")
	var shader := Shader.new()
	shader.code = code
	ReceiveSource.replace_shader(material, shader)
	material.set_shader_parameter("receive_layer_alpha", gain)
