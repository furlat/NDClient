extends Node3D
## Reuses the exact accepted steady Frightened symbol/material data. The
## retained owner supplies lifetime; its steady source window does not restart.
const Marker = preload("res://assets/vfx/sources/956b2fde8af4cd11d880/overhead_marker.gd")
const SourceMaterials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")

var marker: Node3D
var local_clock := 0.0
var owner_visibility := 1.0

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = VfxPackageIO_cc00c6bede.resource("res://assets/vfx/sources/cc00c6beded94e2ece93/maintained_marker.gd").new()
	var accepted: Resource = VfxPackageIO_cc00c6bede.resource(input.accepted_phase)
	assert(accepted.components.size() == 1 and accepted.components[0].constructor_script == "res://assets/vfx/sources/956b2fde8af4cd11d880/overhead_marker.gd")
	instance.marker = Marker.make_component(accepted.components[0].input.duplicate(true))
	var material: ShaderMaterial = instance.marker.plane.material_override
	# The original accepted glyph uses cutout transparency. Alpha attenuation
	# cannot fade that binary output. Only this maintained adapter derivative
	# blends its retirement, retaining the same steady art/samplers/palette.
	var code: String = material.shader.code.replace("ALPHA_SCISSOR_THRESHOLD = .025;", "")
	assert(not code.contains("ALPHA_SCISSOR_THRESHOLD"))
	code = code.replace("shader_type spatial;", "shader_type spatial;\nuniform float marker_tail_opacity=1.0;\n")
	var shader := Shader.new()
	shader.code = SourceMaterials.finish_fragment(code, "\nALPHA*=marker_tail_opacity;\n")
	SourceMaterials.replace_shader(material, shader)
	instance.add_child(instance.marker)
	return instance

func sample(seconds: float) -> void:
	local_clock = seconds
	marker.sample(minf(seconds, .5))
	var material: ShaderMaterial = marker.plane.material_override
	material.set_shader_parameter("marker_envelope", smoothstep(0.0, .12, seconds) * owner_visibility)

func set_owner_visibility(value: float) -> void:
	owner_visibility = clampf(value, 0.0, 1.0)
	sample(local_clock)

const VfxPackageIO_cc00c6bede = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
