extends "res://assets/vfx/sources/4674c46f17c6de4e99dc/fear_noise_wake.gd"
## Keep V301's source front/contact. Avoid thresholded parallel floor gaps.


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/9ef59f94adb1ec8e886a/fear_noise_wake_soft.gd", input)


func apply_scene_edits(node: Node) -> void:
	super.apply_scene_edits(node)
	var wake := node.get_node("SourceNoiseWake") as MeshInstance3D
	var material := wake.material_override as ShaderMaterial
	var code: String = material.shader.code
	code = code.replace("float curl=.5+.5*sin(UV.y*24.-support_clock*3.+n2*5.);", "float curl=smoothstep(.12,.78,n2*.6+n*.4);")
	code = code.replace("edge*smoothstep(.18,.62,n*.65+n2*.35)*(.12+.52*strands)", "edge*(.13+.19*n+.20*strands)")
	var shader := Shader.new()
	shader.code = code
	SourceMaterials.replace_shader(material, shader)
