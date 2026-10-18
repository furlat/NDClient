extends "res://assets/vfx/sources/e212c77ca5bf64639ea0/base.gd"


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/c0d353db196caa737f35/support.gd", input)


func apply_scene_edits(node: Node) -> void:
	node.scale *= float(settings.scale)
	node.position.y += float(settings.height)
	if settings.name == "VFX_HealPuff_A":
		node.get_node("objectflare").layers = 0
		node.get_node("lines").layers = 0
		var puff = node.get_node("smoke2init2")
		for player in node.find_children("*", "AnimationPlayer", true, false):
			if player.has_animation("Init"):
				var anim = player.get_animation("Init")
				for track in anim.get_track_count():
					if String(anim.track_get_path(track)) == "smoke2init2:emitting":
						for key in anim.track_get_key_count(track):
							anim.track_set_key_time(track, key, 0.25)
		puff.amount = 5
		puff.lifetime = 0.85
		puff.process_material = puff.process_material.duplicate(true)
		puff.process_material.radial_velocity_min = 0.4
		puff.process_material.radial_velocity_max = 0.9
		puff.process_material.emission_shape_scale = Vector3(0.9, 0.35, 0.9)
		puff.process_material.scale_min *= 0.65
		puff.process_material.scale_max *= 0.65
		puff.process_material.initial_velocity_min *= 0.5
		puff.process_material.initial_velocity_max *= 0.5
	if settings.name == "VFX_Healing_W1":
		node.get_node("white_Line_horizontal").layers = 0
		var pulse = node.get_node("verticalflash")
		pulse.scale = Vector3(0.9, 0.5, 0.9)
		pulse.lifetime = 0.65
		pulse.process_material = pulse.process_material.duplicate(true)
		pulse.process_material.scale_min *= 0.85
		pulse.process_material.scale_max *= 0.85
	if settings.name == "VFX_Protection_4_Shield":
		node.get_node("muzzle2").scale *= 0.35
		node.get_node("muzzle2").position.y += 0.7
		node.get_node("floorflash4").layers = 0
		node.get_node("verticalflash3").layers = 0
		node.get_node("shield_effect").position.y += 1.0
		node.get_node("shield_effect").scale *= Vector3(0.85, 0.85, 0.85)
		node.get_node("external_base_ring").scale *= Vector3(0.6, 0.6, 0.6)
		node.get_node("verticalflash2").scale.y = 0.08
		node.get_node("verticalflash2").position.y = 1.5
		node.get_node("verticalflash2").lifetime = 0.45
		node.get_node("smallparticles4").amount = 24
	if settings.name == "magic_orb_small_vfx_03":
		node.get_node("Flare").layers = 0
		var glow = node.get_node("Glow").material_override
		var gradient = Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.65, 1.0])
		gradient.colors = PackedColorArray([Color.WHITE, Color(0.6, 0.6, 0.6, 1), Color.BLACK])
		var texture = GradientTexture1D.new()
		texture.gradient = gradient
		glow.set_shader_parameter("fresnel_gradient", texture)
		glow.set_shader_parameter("fresnel_exponent", 1.3)
		glow.set_shader_parameter("proximity_fade", false)
	if settings.name == "VFX_Healing_R1":
		var flecks = node.get_node("smallparticles4")
		flecks.amount = 24
		flecks.lifetime = 0.85
		flecks.process_material = flecks.process_material.duplicate(true)
		flecks.process_material.directional_velocity_max = 2.0
		flecks.process_material.radial_velocity_max = 0.8
		var wisp = node.get_node("verticalflash2")
		wisp.amount = 1
		wisp.one_shot = true
		wisp.explosiveness = 1.0
		wisp.lifetime = 1.15
		wisp.position.x = -0.48
		wisp.position.y = 1.15
		wisp.scale = Vector3(1.6, 0.75, 1.0)
		wisp.process_material = wisp.process_material.duplicate(true)
		wisp.process_material.emission_sphere_radius = 0.08
		wisp.process_material.gravity = Vector3(0, 0.1, 0)
		var other = wisp.duplicate()
		other.name = "SecondWisp"
		other.position.x = 0.48
		other.position.y = 0.9
		other.scale = Vector3(1.25, 0.85, 1.0)
		other.emitting = true
		node.add_child(other)
	if settings.name == "VFX_Dark_sword":
		node.get_node("PurpleSword").layers = 0
	if settings.name == "vfx_status_magic":
		node.set_script(null)
		for particles in node.find_children("*", "GPUParticles3D", true, false):
			particles.amount = 3
			particles.lifetime = 0.7
			particles.process_material = particles.process_material.duplicate(true)
			particles.process_material.emission_shape_scale = Vector3(1, 0.5, 1)
			particles.process_material.emission_sphere_radius = 0.8
			particles.process_material.orbit_velocity_curve = null
			particles.process_material.radial_velocity_min = -1.0
			particles.process_material.radial_velocity_max = -1.0
			particles.process_material.scale_min = 0.2
			particles.process_material.scale_max = 0.4
