extends "res://assets/vfx/sources/c453b83c4c572aa5c3b6/protection.gd"


## Native directional contact geometry; source shader remains unchanged.
static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/c8950a0c89b678d29b2b/protection_contact.gd", input)


func apply_scene_edits(node: Node) -> void:
	node.position = Vector3(parameters.position[0], parameters.position[1], parameters.position[2])
	node.scale = Vector3.ONE * 1.12
	var direction: Array = parameters.impact_directions[parameters.view_id]
	node.quaternion = Quaternion(Vector3.UP, Vector3(direction[0], direction[1], direction[2]))
	var material = ShaderMaterial.new()
	material.shader = VfxPackageIO_c8950a0c89.resource("res://assets/vfx/sources/413038e3d4132a32c9f3/accepted_shield_contact.gdshader")
	for key in ["Size_Sphere", "Hit_Texture", "Gradient_Color_1D", "Gradient_Dissapear"]:
		material.set_shader_parameter(key, node.material_override.get_shader_parameter(key))
	material.set_shader_parameter("Size_Sphere", 0.25)
	var proxy = MeshInstance3D.new()
	proxy.mesh = node.draw_pass_1
	proxy.material_override = material
	proxy.scale = Vector3.ONE * 0.8
	node.add_child(proxy)
	node.emitting = false
	adapt(material)


func prepare_materials(_node: Node) -> void:
	pass


func advance_lifecycle(_delta: float) -> void:
	tick += 1
	var age: float = float(tick) / float(parameters.simulation_hz)
	subject.visible = age < 0.82
	for material in materials:
		material.set_shader_parameter("Hit_Phase", 1.0 - clampf(age / 0.82, 0.0, 1.0))
		material.set_shader_parameter("vfx_clock", age)
		material.set_shader_parameter("vfx_alpha", 1.0)

const VfxPackageIO_c8950a0c89 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
