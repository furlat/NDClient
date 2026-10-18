extends "res://assets/vfx/sources/752df28aa85051b2b1f8/aoe_tile.gd"
const ReadonlyGeometry = preload("res://assets/vfx/sources/43ecfb8ee79a6dbe5e2e/readonly_geometry.gd")
## Whole approved flame cone / cube crest, using the shared clock and extraction.
static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/732c0fdb5f3590e9c5df/approved_aoe_whole.gd", input)

func clipped_material(old: Material, cell: Vector2, facing: String) -> ShaderMaterial:
	var mat := super.clipped_material(old, cell, facing)
	var code: String = mat.shader.code
	var start := code.find("\nvec3 wp=(INV_VIEW_MATRIX")
	var end := code.find("discard;\n", code.find("if ((wp.x-", start))
	if start >= 0 and end >= 0:
		code = code.substr(0, start) + code.substr(end + 9)
	mat.shader.code = code
	return mat

func apply_scene_edits(node: Node) -> void:
	if settings.spell != "burning_hands":
		super.apply_scene_edits(node)
		return
	var imported := ReadonlyGeometry.instantiate(parameters.geometry_registry)
	if imported == null:
		return
	var meshes := imported.find_children("*", "MeshInstance3D", true, false)
	assert(meshes.size() == 3, "Approved flame mesh set must contain three components")
	var source: GPUParticles3D = node.get_node("fire")
	for i in range(3):
		var emitter: GPUParticles3D = source if i == 0 else source.duplicate()
		if i > 0:
			emitter.name = "fire_variant_%d" % i
			node.add_child(emitter)
		emitter.draw_pass_1 = meshes[i].mesh
		emitter.set_meta("component_variant", i)
	imported.free()
	var player: AnimationPlayer = node.get_node("AnimationPlayer")
	for library_name in player.get_animation_library_list():
		var library: AnimationLibrary = player.get_animation_library(library_name)
		for animation_name in library.get_animation_list():
			var animation := library.get_animation(animation_name)
			var count := animation.get_track_count()
			for track in range(count):
				if str(animation.track_get_path(track)) != "fire:emitting":
					continue
				for i in [1, 2]:
					var new_track := animation.add_track(Animation.TYPE_VALUE)
					animation.track_set_path(new_track, NodePath("fire_variant_%d:emitting" % i))
					animation.value_track_set_update_mode(new_track, Animation.UPDATE_DISCRETE)
					for key in animation.track_get_key_count(track):
						animation.track_insert_key(new_track, animation.track_get_key_time(track, key), animation.track_get_key_value(track, key))
	# Shared conversion handles authored flipbooks, shaders, hue and source seeds.
	super.apply_scene_edits(node)
	var index := 0
	for child in node.find_children("*", "GPUParticles3D", true, false):
		child.seed = 47291 + index
		index += 1
		if not str(child.name).begins_with("fire"):
			continue
		child.amount = 108 if child.get_meta("component_variant", 0) == 0 else 106
		child.lifetime = 0.65
		var material: ParticleProcessMaterial = child.process_material
		material.spread = 26.565051
		material.flatness = 0.85
		material.scale_min = 0.75
		material.scale_max = 1.25
		material.lifetime_randomness = 0.28
		material.initial_velocity_min = 5.0
		material.initial_velocity_max = 8.0
		material.anim_offset_min = 0.0
		material.anim_offset_max = 0.30
		material.anim_speed_min = 0.85
		material.anim_speed_max = 1.25

func advance_lifecycle(delta: float) -> void:
	if settings.spell != "burning_hands":
		super.advance_lifecycle(delta)
		return
	tick += 1
	for mat in materials:
		mat.set_shader_parameter("source_clock", float(tick) / float(parameters.simulation_hz))
	if tick == 80:
		for player in subject.find_children("*", "AnimationPlayer", true, false):
			if player.has_animation("End"):
				player.play("End")
