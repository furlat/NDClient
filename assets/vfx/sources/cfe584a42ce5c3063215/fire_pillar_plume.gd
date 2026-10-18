extends "res://assets/vfx/sources/8302a6453a9f295d55ac/fire_pillar_layers.gd"
## Native fire particles fill the beam volume instead of stacked torch meshes.
const FIRE_SCENE = "res://assets/vfx/sources/d74ab0e4f52430350276/VFX_FireDynamic_T1.tscn"
var flame_emitter: GPUParticles3D


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/cfe584a42ce5c3063215/fire_pillar_plume.gd", input)


func apply_scene_edits(node: Node) -> void:
	var original: Node3D = VfxPackageIO_cfe584a42c.resource(FIRE_SCENE).instantiate()
	ResourceGraph.native_sampler_scopes += 1
	ResourceGraph.isolate_node(original, {})
	ResourceGraph.native_sampler_scopes -= 1
	flame_emitter = original.get_node("firex")
	flame_emitter.owner = null
	original.remove_child(flame_emitter)
	node.add_child(flame_emitter)
	original.free()
	flame_emitter.name = "NativeFireColumnPlume"
	flame_emitter.emitting = false
	flame_emitter.position = Vector3(0, 22, 0)
	flame_emitter.amount = 140
	flame_emitter.lifetime = .55
	flame_emitter.use_fixed_seed = true
	flame_emitter.seed = 47297
	flame_emitter.local_coords = true
	flame_emitter.fixed_fps = 144
	var process: ParticleProcessMaterial = flame_emitter.process_material
	process.emission_ring_height = 40.0
	process.emission_ring_radius = 3.8
	process.emission_ring_inner_radius = 0.0
	process.initial_velocity_min = 3.0
	process.initial_velocity_max = 7.0
	process.angle_min = -12.0
	process.angle_max = 12.0
	process.scale_min = 3.0
	process.scale_max = 4.0
	# Beam calibration compresses local Y (.35) relative to X/Z (1.25).
	# Compensate the new particle cards, not the accepted beam or world area.
	var quad: QuadMesh = flame_emitter.draw_pass_1
	quad.size = Vector2(.75, 4.0)
	# The donor's three fire colours all have value about 1. At this density
	# they flatten into orange. Use this spell's existing dark-to-hot palette
	# through the same source smoke mask; keep its original erosion/alpha.
	var original_texture: GradientTexture1D = flame_emitter.material_override.get_shader_parameter("Color_1D_Gradient")
	var palette_gradient := Gradient.new()
	var colors := PackedColorArray()
	var offsets := PackedFloat32Array()
	for index in settings.palette.size():
		colors.append(Color.html(str(settings.palette[index])))
		offsets.append(float(index) / float(settings.palette.size() - 1))
	palette_gradient.colors = colors
	palette_gradient.offsets = offsets
	# Alpha is source geometry: the ramp masks the billboard perimeter.
	# Preserve every original alpha knot while changing RGB only.
	for offset in original_texture.gradient.offsets:
		if not offsets.has(offset):
			offsets.append(offset)
	offsets.sort()
	colors.clear()
	for offset in offsets:
		var color: Color = palette_gradient.sample(offset)
		color.a = original_texture.gradient.sample(offset).a
		colors.append(color)
	var gradient := Gradient.new()
	gradient.offsets = offsets
	gradient.colors = colors
	var texture := GradientTexture1D.new()
	texture.gradient = gradient
	flame_emitter.material_override.set_shader_parameter("Color_1D_Gradient", texture)
	flame_emitter.material_override.set_meta("native_strike_plume", true)
	super.apply_scene_edits(node)


func adapt_shader(material: ShaderMaterial) -> void:
	super.adapt_shader(material)
	var addition: String = ""
	if material.get_meta("original_strike_repair_layer", "") == "outter_rays":
		addition = "\nALPHA*=0.12;\n"
	elif material.get_meta("native_strike_plume", false):
		addition = "\nALBEDO*=0.22;EMISSION*=0.22;ALPHA*=0.35;\n"
	if addition.is_empty():
		return
	var shader := Shader.new()
	shader.code = Finish.finish_fragment(material.shader.code.replace("depth_draw_opaque", "depth_draw_never"), addition)
	Finish.replace_shader(material, shader)


func advance_lifecycle(delta: float) -> void:
	super.advance_lifecycle(delta)
	var seconds: float = float(tick) / float(parameters.simulation_hz)
	flame_emitter.emitting = seconds >= .12 and seconds < 1.8


func capture_observation() -> Dictionary:
	var result: Dictionary = super.capture_observation()
	result["native_fire_scene"] = FIRE_SCENE
	result["native_fire_emitter_count"] = 1
	result["stacked_torch_meshes"] = false
	return result

const VfxPackageIO_cfe584a42c = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
