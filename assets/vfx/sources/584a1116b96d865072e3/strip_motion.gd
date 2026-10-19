extends RefCounted
## Same authored strip equations and fragment programs, evaluated per vertex.
## Only source age, piece index and existing fit transforms remain live inputs.
const SourceMaterials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
static var meshes: Dictionary = {}
static var programs: Dictionary = {}
const KINDS := {"mantle": 0, "ground": 1, "heal": 2, "burst": 3,
	"quickened": 4, "twinned": 5, "distant": 6, "affinity": 7,
	"affinity_open": 8, "rage_open": 9, "accepted_ground": 10, "recovery": 11}


static func mesh(segments: int, three_columns: bool = false) -> ArrayMesh:
	var key := str(segments) + ("/3" if three_columns else "/2")
	var resource: ArrayMesh = meshes.get(key)
	if resource == null:
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for station in segments:
			for edge in (2 if three_columns else 1):
				for coordinate in [Vector2i(station, edge), Vector2i(station, edge + 1), Vector2i(station + 1, edge + 1), Vector2i(station, edge), Vector2i(station + 1, edge + 1), Vector2i(station + 1, edge)]:
					surface.set_uv(Vector2(float(coordinate.x) / segments, float(coordinate.y) * (.5 if three_columns else 1.0)))
					surface.add_vertex(Vector3.ZERO)
		resource = surface.commit()
		meshes[key] = resource
	return resource


static func prepare(material: ShaderMaterial, motion: String, index: int) -> void:
	var original: Shader = material.shader
	var key := original.code.sha256_text()
	var program: Shader = programs.get(key)
	if program == null:
		var code: String = original.code
		var expression := RegEx.new()
		expression.compile("void\\s+vertex\\s*\\(\\s*\\)\\s*\\{")
		var vertex := expression.search(code)
		assert(vertex != null, "Strip source must retain its original vertex/fragment program")
		code = code.insert(vertex.get_end(), "\nVERTEX = factory_strip_vertex(UV);\n")
		code = code.insert(vertex.get_start(), VfxPackageIO_584a1116b9.text("res://assets/vfx/sources/de07a853000513680ca5/strip_motion.gdshaderinc") + "\n")
		program = Shader.new()
		program.code = code
		programs[key] = program
	SourceMaterials.replace_shader(material, program)
	material.set_shader_parameter("factory_motion_kind", KINDS[motion])
	material.set_shader_parameter("factory_piece_index", index)

const VfxPackageIO_584a1116b9 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
