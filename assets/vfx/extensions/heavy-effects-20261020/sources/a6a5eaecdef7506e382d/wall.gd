extends Node3D
## Exact prepared source modules, native GPU state private per emitter. All
## original modules share one explicitly verified lifecycle; bindings are lowered
## offline rather than reconstructed through metadata/path queries per owner.
var bank: Resource
var source_root: Node3D
var geometry: Array = []
var materials: Array = []
var lights: Array = []
var module_roots: Array = []
var age_materials: Array = []
var clock_materials: Array = []
var envelope_materials: Array = []
var emitters: Array = []
var world_process_materials: Array = []
var tick := 0
var stopped := false
var envelope_written := false
var visible_state := true
var previous_unit_scale := 1.0
var prepared_layer_mask := 0
# Inspection only. The runtime never allocates per-module observation records.
var entries: Array:
	get:
		return debug_source_entries()

static func preparation_resources(input: Dictionary) -> Array:
	return [String(input.fire_wall_bank)]

static func make_component(input: Dictionary) -> Node3D:
	var value: Resource = VfxPackageIO_a6a5eaecde.resource(String(input.fire_wall_bank))
	assert(value != null and value.program != null, "Exact offline Fire Wall bank required")
	var instance: Node3D = VfxPackageIO_a6a5eaecde.resource("res://assets/vfx/extensions/heavy-effects-20261020/sources/a6a5eaecdef7506e382d/wall.gd").new()
	instance.bank = value
	var made: Dictionary = value.program.instantiate(value.operands)
	instance.source_root = made.root
	instance.geometry = made.geometry
	instance.materials = made.all_materials
	instance.lights = made.lights
	instance.module_roots = made.module_roots
	instance.age_materials = made.age_materials
	instance.clock_materials = made.clock_materials
	instance.envelope_materials = made.envelope_materials
	instance.emitters = made.emitters
	instance.world_process_materials = made.world_process_materials
	instance.add_child(instance.source_root)
	return instance

func prepare_source_layer_mask(layer_mask: int) -> void:
	assert(not is_inside_tree() and layer_mask > 0)
	for piece: GeometryInstance3D in geometry:
		if piece.layers != 0 and piece.layers != layer_mask:
			piece.layers = layer_mask
	prepared_layer_mask = layer_mask

func has_verified_stable_paths() -> bool:
	return bank.stable_paths_verified

func sample(seconds: float) -> void:
	if not is_finite(seconds):
		return
	# Exact old occurrence-root world-unit conversion, not module/donor scale.
	var unit_scale := global_basis.get_scale().x
	if unit_scale != previous_unit_scale:
		for record in world_process_materials:
			for uniform in record.values:
				record.material.set_shader_parameter(uniform, record.values[uniform] * unit_scale)
		previous_unit_scale = unit_scale
	var selected: Dictionary = bank.entries[0]
	var age := seconds - float(selected.begin)
	var visible_now := age >= 0.0 and age < float(selected.seconds)
	if visible_now != visible_state:
		for module in module_roots:
			module.visible = visible_now
		visible_state = visible_now
	if not visible_now:
		return
	var desired := int(round(age * float(selected.hz)))
	if desired <= tick:
		return
	# Original leaves advance monotonically. No invented history reset on seek.
	tick = desired
	var source_age := float(tick) / float(selected.hz)
	for material: ShaderMaterial in age_materials:
		material.set_shader_parameter("support_age", source_age)
	for material: ShaderMaterial in clock_materials:
		material.set_shader_parameter("support_clock", source_age)
	if not envelope_written:
		for material: ShaderMaterial in envelope_materials:
			material.set_shader_parameter("support_envelope", float(selected.alpha_gain))
		envelope_written = true
	if source_age >= float(selected.emission_stop) and not stopped:
		for emitter: GPUParticles3D in emitters:
			emitter.emitting = false
		stopped = true

func debug_source_entries() -> Array:
	var result := []
	for index in bank.entries.size():
		var original: Dictionary = bank.entries[index]
		var observation := {"root": module_roots[index], "definition": original,
			"tick": tick, "stopped": stopped, "materials": [], "emitters": []}
		for at in original.material_indices:
			observation.materials.append(materials[at])
		for path in original.emitter_paths:
			observation.emitters.append(source_root.get_node(path))
		result.append(observation)
	return result

func source_bindings() -> Dictionary:
	return {"geometry": geometry, "materials": materials, "lights": lights,
		"static_material_topology": true, "prepared_source_layer_mask": prepared_layer_mask}

func capture_observation() -> Dictionary:
	return {"source": bank.source_phase, "modules": module_roots.size(), "geometry": geometry.size(),
		"private_materials": materials.size(), "world_coordinate_processes": world_process_materials.size(),
		"ticks": Array().duplicate() if bank.entries.is_empty() else range(bank.entries.size()).map(func(_index): return tick),
		"stopped_modules": module_roots.size() if stopped else 0,
		"visible_layers_removed": false, "runtime_geometry_generation": false,
		"runtime_shader_generation": false, "arbitrary_seeking_qualified": false,
		"human_approval_inferred": false}

const VfxPackageIO_a6a5eaecde = preload("res://assets/vfx/extensions/heavy-effects-20261020/scoped_resource_io.gd")
