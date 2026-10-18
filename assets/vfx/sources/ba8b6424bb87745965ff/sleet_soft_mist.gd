extends "res://assets/vfx/sources/eeb1fa57d7bc1727c667/sleet_storm.gd"
## Soft source-material mist patches; no ellipsoid skin or full-width slice.
const SourceFinish = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/ba8b6424bb87745965ff/sleet_soft_mist.gd", input)


func apply_scene_edits(node: Node) -> void:
	super.apply_scene_edits(node)
	if side == "ground":
		return
	# Original construction/seed draws run first, retaining the real rain bank.
	for index in mist_mats.size():
		var cloud: MeshInstance3D = assembly.get_child(index)
		var angle: float = float(index) * 2.3999632297
		var radius: float = sqrt((float(index) + .5) / 9.0) * 5.6
		var card := QuadMesh.new()
		card.size = Vector2(7.8 + .9 * sin(angle * .73), 4.6 + .7 * cos(angle * 1.11))
		cloud.mesh = card
		cloud.position = Vector3(cos(angle) * radius, 1.65 + .62 * sin(angle * 1.7), sin(angle) * radius)
		cloud.scale = Vector3.ONE
		var material: ShaderMaterial = mist_mats[index]
		material.set_shader_parameter("billboard", true)
		# Source circle is white centrally and smoothly black at its perimeter.
		material.set_shader_parameter("use_mask3", true)
		material.set_shader_parameter("mask3_texture", VfxPackageIO_ba8b6424bb.resource("res://assets/vfx/sources/047894e37616be2652c5/circle.tres"))
		material.set_shader_parameter("mask3_blend_mode", 2)
		material.set_shader_parameter("mask3_strength", 1.0)
		material.set_shader_parameter("mask3_scale", Vector2.ONE)
		material.set_shader_parameter("mask3_scroll", Vector2.ZERO)
		material.set_shader_parameter("mask3_radial", false)
		var shader := Shader.new()
		shader.code = SourceFinish.finish_fragment(material.shader.code,
			"\nvec2 sleet_drift=vec2(sin(weather_clock*3.14159265359),cos(weather_clock*3.14159265359))*.07;\n" +
			"float sleet_wisp_noise=texture(weather_edge_noise,UV*3.3+wp.xz*.19+sleet_drift).r;\n" +
			"ALPHA*=smoothstep(.12,.58,sleet_wisp_noise);\n")
		SourceFinish.replace_shader(material,shader)

const VfxPackageIO_ba8b6424bb = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
