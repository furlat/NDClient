extends RefCounted
## Private runtime state for original fixed VAT evaluators. No source graph,
## simulation, image upload, global clock allocation or geometry work.
var emitters: Array[GPUParticles3D] = []
var materials: Array[ShaderMaterial] = []
var age_operand := PackedFloat32Array([0.0])
var emission_stop := INF
var source_rate := 60.0

func _init(field: Node3D) -> void:
	source_rate = field.bank.rate
	for index in field.bank.system_node_indices:
		var node: GPUParticles3D = field.nodes[index]
		var process: ShaderMaterial = node.process_material
		assert(process != null and process.get_meta("factory_recorded_time_shader") == process.shader)
		emitters.append(node)
		materials.append(process)

func sample(seconds: float) -> void:
	# The receiver stores seconds in an RGBAF Image. One private typed store
	# preserves exactly that float32 operand before the identical GPU maths.
	age_operand[0] = seconds
	for material in materials:
		material.set_shader_parameter("factory_recorded_age",float(age_operand[0]))

func stop_emission(seconds: float) -> void:
	if is_equal_approx(emission_stop,seconds):
		return
	emission_stop = seconds
	var frame: float = seconds*source_rate if is_finite(seconds) else 1000000.0
	for material in materials:
		material.set_shader_parameter("emission_stop_frame",frame)
