extends Node3D
## Brief connected touch and closing spirit strands, fitted to the downed pose.
## No healing number, optical light, standing transition or maintained condition.
const Graph = preload("res://assets/vfx/sources/1d02b6d800655ef86df2/resource_graph.gd")
const SourceMaterials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
const Palette = preload("res://assets/vfx/sources/386bc581a35eb3b9ee50/spatial_energy_palette.gd")
const Ribbon = preload("res://assets/vfx/sources/31348bd589e2d41ae443/path_ribbon.gd")
var specification: Dictionary = {}
var endpoints: Array = []
var geometry: Dictionary = {}
var strands: Array[MeshInstance3D] = []


static func make_component(input: Dictionary) -> Node3D:
	var effect: Node3D = VfxPackageIO_673af89c2c.resource("res://assets/vfx/sources/673af89c2c01f913195f/stabilize_touch.gd").new()
	effect.specification = input.duplicate(true)
	return effect


func set_live_endpoints(value: Array) -> void:
	endpoints = value


func set_entity_geometry(value: Dictionary) -> void:
	geometry = value


func prepare() -> void:
	var source: Node3D = VfxPackageIO_673af89c2c.resource(specification.material_scene).instantiate()
	var original: ShaderMaterial = source.get_node(specification.material_node).material_override
	for index in 3:
		var draw := MeshInstance3D.new()
		draw.name = "ClosingSpiritStrand" + str(index)
		draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		draw.material_override = Graph.clone_value(original, {})
		var material: ShaderMaterial = draw.material_override
		var shader := Shader.new()
		var code: String = SourceMaterials.expand_shader(material.shader.code, material.shader.resource_path.get_base_dir())
		# Retain the source smoke/mask material, applied to actual world ribbons.
		# Its former GPU-quad billboard must not flatten the new path geometry.
		code = code.replace("MODELVIEW_MATRIX = n_out2p0;", "")
		code = code.replace("TIME", "touch_clock").replace("shader_type spatial;", "shader_type spatial;\nuniform float touch_clock=0.0;\nuniform float touch_envelope=0.0;")
		code = SourceMaterials.finish_fragment(code, "\nALPHA*=touch_envelope*pow(max(0.0,1.0-abs(UV.x*2.0-1.0)),1.5)*smoothstep(0.0,0.12,UV.y)*(1.0-smoothstep(0.88,1.0,UV.y));\n")
		shader.code = SourceMaterials.stable_proximity(code)
		SourceMaterials.replace_shader(material, shader)
		Palette.apply(material, specification.palette, {"quantize": false, "emission_gain": 0.12})
		add_child(draw)
		strands.append(draw)
	source.free()


func sample(seconds: float) -> void:
	if strands.is_empty(): prepare()
	if endpoints.is_empty() or geometry.get("points", []).is_empty():
		for strand in strands: strand.hide()
		return
	var inverse := global_transform.affine_inverse()
	var recipient := Vector3.ZERO
	for point in geometry.points:
		recipient += inverse * point.position
	recipient /= float(geometry.points.size())
	var hand: Vector3 = inverse * endpoints[0].point
	var envelope: float = smoothstep(0.0, 0.22, seconds) * (1.0 - smoothstep(0.8, 1.7, seconds))
	var closing: float = smoothstep(0.15, 0.65, seconds)
	for index in strands.size():
		var points: Array[Vector3] = []
		var widths: Array[float] = []
		for sample_index in 20:
			var phase: float = float(sample_index) / 19.0
			var arch := Vector3(cos(float(index) * TAU / 3.0), 0.6, sin(float(index) * TAU / 3.0)) * sin(phase * PI) * 0.13
			var destination: Vector3 = recipient + Vector3(0.0, 0.08, 0.0)
			var start: Vector3 = hand.lerp(recipient + Vector3(0.0, 0.22, 0.0), closing)
			points.append(start.lerp(destination, phase) + arch)
			widths.append(0.045 * sin(phase * PI))
		var strand: MeshInstance3D = strands[index]
		if specification.get("gpu_paths",false):
			preload("res://assets/vfx/sources/34e0f9ed9a909885cd97/path_ribbon.gd").assign(strand,points,widths,Color.WHITE,Vector2(0,1),false)
		else:
			strand.mesh = Ribbon.build(points, widths)
		strand.visible = envelope > 0.001
		strand.material_override.set_shader_parameter("touch_clock", seconds + float(index) * 0.21)
		strand.material_override.set_shader_parameter("touch_envelope", envelope * 0.8)


func capture_observation() -> Dictionary:
	return {"measured_points": geometry.get("points", []).size(), "source": specification.material_scene,
		"lights": 0, "healing_or_standing_transition": false, "connected_touch_strands": strands.size()}

const VfxPackageIO_673af89c2c = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
