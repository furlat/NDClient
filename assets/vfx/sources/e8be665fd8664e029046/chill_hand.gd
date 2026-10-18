extends "res://assets/vfx/sources/843204815cdceaac8544/clocked_source.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance = construct("res://assets/vfx/sources/e8be665fd8664e029046/chill_hand.gd", input)
	# The native sandbox retains the full source composition, including its light.
	if instance.settings.get("source_materials_only", false):
		return instance
	# This source light is unkeyed and has exactly zero energy. Remove it before
	# tree insertion: Godot 4.6.2 cull teardown reports errors for the inert light.
	var light: OmniLight3D = instance.subject.get_node("OmniLight3D")
	if light.light_energy != 0.0:
		push_error("Chill source zero-energy light contract changed")
		instance.free()
		return null
	light.free()
	return instance


func green(c: Color) -> Color:
	if c.s < 0.12:
		return c
	return Color.from_hsv(0.30 + (c.h - 0.5) * 0.04, c.s, c.v, c.a)


func visit_resource(r: Resource) -> void:
	if r == null or visited.has(r.get_instance_id()):
		return
	visited[r.get_instance_id()] = true
	for p in r.get_property_list():
		if not (int(p.usage) & PROPERTY_USAGE_STORAGE):
			continue
		var v = r.get(p.name)
		if v is Color:
			r.set(p.name, green(v))
		elif v is PackedColorArray:
			var changed := PackedColorArray()
			for c in v:
				changed.append(green(c))
			r.set(p.name, changed)
		elif v is Resource:
			visit_resource(v)


func visit_node(n: Node) -> void:
	for p in n.get_property_list():
		if int(p.usage) & PROPERTY_USAGE_STORAGE:
			var v = n.get(p.name)
			if v is Color:
				n.set(p.name, green(v))
			elif v is Resource:
				visit_resource(v)
	if n is MeshInstance3D and n.mesh != null:
		for i in n.mesh.get_surface_count():
			visit_resource(n.get_active_material(i))
	if n is AnimationPlayer:
		for library_name in n.get_animation_library_list():
			var library = n.get_animation_library(library_name)
			for animation_name in library.get_animation_list():
				var anim = library.get_animation(animation_name)
				for track in anim.get_track_count():
					for key in anim.track_get_key_count(track):
						var value = anim.track_get_key_value(track, key)
						if value is Color:
							anim.track_set_key_value(track, key, green(value))
	for child in n.get_children():
		visit_node(child)


func recolor_source(node: Node) -> void:
	visit_node(node)


func apply_scene_edits(node: Node) -> void:
	recolor_source(node)
	visited.clear()
	# Keep the authored necrotic material, not sprite-export geometry/cropping.
	if settings.get("source_materials_only", false):
		return
	for path in [
		"debirs_mini_FINAL",
		"debirs_mini_A",
		"SmCrackaura1998",
		"Decal",
		"portal",
		"muzzle2start",
		"muzzle2end"
	]:
		var fragment = node.get_node_or_null(path)
		if fragment is VisualInstance3D:
			fragment.layers = 0
	var hand = node.get_node_or_null("punch")
	if hand is Node3D:
		hand.scale *= 1.2
	var puff = node.get_node_or_null("portaldustring2")
	if puff != null:
		puff.position *= 1.2
		puff.process_material = puff.process_material.duplicate(true)
		puff.process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		puff.process_material.emission_sphere_radius = 1.5
		puff.process_material.scale_min = 5.0
		puff.process_material.scale_max = 7.0
		puff.process_material.color = Color(3, 3, 3, 1)
	node.rotation.x = PI / 2.0


var smoke_tick := 0


func advance_lifecycle(delta: float) -> void:
	super.advance_lifecycle(delta)
	# The complete native animation owns emission and retirement in the sandbox.
	if settings.get("source_materials_only", false):
		return
	if get_child_count() == 0:
		return
	smoke_tick += 1
	if smoke_tick >= 236:
		var smoke = subject.get_node_or_null("portaldustring2")
		if smoke is VisualInstance3D:
			smoke.layers = 0
