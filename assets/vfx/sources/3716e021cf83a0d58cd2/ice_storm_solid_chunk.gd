extends "res://assets/vfx/sources/2d994044ef3b352d4ebb/ice_storm_recipient_chunk.gd"
## Closed donor bounds prevent the intact ice from reading as an open bowl.
## Native texture/material/vertex UV seams and physical fracture remain.
const NativeOpacity = preload("res://assets/vfx/sources/39f30ee3f172ac269cd6/native_opacity.gd")


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/3716e021cf83a0d58cd2/ice_storm_solid_chunk.gd", input)


func normalized(_source: Mesh) -> ArrayMesh:
	var data: Dictionary = JSON.parse_string(VfxPackageIO_3716e021cf.text(parameters.solid_geometry_resource))
	var definition: Dictionary = data.variants[int(settings.variant) % data.variants.size()]
	var expected: Array = definition.size
	assert(size.is_equal_approx(Vector3(expected[0], expected[1], expected[2])), "Solid geometry must match actual source normalization")
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	vertices.clear()
	for vertex in definition.faces:
		var point := Vector3(vertex.position[0], vertex.position[1], vertex.position[2])
		surface.set_uv(Vector2(vertex.uv[0], vertex.uv[1]))
		surface.set_normal(Vector3(vertex.normal[0], vertex.normal[1], vertex.normal[2]))
		surface.add_vertex(point)
		vertices.append(point)
	return surface.commit()


func material() -> ShaderMaterial:
	var result: ShaderMaterial = super.material()
	var shader := Shader.new()
	shader.code = result.shader.code.replace("ALPHA=.94;", "ALPHA=1.0;")
	SourceMaterials.replace_shader(result, shader)
	return result


func apply_scene_edits(node: Node) -> void:
	super.apply_scene_edits(node)
	NativeOpacity.apply(self)


func advance_lifecycle(delta: float) -> void:
	super.advance_lifecycle(delta)
	var age := float(tick) / float(parameters.simulation_hz)
	var fade := 1.0 - smoothstep(2.55, 2.98, age)
	for source_material in [ice, interior, impact_mat]:
		source_material.set_shader_parameter("factory_occurrence_alpha", fade)

const VfxPackageIO_3716e021cf = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
