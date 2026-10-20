extends "res://assets/vfx/extensions/late-20261020/sources/e590c9ae3baae472d4aa/liquid_state.gd"
## Live ground-state presentation. Explicit committed cells drive local fronts.
## No spell inference, damage, spreading rule, or independent gameplay lifetime.
const StateShader := "res://assets/vfx/extensions/late-20261020/sources/1429ef3d5c897b3c25a7/surface_states.gdshaderinc"
const SmokeScene := "res://assets/vfx/extensions/late-20261020/sources/246006a26aff271396e2/VFX_Smoke_z_puff.tscn"
const DonorScene = preload("res://assets/vfx/sources/7fb2e55699a318c2dafb/donor_scene.gd")
const ResourceGraph = preload("res://assets/vfx/sources/1d02b6d800655ef86df2/resource_graph.gd")
const SurfaceEvents = preload("res://assets/vfx/extensions/late-20261020/sources/fb7d771675b2f9a86e34/committed_surface_events.gd")
var transition_state := SurfaceEvents.new()
var contacts := PackedVector4Array()
var regions := PackedVector4Array()
var operations := PackedInt32Array()
var events: Array = []
var plumes: Array = []
var live_particles := PackedVector4Array()

static func make_component(input: Dictionary) -> Node3D:
	var instance := VfxPackageIO_979ecf1a1d.resource("res://assets/vfx/extensions/late-20261020/sources/979ecf1a1d9d8264d287/reactive_liquid.gd").new() as Node3D
	instance.settings = input.duplicate(true)
	instance.settings.charge_at = 0.0
	instance.simulation = JSON.parse_string(VfxPackageIO_979ecf1a1d.text(input.simulation))
	instance._build()
	return instance

func _build() -> void:
	super._build()
	var shader := Shader.new()
	var shared := VfxPackageIO_979ecf1a1d.text(StateShader)
	var code: String = material.shader.code.replace("void fragment(){", shared+"\nvoid fragment(){")
	code = code.replace("float frozen = freeze_fraction*freeze_front*(1.-thaw_fraction);",
		"vec4 state=factory_surface_states(point,ice_noise); float frozen=state.x;")
	code = code.replace("*retirement;", "*retirement*(1.-state.w);")
	shader.code = code
	material.shader = shader
	for selected in electricity.materials:
		var source: String = selected.shader.code
		source = source.replace("void fragment() {", shared+"\nvoid fragment() {")
		source = source.replace("if(density<.48)discard;", "if(density<.48)discard;\nif(factory_surface_states(field_point,0.).y<.08)discard;")
		var electric_shader := Shader.new()
		electric_shader.code = source
		selected.shader = electric_shader
	set_transition_events(settings.get("events", []))
	# All emitter nodes exist before native geometry/material registration. Only
	# their emission and positions change during the sequence.
	for index in int(settings.get("steam_source_count", 12)):
		var plume: GPUParticles3D = DonorScene.instantiate(VfxPackageIO_979ecf1a1d.resource(SmokeScene), [])
		ResourceGraph.isolate_node(plume, {})
		plume.name = "SourceSteam_"+str(index)
		plume.emitting = false
		plume.amount = int(settings.get("steam_particles_per_emitter", 9))
		plume.lifetime = 1.8
		plume.use_fixed_seed = true
		plume.seed = 41219+index
		plume.fixed_fps = 60
		var process: ParticleProcessMaterial = plume.process_material
		process.radial_velocity_min = .06
		process.radial_velocity_max = .10
		process.angular_velocity_min = -20.
		process.angular_velocity_max = 20.
		process.gravity = Vector3(0,.5,0)
		process.scale_min = float(settings.get("steam_particle_scale_min", .35))
		process.scale_max = float(settings.get("steam_particle_scale_max", .65))
		var smoke: ShaderMaterial = plume.material_override
		smoke.set_shader_parameter("Color", Color("b4a38b"))
		smoke.set_shader_parameter("Enable_Proximity_Fade", false)
		add_child(plume)
		plumes.append(plume)

func set_transition_events(value: Array) -> void:
	var error: String = transition_state.replace(value,["freeze","thaw","charge","vaporize","clear","uncharge"])
	if not error.is_empty():
		push_error(error)
		return
	events = transition_state.events
	contacts = transition_state.contacts
	regions = transition_state.regions
	operations = transition_state.operations
	for selected in [material]+electricity.materials:
		transition_state.bind(selected)

func set_live_particles(value: PackedVector4Array) -> void:
	if value.size()!=160:
		push_error("Native liquid field requires exactly 160 source particle samples")
		return
	live_particles = value.duplicate()

func sample(seconds: float) -> void:
	super.sample(seconds)
	if not live_particles.is_empty():
		_set_fluid(live_particles.duplicate())
		_sample_electricity(seconds,float(state_values.retirement))
	for selected in [material]+electricity.materials:
		selected.set_shader_parameter("surface_seconds",seconds)
	for index in plumes.size():
		var active := false
		var plume: GPUParticles3D = plumes[index]
		if not support_points.is_empty():
			var point: Vector3 = support_points[(index*13)%support_points.size()]
			plume.position = point+Vector3.UP*.03
			for event in events:
				if not event.operation in ["vaporize","douse"]:
					continue
				var age: float = seconds-float(event.at)
				var cell := Vector2(floor(point.x+.5),floor(point.z+.5))
				for admitted in event.cells:
					if cell==Vector2(admitted[0],admitted[1]) and age>=0. and age<float(event.get("steam_seconds",2.)):
						active = true
		plume.emitting = active
	state_values["transition_cell_records"] = contacts.size()
	state_values["footprint_owner"] = "source density; retained through freeze, thaw and charge; consumed locally on vaporize"

const VfxPackageIO_979ecf1a1d = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
