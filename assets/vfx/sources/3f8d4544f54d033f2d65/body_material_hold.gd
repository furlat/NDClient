extends Node3D
## Public material-input provider for separate unaccepted art candidates.
## The source donor is always hidden. The actual renderer composes this sample
## through its existing BodySurfaces API; raw source construction draws nothing.
var source: Node3D
var material: ShaderMaterial
var settings: Dictionary = {}
var owner_binding: Dictionary = {}
var owner_state: Dictionary = {}
var surface_parameters: Dictionary = {}
var clock := 0.0

static func make_component(input: Dictionary) -> Node3D:
	var result = VfxPackageIO_3f8d4544f5.resource("res://assets/vfx/sources/3f8d4544f54d033f2d65/body_material_hold.gd").new()
	result.settings = input.duplicate(true)
	result.source = VfxPackageIO_3f8d4544f5.resource(str(input.source_constructor)).make_component(input.source_input)
	result.add_child(result.source)
	result.source.hide()
	result.source.set_process(false)
	for emitter in result.source.find_children("*","GPUParticles3D",true,false):
		emitter.emitting = false
	result.material = result.source.get_node(str(input.material_node)).get_active_material(0)
	assert(result.material != null and result.material.get_shader_parameter("noise_texture") is Texture2D,"Candidate requires its original native body material/noise")
	# BodySurfaces consumes uniform values, not the donor's fragment program.
	# The source adapters neutralize Aid/Bless before their later palette finish;
	# copying those intermediate colours loses both selected spell palettes.
	var flow: Dictionary = input.surface_material
	var native_noise: NoiseTexture2D = result.material.get_shader_parameter("noise_texture")
	assert(native_noise.noise is FastNoiseLite, "Candidate requires its selected native noise generator")
	var flow_texture: NoiseTexture2D = native_noise.duplicate(true)
	var flow_noise: FastNoiseLite = native_noise.noise.duplicate(true)
	# The source sphere/cylinder texture has several periods per world cell.
	# The body consumer projects it three ways and has a fixed .5-.8 threshold;
	# use a private lower-frequency, softer range of that same native noise.
	flow_noise.frequency *= float(flow.noise_frequency_multiplier)
	flow_texture.noise = flow_noise
	var gradient := Gradient.new()
	var value_range: Array = flow.noise_value_range
	gradient.colors = PackedColorArray([
		Color(value_range[0], value_range[0], value_range[0]),
		Color(value_range[1], value_range[1], value_range[1])
	])
	flow_texture.color_ramp = gradient
	result.surface_parameters = {
		"body_surface_texture": flow_texture,
		"body_surface_primary": Color.html(str(flow.primary)),
		"body_surface_secondary": Color.html(str(flow.secondary)),
		"body_surface_tertiary": Color.html(str(flow.tertiary)),
		"body_surface_noise_scale": Vector2(flow.noise_scale[0], flow.noise_scale[1]),
		"body_surface_scroll": Vector2(flow.scroll[0], flow.scroll[1]),
		"body_surface_twist": float(flow.twist),
		"body_surface_waviness": float(flow.waviness),
		"body_surface_emission": float(flow.emission),
		"body_surface_scale": float(flow.scale)
	}
	return result

func set_owner_binding(value: Dictionary) -> void:
	owner_binding = value.duplicate(false)
	owner_state = {}

func set_owner_state(value: Dictionary) -> void:
	owner_state = value

func sample(seconds: float) -> void:
	clock = seconds
	# This is not a free shell fallback, even if no consumer requests material.
	source.hide()

func body_surface_sample(actual_actor_uuid: String) -> Dictionary:
	if str(owner_binding.get("owner_uuid","")).is_empty() or str(owner_binding.get("actor_uuid","")) != actual_actor_uuid or actual_actor_uuid.is_empty(): return {}
	if owner_state.get("owner_uuid") != owner_binding.owner_uuid or owner_state.get("actor_uuid") != actual_actor_uuid: return {}
	if owner_state.get("suppressed",false) or not owner_state.get("visible",false): return {}
	var phase := str(owner_state.get("phase",""))
	if phase not in ["application","sustain","removal"]: return {}
	var age_value: Variant = owner_state.get("phase_age_seconds")
	if not (age_value is float or age_value is int) or not is_finite(float(age_value)) or float(age_value)<0.0 or not is_finite(clock): return {}
	var age := float(age_value)
	var envelope := 1.0
	if phase == "application": envelope = smoothstep(0.0,float(settings.application_seconds),age)
	elif phase == "removal": envelope = 1.0-smoothstep(0.0,float(settings.removal_seconds),age)
	if envelope<=0.0:return {}
	var result: Dictionary = surface_parameters.duplicate(false)
	result.merge({"id":"unaccepted-material:"+str(owner_binding.owner_uuid),"kind":"body_surface","actor_uuid":actual_actor_uuid,
		"body_surface_strength":float(settings.strength)*envelope,"body_surface_clock":clock})
	return result

const VfxPackageIO_3f8d4544f5 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
