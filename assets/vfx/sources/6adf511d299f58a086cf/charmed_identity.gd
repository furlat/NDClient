extends Node3D
## One genuine Charmed body family plus its original single overhead asset.
## Current receiving geometry supplies placement; supplied state owns lifetime.
const HeartSource = preload("res://assets/vfx/sources/062930224d4035e4235f/charmed_source.gd")
const Frame = preload("res://assets/vfx/sources/02d90ce9caaa3a5e1100/receiving_frame.gd")
const Sources = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")

var settings: Dictionary = {}
var surface: Dictionary = {}
var body: Node3D
var marker: MeshInstance3D
var local_clock := 0.0
var owner_visibility := 1.0
var current_state: Dictionary = {}
var envelope := 0.0
var measured: Dictionary = {}
var removed := false
var removal_seconds := -1.0

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = VfxPackageIO_6adf511d29.resource("res://assets/vfx/sources/6adf511d299f58a086cf/charmed_identity.gd").new()
	instance.settings = input.duplicate(true)
	instance.current_state = input.initial_owner_state.duplicate(true)
	instance.body = HeartSource.make_component(input.source)
	instance.add_child(instance.body)
	instance.body.scale = Vector3.ONE * float(input.source_scale)
	instance.marker = MeshInstance3D.new()
	instance.marker.name = "OneOriginalCharmedMarker"
	var quad := QuadMesh.new()
	quad.size = Vector2(.34, .34)
	instance.marker.mesh = quad
	instance.marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = "shader_type spatial; render_mode unshaded,cull_disabled; uniform sampler2D original_charmed:source_color,filter_nearest,repeat_disable; uniform float condition_alpha=0.; void fragment(){vec4 source=texture(original_charmed,UV); ALBEDO=source.rgb; ALPHA=source.a*condition_alpha;}"
	material.shader = shader
	material.set_shader_parameter("original_charmed", Sources.raw_texture(input.marker_texture))
	instance.marker.material_override = material
	instance.add_child(instance.marker)
	return instance

func set_entity_geometry(value: Dictionary) -> void:
	surface = value if str(value.get("actor", "")) == str(settings.actor) else {}
	_rebind()

func set_owner_state(value: Dictionary) -> void:
	_accept_state(value)
	sample(local_clock)

func _accept_state(value: Dictionary) -> void:
	if str(value.get("owner_uuid", "")) != str(settings.owner_uuid):
		return
	if removed:
		return
	current_state = value.duplicate(true)
	if not bool(value.get("present", false)):
		removed = true
		removal_seconds = float(value.get("observed_at_seconds", local_clock))

func set_owner_visibility(value: float) -> void:
	owner_visibility = clampf(value, 0.0, 1.0)
	sample(local_clock)

func _admitted() -> bool:
	return str(current_state.get("owner_uuid", "")) == str(settings.owner_uuid) \
		and bool(current_state.get("present", false)) and bool(current_state.get("observed", false)) \
		and not bool(current_state.get("suppressed", false))

func sample(seconds: float) -> void:
	local_clock = seconds
	# Offline fixtures supply actual observation timestamps. This performs no
	# turn, damage, expiry or eligibility calculation. Live callers may supply
	# the same owner/state directly instead of these explicit recorded rows.
	for observation in settings.get("owner_observations", []):
		if seconds >= float(observation.seconds):
			var state: Dictionary = observation.state.duplicate(true)
			state.owner_uuid = settings.owner_uuid
			state.observed_at_seconds = observation.seconds
			_accept_state(state)
	envelope = smoothstep(0.0, .16, seconds) * owner_visibility
	if not _admitted():
		if removed and bool(current_state.get("observed", false)) and not bool(current_state.get("suppressed", false)):
			envelope *= 1.0 - smoothstep(removal_seconds, removal_seconds + .2, seconds)
		else:
			envelope = 0.0
	body.sample(seconds)
	for material in body.materials:
		material.set_shader_parameter("support_envelope", envelope)
	marker.material_override.set_shader_parameter("condition_alpha", envelope)
	_rebind()

func _rebind() -> void:
	measured = Frame.measure(surface)
	if measured.is_empty():
		hide()
		return
	show()
	var scale_factor := float(settings.source_scale)
	body.global_transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * scale_factor), surface.origin)
	for emitter in body.subject.find_children("*", "GPUParticles3D", true, false):
		if emitter.layers == 0:
			continue
		emitter.position = body.to_local(Vector3(measured.centre.x, measured.bottom + measured.height*.58, measured.centre.z))
		emitter.process_material.emission_shape_scale = Vector3(measured.half_width*.85, measured.height*.18, measured.half_width*.6)/scale_factor
	marker.global_position = Vector3(measured.centre.x, measured.top + .22, measured.centre.z)
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera != null:
		marker.global_basis = camera.global_basis.orthonormalized()

func capture_observation() -> Dictionary:
	return {"charmed_identity": {"clock":local_clock,"owner_uuid":settings.owner_uuid,"owner_admitted":_admitted(),"owner_state":current_state,"removed_at":removal_seconds,"envelope":envelope,"measured_points":surface.get("points",[]).size(),"original_particles_per_emitter":7,"original_marker_count":1,"marker_texture":settings.marker_texture,"source_scale":settings.source_scale,"optical_lights":0,"local_solver":false}}

const VfxPackageIO_6adf511d29 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
