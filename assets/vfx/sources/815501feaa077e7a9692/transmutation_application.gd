extends Node3D
## Two selected native ground-material layers, not an enclosing source shell.
## The receiving spell supplies growth/shrink direction; this applies no size.
const Resources = preload("res://assets/vfx/sources/1d02b6d800655ef86df2/resource_graph.gd")
const Sources = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
const Palette = preload("res://assets/vfx/sources/386bc581a35eb3b9ee50/spatial_energy_palette.gd")
var specification: Dictionary = {}
var draws: Array[MeshInstance3D] = []
var materials: Array[ShaderMaterial] = []


static func make_component(input: Dictionary) -> Node3D:
	var effect: Node3D = VfxPackageIO_815501feaa.resource("res://assets/vfx/sources/815501feaa077e7a9692/transmutation_application.gd").new()
	effect.specification = input.duplicate(true)
	return effect


func prepare() -> void:
	var source: Node3D = VfxPackageIO_815501feaa.resource(specification.source_scene).instantiate()
	for layer in specification.layers:
		var original: MeshInstance3D = source.get_node(layer.node)
		var material: ShaderMaterial = Resources.clone_value(original.material_override, {})
		var code: String = Sources.expand_shader(material.shader.code, material.shader.resource_path.get_base_dir())
		var token := RegEx.new()
		token.compile("\\bTIME\\b")
		code = token.sub(code, "application_clock", true)
		code = code.replace("shader_type spatial;", "shader_type spatial;\nuniform float application_clock=0.0;\nuniform float application_alpha=0.0;")
		code = code.replace("depth_draw_opaque", "depth_draw_never")
		code = Sources.finish_fragment(code, "\nALPHA *= application_alpha;\n")
		var shader := Shader.new()
		shader.code = code
		Sources.replace_shader(material, shader)
		Palette.apply(material, specification.palette, {"quantize": false, "emission_gain": 0.08})
		var draw := MeshInstance3D.new()
		draw.name = str(layer.node)
		draw.mesh = original.mesh
		draw.material_override = material
		draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var bounds: AABB = original.mesh.get_aabb()
		var native_width: float = maxf(bounds.size.x, bounds.size.z)
		assert(native_width > 0.001)
		draw.scale = Vector3.ONE * float(layer.diameter_cells) / native_width
		draw.position.y = float(layer.height_cells)
		draw.set_meta("base_scale", draw.scale)
		add_child(draw)
		draws.append(draw)
		materials.append(material)
	source.free()


func sample(seconds: float) -> void:
	if draws.is_empty():
		prepare()
	var duration: float = float(specification.duration_seconds)
	var progress: float = clampf(seconds / duration, 0.0, 1.0)
	var envelope: float = smoothstep(0.0, 0.08, seconds) * (1.0 - smoothstep(duration * 0.5, duration, seconds))
	var grow: bool = float(specification.direction) > 0.0
	var radius: float = lerpf(0.52, 1.0, progress if grow else 1.0 - progress)
	for index in draws.size():
		var draw: MeshInstance3D = draws[index]
		draw.visible = envelope > 0.001
		draw.scale = draw.get_meta("base_scale") * radius
		draw.rotation.y = float(specification.direction) * seconds * (0.3 if index == 0 else -0.45)
		materials[index].set_shader_parameter("application_clock", seconds)
		materials[index].set_shader_parameter("application_alpha", envelope * float(specification.opacity))


func capture_observation() -> Dictionary:
	return {"selected_native_ground_layers": draws.size(), "source_scene": specification.source_scene,
		"direction": specification.direction, "enclosing_geometry": false,
		"applies_size_change": false, "optical_lights_added": 0}

const VfxPackageIO_815501feaa = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
