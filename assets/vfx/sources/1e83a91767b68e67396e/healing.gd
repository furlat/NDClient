extends "res://assets/vfx/sources/a4fd0883f0b17d893a03/base.gd"


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/1e83a91767b68e67396e/healing.gd", input)


func apply_scene_edits(node: Node) -> void:
	node.scale *= float(settings.scale)
	node.position.y += float(settings.height)
	if settings.pack == "binbun-statusfxfull":
		node.set_script(null)
		for particles in node.find_children("*", "GPUParticles3D", true, false):
			particles.amount = maxi(6, int(particles.amount * 0.65))
	if settings.name == "VFX_Healing_Ring_A":
		node.get_node("white_Line_horizontal").layers = 0
		node.get_node("floorflash").position.y -= 0.75 / float(settings.scale)
	if settings.name == "VFX_Healing_Area":
		# The original source encloses a wide area. Each selected recipient gets its
		# own compact curtain; the source's decorative floor seal doesn't claim AoE.
		node.get_node("symbol1").scale *= 0.72
		for ground_name in ["symbol1", "waves"]:
			node.get_node(ground_name).material_override.set_meta("support_ground", true)
	if settings.get("id", "") == "mass_heal":
		var added = (
			VfxPackageIO_1e83a91767.resource(
				"res://assets/vfx/sources/d6654b791469c50248d5/VFX_Healing_Ring_A.tscn"
			)
			. instantiate()
		)
		# This donor is added after the parent isolation pass. Each recipient
		# must own its materials/animations before the source shader is adapted.
		_isolate(added, {})
		added.name = "MassHealRadialRelease"
		added.scale = Vector3.ONE * 0.65
		added.get_node("white_Line_horizontal").layers = 0
		node.add_child(added)
		_apply_particle_seed(added)
		added.get_node("AnimationPlayer").play("Init")
	if settings.name == "VFX_Healing_Flower":
		var flower = node.get_node("am_flower_001/Armature/Skeleton3D/LilyFlower")
		var old = flower.material_override
		var shader = Shader.new()
		shader.code = "shader_type spatial; render_mode unshaded,cull_disabled; uniform vec4 flower_color:source_color=vec4(1.0); uniform sampler2D tex:source_color; void fragment(){vec4 c=texture(tex,UV)*flower_color; ALBEDO=c.rgb; ALPHA=c.a;}"
		if settings.id == "mass_heal":
			shader.code = shader.code.replace(
				"ALBEDO=c.rgb; ALPHA=c.a;", "ALBEDO=c.rgb*0.45; ALPHA=c.a*0.65;"
			)
		var mat = ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("tex", old.albedo_texture)
		mat.set_shader_parameter("flower_color", old.albedo_color)
		flower.material_override = mat
		for player in node.find_children("*", "AnimationPlayer", true, false):
			for name in player.get_animation_list():
				var a = player.get_animation(name)
				for t in a.get_track_count():
					var path = String(a.track_get_path(t))
					if path.contains("LilyFlower:material_override:albedo_color"):
						a.track_set_path(
							t,
							NodePath(path.replace("albedo_color", "shader_parameter/flower_color"))
						)
		if settings.id == "greater_restoration":
			flower.layers = 0
	if settings.name == "VFX_Healing_Area":
		# Source contains world-space particles for a large stationary area. Recipient
		# captures need the particle trajectories in the same scaled local volume.
		for particle in node.find_children("*", "GPUParticles3D", true, false):
			particle.local_coords = true
		var sparkle = node.get_node("smallparticles5")
		var old = sparkle.material_override
		var shader = Shader.new()
		shader.code = "shader_type spatial;render_mode unshaded,blend_add,cull_disabled,depth_draw_never;uniform sampler2D tex:source_color;uniform vec4 tint:source_color=vec4(1.0);void vertex(){float c=cos(INSTANCE_CUSTOM.x);float s=sin(INSTANCE_CUSTOM.x);mat4 bb=mat4((INV_VIEW_MATRIX[0]*c+INV_VIEW_MATRIX[1]*s)*length(MODEL_MATRIX[0].xyz),(-INV_VIEW_MATRIX[0]*s+INV_VIEW_MATRIX[1]*c)*length(MODEL_MATRIX[1].xyz),INV_VIEW_MATRIX[2]*length(MODEL_MATRIX[2].xyz),MODEL_MATRIX[3]);MODELVIEW_MATRIX=VIEW_MATRIX*bb;}void fragment(){vec4 c=texture(tex,UV)*tint*COLOR;ALBEDO=c.rgb;ALPHA=c.a;}"
		var sm = ShaderMaterial.new()
		sm.shader = shader
		sm.render_priority = old.render_priority
		sm.set_shader_parameter("tex", old.albedo_texture)
		sm.set_shader_parameter("tint", old.albedo_color)
		sparkle.material_override = sm
		var animation = node.get_node("AnimationPlayer").get_animation("Start")
		for track in animation.get_track_count():
			for key in animation.track_get_key_count(track):
				animation.track_set_key_time(
					track, key, animation.track_get_key_time(track, key) / 1.8
				)
		animation.length /= 1.8


func advance_lifecycle(_delta: float) -> void:
	if not is_instance_valid(subject):
		return
	tick += 1
	var age = float(tick) / 144.0
	var fade = float(settings.get("alphaGain", 1.0))
	if settings.get("id", "") == "aid":
		fade *= lerpf(1.0, 0.24, smoothstep(1.1, 1.8, age))
	if int(settings.close) > 0 and tick > int(settings.close):
		fade *= (
			1.0
			- smoothstep(float(settings.close) / 144.0, float(settings.frames - 12) / 144.0, age)
		)
	for mat in materials:
		mat.set_shader_parameter("support_clock", age)
		mat.set_shader_parameter("support_envelope", fade)
	if tick == int(settings.close):
		for particles in subject.find_children("*", "GPUParticles3D", true, false):
			particles.emitting = false
		for player in subject.find_children("*", "AnimationPlayer", true, false):
			for ending in ["close", "End"]:
				if player.has_animation(ending):
					player.play(ending)
					break

const VfxPackageIO_1e83a91767 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
