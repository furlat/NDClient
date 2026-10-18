extends Node3D
## A supplied presentation interrupt of one exact original native spell phase.
## It holds the original source clock and transform, then erodes that material
## with the preserved 500 ms noise coverage. It never decides game outcomes.

const SourceMaterials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")

var settings: Dictionary = {}
var source: Node3D
var materials: Array[ShaderMaterial] = []
var source_seconds: float = 0.0
var coverage_phase: float = -0.05
var sample_position: Vector3 = Vector3.ZERO


static func make_component(input: Dictionary) -> Node3D:
	var effect: Node3D = VfxPackageIO_26d73abcda.resource("res://assets/vfx/sources/26d73abcda3a1307307d/interrupted_source.gd").new()
	effect.settings = input.duplicate(true)
	effect.prepare()
	return effect


func prepare() -> void:
	var phase: Resource = VfxPackageIO_26d73abcda.resource(settings.phase_resource)
	assert(phase != null and phase.components.size() == 1, "Explicit original native phase is required")
	var selected: Resource = phase.components[0]
	source = VfxPackageIO_26d73abcda.resource(selected.constructor_script).make_component(selected.input)
	add_child(source)
	source.sample(0.0)
	_collect_materials(source)
	assert(not materials.is_empty(), "Original incoming source has no native material to dissipate")
	for material in materials:
		var code: String = SourceMaterials.expand_shader(material.shader.code, material.shader.resource_path.get_base_dir())
		code = code.replace("shader_type spatial;", "shader_type spatial;\nuniform sampler2D interrupt_noise:repeat_enable,filter_nearest;\nuniform float interrupt_phase=-0.05;\n")
		code = SourceMaterials.finish_fragment(code, "\nfloat interrupt_coverage=step(interrupt_phase,texture(interrupt_noise,UV*2.0).r*0.7+UV.x*0.3); ALPHA*=interrupt_coverage;\n")
		var shader := Shader.new()
		shader.code = code
		SourceMaterials.replace_shader(material, shader)
		material.set_shader_parameter("interrupt_noise", VfxPackageIO_26d73abcda.resource(settings.noise_texture))
	visible = false


func _collect_materials(node: Node) -> void:
	if node is GeometryInstance3D:
		if node.material_override is ShaderMaterial and not materials.has(node.material_override):
			materials.append(node.material_override)
		elif node is MeshInstance3D and node.mesh != null:
			for index in node.mesh.get_surface_count():
				var material: Material = node.get_active_material(index)
				if material is ShaderMaterial and not materials.has(material):
					materials.append(material)
		elif node is GPUParticles3D:
			for index in node.draw_passes:
				var mesh: Mesh = node.get("draw_pass_" + str(index + 1))
				if mesh != null:
					for surface in mesh.get_surface_count():
						var material: Material = mesh.surface_get_material(surface)
						if material is ShaderMaterial and not materials.has(material):
							materials.append(material)
	for child in node.get_children():
		_collect_materials(child)


func sample_observation(seconds: float, observation: Dictionary) -> void:
	var began: float = float(observation.release_seconds)
	var contact: float = float(observation.contact_seconds)
	var arrival: float = float(observation.arrival_seconds)
	var succeeded: bool = observation.succeeded
	var held_time: float = minf(seconds, contact) if succeeded else seconds
	source_seconds = maxf(0.0, held_time - began) + float(observation.source_offset_seconds)
	source.sample(source_seconds)
	for emitter in source.find_children("*", "GPUParticles3D", true, false):
		emitter.speed_scale = 0.0 if succeeded and seconds >= contact else 1.0
		emitter.emitting = not (succeeded and seconds >= contact)
	var from: Vector3 = observation.source_world
	var to: Vector3 = observation.target_world
	var progress: float = clampf((held_time - began) / maxf(0.001, arrival - began), 0.0, 1.0)
	sample_position = from.lerp(to, progress)
	if succeeded and seconds >= contact:
		sample_position = observation.contact_world
	position = get_parent().global_transform.affine_inverse() * sample_position
	var direction: Vector3 = (to - from).normalized()
	source.basis = Basis.looking_at(direction, Vector3.UP) if absf(direction.y) < 0.99 and not direction.is_zero_approx() else Basis.IDENTITY
	source.scale = Vector3.ONE * float(settings.scale_cells_per_source_unit)
	coverage_phase = lerpf(-0.05, 1.05, clampf((seconds - contact) / 0.5, 0.0, 1.0)) if succeeded else -0.05
	for material in materials:
		material.set_shader_parameter("interrupt_phase", coverage_phase)
	visible = seconds >= began and (seconds < contact + 0.5 if succeeded else seconds < arrival)

const VfxPackageIO_26d73abcda = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
