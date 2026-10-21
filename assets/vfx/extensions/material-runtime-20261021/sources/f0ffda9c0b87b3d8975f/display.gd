extends RefCounted
## Private draw operands for the exact immutable Curse display programs.
var draws: Array[GeometryInstance3D] = []
var source_clock: Variant
var envelope := 1.0
var releasing := false
var offset := 0.0
var previous_offset := INF
var clock_state := Vector4(0.0, 0.0, 1.0, 0.0)
var clock_written := false
var source_frame := Transform3D.IDENTITY
var frame_written := false


func bind(subject: Node3D, specifications: Array[Dictionary]) -> void:
	for specification: Dictionary in specifications:
		assert(specification.binding.kind == "override")
		var draw: GeometryInstance3D = subject.get_node(specification.binding.node)
		draws.append(draw)


func lifecycle(age: float, value: float, is_releasing: bool = false) -> void:
	source_clock = age
	envelope = value
	releasing = is_releasing


func publish(seconds: float, frame: Transform3D) -> void:
	# Match the original float64 subtraction and approximate write gate before
	# both terms undergo their original float32 GPU upload and addition.
	if source_clock != null:
		var candidate: float = float(source_clock) - seconds
		if not is_equal_approx(previous_offset, candidate):
			offset = candidate
			previous_offset = candidate
	var value := Vector4(seconds, offset, envelope, float(releasing))
	if not clock_written or value != clock_state:
		clock_written = true
		clock_state = value
		for draw: GeometryInstance3D in draws:
			draw.set_instance_shader_parameter("curse_clock_state", value)
	if not frame_written or frame != source_frame:
		source_frame = frame
		frame_written = true
		for draw: GeometryInstance3D in draws:
			_write_frame(draw, frame)


static func _write_frame(draw: GeometryInstance3D, value: Transform3D) -> void:
	draw.set_instance_shader_parameter("curse_frame_x", Vector4(value.basis.x.x, value.basis.x.y, value.basis.x.z, 0.0))
	draw.set_instance_shader_parameter("curse_frame_y", Vector4(value.basis.y.x, value.basis.y.y, value.basis.y.z, 0.0))
	draw.set_instance_shader_parameter("curse_frame_z", Vector4(value.basis.z.x, value.basis.z.y, value.basis.z.z, 0.0))
	draw.set_instance_shader_parameter("curse_frame_w", Vector4(value.origin.x, value.origin.y, value.origin.z, 1.0))


static func envelope_at(age: float, mode: String) -> float:
	var value := 1.0
	if mode == "touch":
		value = smoothstep(0.0, .16, age) * (1.0 - smoothstep(.68, 1.15, age))
	elif mode == "apply":
		value = smoothstep(0.0, .06, age) * (1.0 - smoothstep(1.15, 1.8, age))
	elif mode == "loop":
		value = smoothstep(0.0, .12, age)
	elif mode == "release":
		value = 1.0 - smoothstep(.20, 1.15, age)
	elif mode == "resisted":
		value = smoothstep(0.0, .08, age) * (1.0 - smoothstep(.25, .9, age))
	return value
