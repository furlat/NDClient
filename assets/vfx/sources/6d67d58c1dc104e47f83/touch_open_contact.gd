extends "res://assets/vfx/sources/57b9ea67c1761593cabb/touch_or_puff.gd"
## Keep the source rim/contact motion while opening its opaque central fill.
const TouchBindings = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/6d67d58c1dc104e47f83/touch_open_contact.gd", input)


func apply_scene_edits(node: Node) -> void:
	super.apply_scene_edits(node)
	var corruption: GPUParticles3D = node.get_node("Pruple Expansion")
	var material: ShaderMaterial = corruption.material_override
	var original := "max(core*0.9,n_out3p1*0.28)"
	var code: String = material.shader.code
	assert(code.count(original) == 1, "Touch source coverage output changed")
	var shader := Shader.new()
	shader.code = code.replace(original, "max(core*0.18,n_out3p1*0.28)")
	TouchBindings.replace_shader(material, shader)
	for name in ["FBHead", "FBHead2inner"]:
		var ribbon: MeshInstance3D = necrotic_wrap.get_node(name)
		var ribbon_material: ShaderMaterial = ribbon.material_override
		var ribbon_code: String = ribbon_material.shader.code
		var end: int = ribbon_code.rfind("}")
		assert(end >= 0)
		var ribbon_shader := Shader.new()
		ribbon_shader.code = ribbon_code.insert(end, "\nALPHA *= 0.42;\n")
		TouchBindings.replace_shader(ribbon_material, ribbon_shader)
