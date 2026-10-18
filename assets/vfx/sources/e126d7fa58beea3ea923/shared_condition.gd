extends "res://assets/vfx/sources/2a457ce5caa83a1c9dfb/receiving_effect.gd"
## Reuses an exact existing condition phase. This adapter only binds the current
## receiving owner, admission and retirement; it invents no condition artwork.
const NativeOpacity = preload("res://assets/vfx/sources/39f30ee3f172ac269cd6/native_opacity.gd")
const ResourceGraph = preload("res://assets/vfx/sources/1d02b6d800655ef86df2/resource_graph.gd")
const ParticleUnits = preload("res://assets/vfx/sources/07cc721710dacce01ef6/native_particle_units.gd")

var condition_art: Node3D
var opacity_materials: Array[ShaderMaterial] = []
var source_particle_units: Array = []
var receiving_pose: Array = []
var receiving_origin := Vector3.ZERO
var receiving_frame: Dictionary = {}


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/e126d7fa58beea3ea923/shared_condition.gd", input)


func phase_admitted() -> bool:
	if settings.mode == "condition_retire":
		return event_admitted() and event_input.get("removed_condition_uuids", []).has(str(settings.owner_uuid))
	return owner_admitted()


func _ready() -> void:
	prepare_source()


func prepare_source() -> void:
	if condition_art != null:
		return
	var phase: Resource = VfxPackageIO_e126d7fa58.resource(str(settings.shared_phase))
	assert(phase != null and phase.components.size() == 1, "Shared condition phase must be exact and singular")
	var definition: Dictionary = phase.components[0].to_component()
	ResourceGraph.native_sampler_scopes += 1
	condition_art = VfxPackageIO_e126d7fa58.resource(str(definition.script)).make_component(definition.input)
	ResourceGraph.native_sampler_scopes -= 1
	condition_art.top_level = true
	add_child(condition_art)
	condition_art.sample(.0)
	var source_scale: float = float(settings.get("shared_source_scale",1.0))
	if not is_equal_approx(source_scale,1.0):
		# The factory converts world particle lengths by the outer root scale.
		# This exact reused source has a smaller nested scale of its own. Its
		# static world dimensions need that factor once before host discovery.
		for emitter in condition_art.find_children("*","GPUParticles3D",true,false):
			var binding: Dictionary = ParticleUnits.prepare(emitter)
			if not binding.is_empty():
				source_particle_units.append(binding)
		ParticleUnits.apply(source_particle_units,source_scale)
	NativeOpacity.apply(condition_art)
	_collect(condition_art,{})
	for light in condition_art.find_children("*","Light3D",true,false):
		light.visible = false
	condition_art.hide()


func _rebuild() -> void:
	frame = _measured_frame()
	if frame.is_empty() or envelope <= .0001:
		if condition_art != null:
			condition_art.hide()
		return
	if condition_art == null:
		prepare_source()
	condition_art.show()
	var source_scale: float = float(settings.get("shared_source_scale",1.0))
	condition_art.global_transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*source_scale), surface.origin)
	var current_endpoints: Array = endpoints.duplicate(true)
	if settings.shared_kind == "stunned":
		current_endpoints = [{"actor":settings.geometry_actor,"socket":"head","point":Vector3(frame.centre.x,frame.top,frame.centre.z)}]
	if condition_art.has_method("set_live_endpoints"):
		condition_art.set_live_endpoints(current_endpoints)
	condition_art.sample(minf(local_clock+float(settings.get("shared_source_offset",.0)),float(settings.shared_source_end)))
	if settings.shared_kind == "marker":
		condition_art.plane.position = condition_art.to_local(Vector3(frame.centre.x,frame.top+.23,frame.centre.z))
		condition_art.plane.position += frame.side * float(settings.get("marker_across_cells",.0))
	elif settings.shared_kind == "blinded":
		# Original cloud/eye mark retain their artwork and dimensions. Only their
		# original proxy heights are reanchored to the actual current head.
		for effect in condition_art.composition.components.values():
			for node in effect.subject.get_children():
				if node is GPUParticles3D and node.layers != 0:
					node.position.y = (frame.top-surface.origin.y+.12)/source_scale
				elif node is MeshInstance3D:
					node.position.y = (frame.top-surface.origin.y+.35)/source_scale
	# Source graph and native opacity shaders are prepared once above.
	for selected in opacity_materials:
		selected.set_shader_parameter(NativeOpacity.UNIFORM,envelope)


func _measured_frame() -> Dictionary:
	if surface.get("points", []).size() < 8:
		return {}
	var key: Array = preload("res://assets/vfx/sources/9c05cee00f7d74560348/geometry_key.gd").from_surface(surface)
	var origin: Vector3 = surface.origin
	if key.is_empty() or receiving_frame.is_empty() or receiving_pose != key:
		receiving_frame = Frame.measure(surface)
		receiving_pose = key.duplicate(true)
		receiving_origin = origin
	var result := receiving_frame.duplicate()
	if not result.is_empty():
		var offset := origin - receiving_origin
		result.centre += offset
		result.top += offset.y
		result.bottom += offset.y
		result.origin = origin
	return result


func _collect(value: Object, visited: Dictionary) -> void:
	if visited.has(value):
		return
	visited[value] = true
	if value is ShaderMaterial and value.has_meta(NativeOpacity.UNIFORM):
		opacity_materials.append(value)
	for property in value.get_property_list():
		if int(property.usage) & PROPERTY_USAGE_STORAGE:
			var selected: Variant = value.get(property.name)
			if selected is Resource and not selected is Shader:
				_collect(selected,visited)
	if value is Mesh:
		for index in value.get_surface_count():
			var selected: Material = value.surface_get_material(index)
			if selected != null:
				_collect(selected,visited)
	if value is Node:
		for child in value.get_children():
			_collect(child,visited)


func capture_observation() -> Dictionary:
	var row: Dictionary = super.capture_observation()
	row.high_level_support.shared_condition_phase = settings.shared_phase
	row.high_level_support.shared_condition_visible = condition_art != null and condition_art.is_visible_in_tree()
	row.high_level_support.shared_condition_materials = opacity_materials.size()
	row.high_level_support.shared_source_scale = float(settings.get("shared_source_scale",1.0))
	row.high_level_support.shared_world_particle_units = source_particle_units.size()
	return row

const VfxPackageIO_e126d7fa58 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
