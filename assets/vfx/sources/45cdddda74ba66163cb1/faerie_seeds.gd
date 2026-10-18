extends "res://assets/vfx/sources/2124c27274ad67bd1b12/faerie_seeds.gd"
## Supplied cells and original masks; one static instanced draw, no mesh rebuild.
const SourceMaterials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
const Programs = preload("res://assets/vfx/sources/801b495c0bd760a8e358/directed_program.gd")
var gleams: MultiMeshInstance3D


static func make_component(input: Dictionary) -> Node3D:
	var effect: Node3D = VfxPackageIO_45cdddda74.resource("res://assets/vfx/sources/45cdddda74ba66163cb1/faerie_seeds.gd").new()
	effect.specification = input.duplicate(true)
	effect.prepare()
	return effect


func prepare() -> void:
	super.prepare()
	for draw in draws:
		draw.free()
	draws.clear()
	Programs.prepare(material, "faerie_seeds", true)
	var shader := Shader.new()
	var code: String = material.shader.code
	code = code.replace("gpu_instance_gate=instance_gate;", "gpu_instance_gate=instance_gate;gpu_faerie_seed=texelFetch(gpu_faerie_data,ivec2(0,INSTANCE_ID),0).w;")
	code = code.replace("-local_clock_seconds * .42", "-(local_clock_seconds + gpu_faerie_seed) * .42")
	code = code.replace("local_clock_seconds * .50", "(local_clock_seconds + gpu_faerie_seed) * .50")
	shader.code = code
	SourceMaterials.replace_shader(material, shader)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var indices := PackedInt32Array()
	for fin in 3:
		for station in 9:
			for edge in [-1.0, 1.0]:
				surface.set_uv(Vector2((edge + 1.) * .5, float(station) / 8.))
				surface.set_normal(Vector3.UP)
				surface.set_tangent(Plane(1, 0, 0, 1))
				surface.add_vertex(Vector3(station, edge, fin))
			if station > 0:
				var first := fin * 18 + (station - 1) * 2
				indices.append_array(PackedInt32Array([first, first + 1, first + 2, first + 1, first + 3, first + 2]))
	for index in indices:
		surface.add_index(index)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = surface.commit()
	multimesh.instance_count = specification.cells.size()
	var image := Image.create(2, maxi(1, multimesh.instance_count), false, Image.FORMAT_RGBAF)
	var bounds := AABB(Vector3.ZERO, Vector3.ZERO)
	for index in multimesh.instance_count:
		multimesh.set_instance_transform(index, Transform3D.IDENTITY)
		var cell: Array = specification.cells[index]
		var seed := float(index) * 2.39996
		var origin := Vector3(cell[0] + cos(seed) * .27, 0, cell[1] + sin(seed) * .27)
		image.set_pixel(0, index, Color(origin.x, origin.z, fposmod(sin(seed * 7.15) * 351.37, 1.) * .20, seed))
		image.set_pixel(1, index, Color(cos(seed), sin(seed), 0, 1))
		bounds = bounds.expand(origin)
	material.set_shader_parameter("gpu_faerie_data", ImageTexture.create_from_image(image))
	gleams = MultiMeshInstance3D.new()
	gleams.name = "OriginalInitialFeyGleams"
	gleams.multimesh = multimesh
	gleams.material_override = material
	gleams.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gleams.custom_aabb = bounds.grow(1.0)
	add_child(gleams)


func sample(seconds: float) -> void:
	material.set_shader_parameter("gpu_faerie_time", seconds)
	material.set_shader_parameter("local_clock_seconds", seconds)
	gleams.visible = seconds >= 0.0 and seconds < .98 and gleams.multimesh.instance_count > 0

const VfxPackageIO_45cdddda74 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
