extends "res://assets/vfx/sources/4fbb7cda915034509170/ice_projectile.gd"
## Keep the original flash, rings, sparks and closed fragments; give the
## physical fragments priority over the smooth additive carrier.


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/202e244b1441ee62b201/ice_knife_fracture.gd", input)


func apply_scene_edits(node: Node) -> void:
	super.apply_scene_edits(node)
	var debris: GPUParticles3D = node.get_node("debirs_icex")
	debris.process_material.scale_min *= float(parameters.fragment_scale_multiplier)
	debris.process_material.scale_max *= float(parameters.fragment_scale_multiplier)
	debris.material_override.set_shader_parameter("ColorIntensity", float(parameters.fragment_intensity))
	for label in ["clouds_external", "little_sparks", "muzzle"]:
		var emitter: GPUParticles3D = node.get_node(label)
		var color: Color = emitter.process_material.color
		var gain: float = float(parameters.flash_color_gain)
		emitter.process_material.color = Color(color.r * gain, color.g * gain, color.b * gain,
			color.a * float(parameters.flash_alpha_gain))
	var muzzle: GPUParticles3D = node.get_node("muzzle")
	muzzle.scale *= float(parameters.muzzle_scale_multiplier)
	if settings.has("material_component"):
		for draw in node.find_children("*", "GeometryInstance3D", true, false):
			var selected: bool = draw.name == "debirs_icex"
			if selected != (settings.material_component == "debris"):
				draw.layers = 0
		debris.visibility_aabb = AABB(Vector3(-100, -100, -100), Vector3(200, 200, 200))
		debris.local_coords = false
		var collider := GPUParticlesCollisionBox3D.new()
		collider.size = Vector3(200, 100, 200)
		collider.position = Vector3(0, -54, 0)
		add_child(collider)


func capture_observation() -> Dictionary:
	var result: Dictionary = super.capture_observation()
	result.fragment_scale_multiplier = parameters.fragment_scale_multiplier
	result.original_fragment_mesh_retained = true
	result.original_fragment_count = 50
	result.original_flash_layers_retained = true
	return result
