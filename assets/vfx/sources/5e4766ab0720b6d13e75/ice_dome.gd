extends "res://assets/vfx/sources/eabc1f79d6ef50cb7665/ice_dome_surface_breakup.gd"
const Restore = preload("res://assets/vfx/sources/ceff5437bd2fda002c72/restore.gd")
var bank: Resource
var runtime_materials: Array[ShaderMaterial] = []
var runtime_geometry: Array = []
var runtime_break_sources: Array[MeshInstance3D] = []
var source_transform_known := false
var previous_source_transform := Transform3D.IDENTITY

static func preparation_resources(input: Dictionary) -> Array:
	return Restore.preparation_resources(input)

static func make_component(input: Dictionary) -> Node3D:
	return Restore.make("res://assets/vfx/sources/5e4766ab0720b6d13e75/ice_dome.gd", input)

func _ready() -> void:
	assembly_breakup.attach_world(self)

func sample(seconds: float) -> void:
	if not is_finite(seconds):
		return
	var desired := int(round(seconds * float(parameters.simulation_hz)))
	Restore.update_source_transform(self)
	var event_tick := int(ceil(4.1 * float(parameters.simulation_hz)))
	if tick < event_tick and desired >= event_tick:
		tick = event_tick
		update_ice(float(tick) / float(parameters.simulation_hz))
	if tick < desired:
		tick = desired
		update_ice(float(tick) / float(parameters.simulation_hz))
	Restore.update_source_transform(self)
	update_geometry()

func update_ice(age: float) -> void:
	# Source surface-breakup law, unchanged; each frost flake's original
	# independent opacity is now one native instance float rather than a material.
	var break_age := age - 4.1
	if not ice_broken and break_age >= 0.0:
		_transfer_surface(age)
	var expiry := 1.0 - smoothstep(7.2, 7.95, age)
	ice_material.set_shader_parameter("age", age)
	ice_material.set_shader_parameter("opacity", expiry * (1.0 if not ice_broken else 1.0 - smoothstep(1.5, 2.3, break_age)))
	ice_whole.visible = not ice_broken
	assembly_breakup.sync_uniforms(["age", "opacity", "factory_world_to_source"])
	if age >= 6.4:
		assembly_breakup.retire()
	var air_opacity := expiry * smoothstep(0.0, .4, break_age)
	ice_air_material.set_shader_parameter("opacity", air_opacity)
	var clock := fposmod(age, 4.0) / 4.0
	for index in ice_flakes.size():
		var phase := fposmod(clock + float(index) * .61803398875, 1.0)
		var angle := float(index) / 24.0 * TAU
		var phi := .25 + float(index % 6) / 6.0 * 1.20
		var point := sphere_position(angle, phi, RADIUS)
		point.y -= .25 * phase
		ice_flakes[index].position = point
		ice_flakes[index].set_instance_shader_parameter("solid_flake_opacity",
			air_opacity * .36 * smoothstep(0.0, .14, phase) * (1.0 - smoothstep(.8, 1.0, phase)))

func _transfer_surface(age: float) -> void:
	assembly_breakup.transfer(self, runtime_break_sources, subject.global_transform,
		bank.break_motions, parameters.source_breakup)
	ice_whole.hide()
	ice_broken = true
	collider.collision_layer = 0
	transfer_source_age_seconds = age

func source_bindings() -> Dictionary:
	return Restore.source_bindings(self)

func set_root_path(_value: Transform3D) -> void:
	Restore.update_source_transform(self)

func capture_observation() -> Dictionary:
	return {"ice_dome_surface_breakup":assembly_breakup.observation(),
		"source_surface_partition":bank.provenance.surface_partition,
		"native_tick":tick, "source_frost_flakes":ice_flakes.size(),
		"intact_whole_visible":ice_whole.visible, "optical_lights":0}

func _exit_tree() -> void:
	assembly_breakup.close()
