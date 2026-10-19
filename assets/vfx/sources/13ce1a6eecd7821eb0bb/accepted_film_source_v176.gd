extends RefCounted
## Evaluates the unmodified accepted Film source. This source-only viewport
## reproduces its archived capture projection; it is not an actor/stage camera.
## Finishing belongs to the actor material, never to an exported sprite bank.
const Sources = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")

static func frame_seconds(age: float) -> float:
	return float(posmod(int(floor(maxf(age, 0.0) * 32.0)), 64)) / 32.0


static func make(parent: Node, specification: Dictionary) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(384, 384)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_2X
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	parent.add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color(0, 0, 0, 0)
	settings.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.environment = settings
	world.add_child(environment)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 384.0 / (64.0 * sqrt(2.0))
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	var target := Vector3(0, .9 * .816496580927726, 0)
	camera.position = target + Vector3(6.0, sqrt(24.0), 6.0)
	camera.look_at(target)
	var subject := Node3D.new()
	subject.scale.y = .816496580927726
	world.add_child(subject)
	var quad := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = Vector2(3.8, 3.8)
	quad.mesh = mesh
	var material := ShaderMaterial.new()
	material.shader = VfxPackageIO_13ce1a6eec.resource(str(specification.shader))
	# Compatibility's unshaded output stored the source ALBEDO scalar directly.
	# Forward+ sRGB-encodes that scalar on output. Invert only that output
	# encoding before its automatic encode; the preserved Film math is intact.
	# Selection is explicit source data, not a spell-name/renderer guess.
	if specification.get("capture_encoding", "") == "gl_compatibility_unshaded":
		var original: Shader = material.shader
		var shader := Shader.new()
		shader.code = Sources.finish_fragment(original.code, "\nALBEDO=mix(ALBEDO/12.92,pow((ALBEDO+vec3(.055))/1.055,vec3(2.4)),greaterThan(ALBEDO,vec3(.04045)));\n")
		shader.set_meta("factory_original_film_shader", original)
		material.shader = shader
	material.set_shader_parameter("flow_tex", VfxPackageIO_13ce1a6eec.resource(str(specification.noise)))
	quad.material_override = material
	quad.position.y = .9
	quad.rotation.y = PI / 4.0
	quad.rotation.x = -asin(1.0 / sqrt(3.0))
	subject.add_child(quad)
	return {"viewport": viewport, "material": material, "camera": camera, "quad": quad,
		"subject": subject, "requested_age": -1.0, "closed": false}


static func sample(surface: Dictionary, age: float) -> void:
	if surface.closed:
		return
	var seconds := frame_seconds(age)
	if surface.requested_age == seconds:
		return
	surface.material.set_shader_parameter("clock", seconds)
	surface.requested_age = seconds
	surface.viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


static func close(surface: Dictionary) -> void:
	if surface.closed:
		return
	surface.closed = true
	if is_instance_valid(surface.viewport):
		surface.viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		surface.viewport.queue_free()

const VfxPackageIO_13ce1a6eec = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
