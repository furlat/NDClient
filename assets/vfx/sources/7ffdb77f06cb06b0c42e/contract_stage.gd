extends RefCounted


## One shared World3D for correlated viewport readback. No recipe-specific defaults.
static func vector(value: Array) -> Vector3:
	return Vector3(value[0], value[1], value[2])


static func make(parent: Node, contract: Dictionary) -> Dictionary:
	var world := World3D.new()
	var viewports: Dictionary = {}
	var palette_materials: Array[ShaderMaterial] = []
	var camera_tracks: Array[Dictionary] = []
	var first_viewport: SubViewport
	for group in contract.capture_groups:
		for view in group.views:
			var viewport := SubViewport.new()
			viewport.size = Vector2i(view.size_pixels[0], view.size_pixels[1])
			viewport.transparent_bg = contract.environment.transparent
			viewport.msaa_3d = int(contract.environment.msaa_3d)
			viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			viewport.world_3d = world
			parent.add_child(viewport)
			viewports[view.id] = viewport
			if first_viewport == null:
				first_viewport = viewport
			var camera := Camera3D.new()
			camera.projection = Camera3D.PROJECTION_ORTHOGONAL
			camera.keep_aspect = Camera3D.KEEP_WIDTH
			camera.size = float(view.ortho_size)
			viewport.add_child(camera)
			camera.position = vector(view.position)
			camera.look_at(vector(view.target))
			camera.current = true
			if view.has("follow"):
				camera_tracks.append(
					{
						"camera": camera,
						"base": camera.position,
						"component": view.follow.component,
						"path": view.follow.path
					}
				)
			if contract.has("palette_pass"):
				palette_materials.append(add_palette_pass(viewport, contract.palette_pass))
	var scene := Node3D.new()
	first_viewport.add_child(scene)
	var profile: Dictionary = contract.environment
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(
		profile.clear_color[0],
		profile.clear_color[1],
		profile.clear_color[2],
		profile.clear_color[3]
	)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(
		profile.ambient_color[0], profile.ambient_color[1], profile.ambient_color[2]
	)
	environment.ambient_light_energy = profile.ambient_energy
	environment.tonemap_mode = int(profile.tonemap_mode)
	environment.tonemap_exposure = profile.exposure
	environment.glow_enabled = profile.glow_enabled
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	scene.add_child(world_environment)
	for light_profile in profile.lights:
		var light := DirectionalLight3D.new()
		light.rotation_degrees = vector(light_profile.rotation_degrees)
		light.light_color = Color(
			light_profile.color[0], light_profile.color[1], light_profile.color[2]
		)
		light.light_energy = light_profile.energy
		light.shadow_enabled = light_profile.shadow_enabled
		scene.add_child(light)
	return {
		"scene": scene,
		"viewports": viewports,
		"palette_materials": palette_materials,
		"camera_tracks": camera_tracks
	}


static func palette_texture(colors: Array) -> ImageTexture:
	var image := Image.create(colors.size(), 1, false, Image.FORMAT_RGBA8)
	for index in colors.size():
		image.set_pixel(index, 0, Color(colors[index]))
	return ImageTexture.create_from_image(image)


static func add_palette_pass(viewport: SubViewport, profile: Dictionary) -> ShaderMaterial:
	var layer := CanvasLayer.new()
	viewport.add_child(layer)
	var rectangle := ColorRect.new()
	rectangle.size = Vector2(viewport.size)
	var material := ShaderMaterial.new()
	material.shader = VfxPackageIO_7ffdb77f06.resource(profile.shader)
	material.set_shader_parameter("palette_texture", palette_texture(profile.palette))
	material.set_shader_parameter("palette_count", profile.palette.size())
	material.set_shader_parameter("ramp_count", 0)
	if profile.has("ramp") and not profile.ramp.is_empty():
		material.set_shader_parameter("ramp_texture", palette_texture(profile.ramp))
		material.set_shader_parameter("ramp_count", profile.ramp.size())
	for key in profile.parameters:
		material.set_shader_parameter(key, profile.parameters[key])
	rectangle.material = material
	layer.add_child(rectangle)
	return material


static func sample_palette(stage: Dictionary, profile: Dictionary, seconds: float) -> void:
	for uniform_name in profile.get("uniform_tracks", {}):
		var track: Dictionary = profile.uniform_tracks[uniform_name]
		var keys: Array = track.keys
		var value: float = float(keys[0][1])
		for index in range(1, keys.size()):
			var previous: Array = keys[index - 1]
			var next: Array = keys[index]
			if seconds >= float(next[0]):
				value = float(next[1])
				continue
			var weight: float = clampf(
				(seconds - float(previous[0])) / (float(next[0]) - float(previous[0])), 0.0, 1.0
			)
			if track.interpolation == "smoothstep":
				weight = weight * weight * (3.0 - 2.0 * weight)
			value = lerpf(float(previous[1]), float(next[1]), weight)
			break
		for material in stage.palette_materials:
			material.set_shader_parameter(uniform_name, value)


static func sample_cameras(stage: Dictionary, components: Dictionary) -> String:
	for track in stage.camera_tracks:
		var target: Node3D = components[track.component].get_node_or_null(NodePath(track.path))
		if target == null:
			return "Missing declared camera follow target: " + str(track.path)
		track.camera.position = track.base + target.global_position
	return ""


static func release(stage: Dictionary) -> void:
	# Exit renderable geometry before destroying lights/worlds, avoiding renderer
	# cull-index teardown errors observed with the native spectral-hand donor.
	for node in stage.scene.find_children("*", "GeometryInstance3D", true, false):
		if node.get_parent() != null:
			node.get_parent().remove_child(node)
			node.queue_free()

const VfxPackageIO_7ffdb77f06 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
