extends "res://assets/vfx/extensions/production-review-20261020/sources/63efbe77094fc90312ab/item_flame.gd"
## Source-qualified new held-loop candidate. Native draw math/absolute phase
## are retained; only the explicitly authored particle hold is looped/blended.
const HoldProcess = preload("res://assets/vfx/extensions/production-review-20261020/sources/e2ac0833a7405937cab5/flame_hold_process.gdshader")
const HoldClock = preload("res://assets/vfx/extensions/production-review-20261020/sources/398daa30f682e7bf644b/flame_hold_clock.gd")
var hold_bank: Resource
var systems: Array[GPUParticles3D] = []
var process_materials: Array[ShaderMaterial] = []
var absolute_source_tick := 0


func build(bank: Resource, input: Dictionary) -> void:
	assert(bank.interface_ready)
	hold_bank = bank
	settings = input.duplicate(true)
	for half in 2:
		var emitter := GPUParticles3D.new()
		emitter.name = "SourceHoldHalf%d" % half
		emitter.transform = bank.emitter_transform
		emitter.amount = bank.particle_count
		emitter.local_coords = true
		emitter.emitting = true
		emitter.speed_scale = 1.0
		emitter.lifetime = 1000000.0
		emitter.explosiveness = 1.0
		emitter.randomness = 0.0
		emitter.fixed_fps = 0
		emitter.interpolate = false
		emitter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		emitter.draw_order = int(bank.source_properties.draw_order)
		emitter.visibility_aabb = bank.source_properties.visibility_aabb
		emitter.draw_pass_1 = bank.draw_mesh
		var material: ShaderMaterial = bank.draw_material.duplicate(false)
		emitter.material_override = material
		materials.append(material)
		var process := ShaderMaterial.new()
		process.shader = HoldProcess
		process.set_shader_parameter("hold_data", bank.particle_data)
		process.set_shader_parameter("hold_period", bank.hold_end_seconds - bank.hold_start_seconds)
		process.set_shader_parameter("half_phase", float(half) * (bank.hold_end_seconds - bank.hold_start_seconds) * .5)
		process.set_meta("factory_prepared_shader", HoldProcess)
		process.set_meta("factory_recorded_time_shader", HoldProcess)
		process.set_meta("factory_clock_names", [])
		process.set_meta("factory_clock_pool_required", false)
		emitter.process_material = process
		process_materials.append(process)
		systems.append(emitter)
		add_child(emitter)


func set_item_snapshot(value: Dictionary) -> void:
	packet = value.duplicate(true)
	refresh_item_binding()


func refresh_item_binding() -> void:
	occurrence_alpha = 1.0 if admitted() else 0.0
	for material: ShaderMaterial in materials:
		material.set_shader_parameter(NativeOpacity.UNIFORM, occurrence_alpha)
		material.set_shader_parameter("factory_world_to_source", Projection(global_transform.affine_inverse()))


func sample(seconds: float) -> void:
	source_seconds = maxf(0.0, seconds)
	absolute_source_tick = roundi(source_seconds * hold_bank.source_hz)
	# This is the original source controller's integer144Hz absolute clock.
	# It never uses a wrapped particle coordinate as owner/material age.
	var native_age := float(absolute_source_tick) / float(hold_bank.source_hz)
	var period := float(hold_bank.hold_end_seconds - hold_bank.hold_start_seconds)
	var cursor := fposmod(native_age, period)
	for process: ShaderMaterial in process_materials:
		process.set_shader_parameter("hold_cursor", cursor)
	for material: ShaderMaterial in materials:
		material.set_shader_parameter(HoldClock.ABSOLUTE, native_age)
		material.set_shader_parameter("support_age", native_age)
		material.set_shader_parameter("support_clock", native_age)
		material.set_shader_parameter("support_envelope", 1.0)
	refresh_item_binding()


func source_bindings() -> Dictionary:
	return {"geometry": systems, "materials": materials + process_materials,
		"recorded_time_emitters": systems, "players": [], "lights": [],
		"static_material_topology": true, "static_geometry_layers": true}


func capture_observation() -> Dictionary:
	return {"item_uuid": settings.item_uuid, "effect_uuid": settings.effect_uuid,
		"holder_uuid": settings.holder_uuid, "source_seconds": source_seconds,
		"absolute_source_tick": absolute_source_tick, "occurrence_alpha": occurrence_alpha,
		"rejection": rejection, "particle_hold_seconds": [hold_bank.hold_start_seconds, hold_bank.hold_end_seconds],
		"new_art_derivative": true, "original_native_rng_sequence_claimed": false,
		"physical_item_replaced": false, "optical_lights": 0}
