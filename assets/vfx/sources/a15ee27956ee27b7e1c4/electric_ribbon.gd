extends RefCounted
const SourceMaterials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
static var meshes: Dictionary = {}
static var programs: Dictionary = {}
static var textures: Dictionary = {}
static var contact_random: WeakRef
const CONTACT_SEGMENTS := 64


static func mesh(bank: Resource, glow: bool) -> ArrayMesh:
	var key := "%d/%d/%d/%d/%s" % [bank.primary_lanes, bank.primary_segments, bank.fork_count, bank.fork_samples, str(glow)]
	var result: ArrayMesh = meshes[key].get_ref() if meshes.has(key) else null
	if result == null:
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for path in bank.primary_lanes + bank.fork_count:
			var segments: int = bank.primary_segments if path < bank.primary_lanes else bank.fork_samples-1
			for layer in (1 if glow else 3):
				for point in segments:
					for coordinate in [Vector2i(point,0), Vector2i(point,1), Vector2i(point+1,1), Vector2i(point,0), Vector2i(point+1,1), Vector2i(point+1,0)]:
						surface.set_uv(Vector2(coordinate.y,0))
						surface.set_normal(Vector3.UP)
						surface.set_color(Color.WHITE)
						surface.add_vertex(Vector3(coordinate.x,path,layer))
		result = surface.commit()
		meshes[key] = weakref(result)
	return result


static func prepare(material: ShaderMaterial, bank: Resource, glow: bool) -> void:
	var original: Shader = material.shader
	var key := original.code.sha256_text()
	var program: Shader = programs[key].get_ref() if programs.has(key) else null
	if program == null:
		var code: String = original.code
		var expression := RegEx.new()
		expression.compile("void\\s+vertex\\s*\\(\\s*\\)\\s*\\{")
		var vertex := expression.search(code)
		assert(vertex != null)
		code = code.insert(vertex.get_end(), "\nfloat gpu_energy_at_vertex; gpu_electric_deform(VERTEX,NORMAL,COLOR,UV,gpu_energy_at_vertex); gpu_ribbon_alpha=gpu_energy_at_vertex;\n")
		code = code.insert(vertex.get_start(), VfxPackageIO_a15ee27956.text("res://assets/vfx/sources/24eac2d88032c40d6047/electric_ribbon.gdshaderinc") + "\n")
		code = SourceMaterials.finish_fragment(code, "\nALPHA *= gpu_ribbon_alpha;\n")
		program = Shader.new()
		program.code = code
		programs[key] = weakref(program)
	SourceMaterials.replace_shader(material, program)
	var texture: ImageTexture = textures[bank.resource_path].get_ref() if textures.has(bank.resource_path) else null
	if texture == null:
		texture = ImageTexture.create_from_image(bank.atlas)
		textures[bank.resource_path] = weakref(texture)
	material.set_shader_parameter("gpu_shape_atlas", texture)
	for name in ["primary_lanes", "primary_segments", "fork_count", "fork_samples", "variations"]:
		material.set_shader_parameter("gpu_"+name, bank.get(name))
	material.set_shader_parameter("gpu_glow", glow)
	material.set_shader_parameter("alpha_mult", 1.0)


static func auxiliary_mesh(kind: String) -> ArrayMesh:
	var key := "auxiliary/"+kind
	var result: ArrayMesh = meshes[key].get_ref() if meshes.has(key) else null
	if result == null:
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		var segments := 17 if kind == "hand" else CONTACT_SEGMENTS
		for strand in (2 if kind == "hand" else 5):
			for point in segments:
				for coordinate in [Vector2i(point,0),Vector2i(point,1),Vector2i(point+1,1),Vector2i(point,0),Vector2i(point+1,1),Vector2i(point+1,0)]:
					surface.set_uv(Vector2(coordinate.y,0))
					surface.set_normal(Vector3.UP)
					surface.set_color(Color.WHITE)
					surface.add_vertex(Vector3(coordinate.x,strand,0))
		result = surface.commit()
		meshes[key] = weakref(result)
	return result


static func prepare_auxiliary(material: ShaderMaterial, kind: String) -> void:
	var key := material.shader.code.sha256_text()+"/"+kind
	var program: Shader = programs[key].get_ref() if programs.has(key) else null
	if program == null:
		var code: String = material.shader.code
		var expression := RegEx.new()
		expression.compile("void\\s+vertex\\s*\\(\\s*\\)\\s*\\{")
		var vertex := expression.search(code)
		assert(vertex != null)
		code = code.insert(vertex.get_end(), "\ngpu_"+kind+"_deform(VERTEX,NORMAL,COLOR,UV);\n")
		code = code.insert(vertex.get_start(), VfxPackageIO_a15ee27956.text("res://factory/components/gpu_motion/electric_"+kind+".gdshaderinc")+"\n")
		program = Shader.new()
		program.code = code
		programs[key] = weakref(program)
	SourceMaterials.replace_shader(material,program)
	if kind == "contact":
		var texture: ImageTexture = contact_random.get_ref() if contact_random != null else null
		if texture == null:
			var image := Image.create(CONTACT_SEGMENTS+1,5,false,Image.FORMAT_RGBAF)
			for strand in 5:
				var random := RandomNumberGenerator.new()
				random.seed = 6121+strand
				for point in CONTACT_SEGMENTS+1:
					image.set_pixel(point,strand,Color(random.randf_range(-.035,.035),random.randf_range(-.035,.035),0,1))
			texture = ImageTexture.create_from_image(image)
			contact_random = weakref(texture)
		material.set_shader_parameter("gpu_contact_random",texture)

const VfxPackageIO_a15ee27956 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
