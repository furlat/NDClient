extends Node3D
## One steady, authored glyph above an actor. No condition rules or playlist.
const MaterialPlane = preload("res://assets/vfx/sources/53a08b13a376af2ecd8a/material_plane.gd")

var plane: MeshInstance3D
var duration_seconds: float = 3.2

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = VfxPackageIO_956b2fde8a.resource("res://assets/vfx/sources/956b2fde8af4cd11d880/overhead_marker.gd").new()
	instance.duration_seconds = float(input.get("duration_seconds", 3.2))
	instance.plane = MaterialPlane.make_component({
		"size": input.get("size_cells", [.45, .45]),
		"material": input.material,
	})
	if instance.plane == null:
		instance.free()
		return null
	instance.add_child(instance.plane)
	instance.plane.position.y = float(input.get("height_cells", 1.2))
	var material: ShaderMaterial = instance.plane.material_override
	var shader := Shader.new()
	var code: String = material.shader.code.replace(
		"shader_type spatial;", "shader_type spatial;\nuniform float marker_envelope=1.0;")
	if input.get("source_cutout_as_coverage", false):
		# Cutout ALPHA is a coverage threshold, not final translucency. Preserve
		# that exact held coverage first, then apply independent owner envelopes
		# in the ordinary blend pass; otherwise a fade merely erodes opaque dots.
		var scissor := RegEx.new()
		scissor.compile("ALPHA_SCISSOR_THRESHOLD\\s*=\\s*([^;]+);")
		assert(scissor.search_all(code).size() == 1, "Source cutout coverage must have one explicit threshold")
		code = scissor.sub(code, "ALPHA = step($1, ALPHA);", true)
	var end: int = code.rfind("}")
	shader.code = code.insert(end, "\nALPHA *= marker_envelope;\n")
	material.shader = shader
	material.set_shader_parameter("glyph_clock", 0.0)
	return instance

func sample(seconds: float) -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera != null:
		plane.global_basis = camera.global_basis.orthonormalized().scaled(global_basis.get_scale())
	var envelope := smoothstep(0.0, .12, seconds) * (1.0 - smoothstep(duration_seconds - .25, duration_seconds, seconds))
	plane.material_override.set_shader_parameter("marker_envelope", envelope)

const VfxPackageIO_956b2fde8a = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
