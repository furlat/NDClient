extends RefCounted
const SourceMaterials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
static var programs: Dictionary = {}


static func template(segments: int,fins: int,gust: bool) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for fin in fins:
		for station in segments:
			for cell in [Vector2i(station,0),Vector2i(station,1),Vector2i(station+1,0),Vector2i(station,1),Vector2i(station+1,1),Vector2i(station+1,0)]:
				var u := float(cell.x)/float(segments)
				surface.set_uv(Vector2(cell.y,u) if gust else Vector2(u,cell.y))
				surface.set_color(Color(1,1,1,.025) if gust else Color.WHITE)
				surface.set_normal(Vector3.UP)
				surface.set_tangent(Plane(1,0,0,1))
				surface.add_vertex(Vector3(cell.x,float(cell.y)*2.0-1.0,fin))
	return surface.commit()


static func prepare(material: ShaderMaterial,kind: String,instanced: bool = false,vertex_invocation: String = "") -> void:
	var key := material.shader.code.sha256_text()+kind+str(instanced)+vertex_invocation
	var shader: Shader = programs[key].get_ref() if programs.has(key) else null
	if shader == null:
		var code: String = material.shader.code
		var expression := RegEx.new()
		expression.compile("void\\s+vertex\\s*\\(\\s*\\)\\s*\\{")
		var vertex := expression.search(code)
		var include := VfxPackageIO_801b495c0b.text("factory-path:factory/components/gpu_motion/"+kind+".gdshaderinc")
		var invocation := vertex_invocation if not vertex_invocation.is_empty() else "gpu_directed_vertex(VERTEX,NORMAL,TANGENT,BINORMAL);"
		if instanced:
			invocation = "float instance_gate;gpu_instance_vertex(VERTEX,NORMAL,TANGENT,BINORMAL,INSTANCE_ID,instance_gate);gpu_instance_gate=instance_gate;"
		if vertex == null:
			var fragment_start := code.find("void fragment()")
			assert(fragment_start>=0)
			code = code.insert(fragment_start,include+"\n")
			code += "\nvoid vertex(){"+invocation+"}\n"
		else:
			code = code.insert(vertex.get_end(),invocation)
			code = code.insert(vertex.get_start(),include+"\n")
		if instanced:
			code = SourceMaterials.finish_fragment(code,"\nALPHA*=gpu_instance_gate;\n")
		shader = Shader.new()
		shader.code = code
		programs[key] = weakref(shader)
	SourceMaterials.replace_shader(material,shader)

const VfxPackageIO_801b495c0b = preload("res://assets/vfx/extensions/owner-fields-v2-20261021/scoped_resource_io.gd")
