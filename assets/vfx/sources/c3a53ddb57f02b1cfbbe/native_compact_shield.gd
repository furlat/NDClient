extends RefCounted
## One actual authored shield panel, not the donor's four-panel enclosure.
## Original vertices, UVs and material remain; the existing forms point table
## supplies the current recipient's torso support and normals on the GPU.
const Receiver = preload("res://assets/vfx/sources/c7903100e89e7c78c542/native_material_receiver.gd")
const SourceMaterials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")


static func make_component(input: Dictionary) -> Node3D:
	var root: Node3D = Receiver.make_component(input)
	var draw: MeshInstance3D = root.get_node("NativeReceivingMaterial")
	draw.name = "OriginalCompactShieldPanel"
	var original: Mesh = VfxPackageIO_c3a53ddb57.resource(input.source_mesh)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var selected_triangles := 0
	for index in original.get_surface_count():
		var arrays := original.surface_get_arrays(index)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var count := indices.size() if not indices.is_empty() else vertices.size()
		for triangle in range(0, count, 3):
			var face := PackedInt32Array()
			for corner in 3:
				face.append(indices[triangle + corner] if not indices.is_empty() else triangle + corner)
			if vertices[face[0]].z < .8 or vertices[face[1]].z < .8 or vertices[face[2]].z < .8:
				continue
			for vertex in face:
				surface.set_normal(normals[vertex])
				surface.set_uv(uv[vertex])
				surface.add_vertex(vertices[vertex])
			selected_triangles += 1
	assert(selected_triangles > 0, "Original +Z shield panel is required")
	draw.mesh = surface.commit()
	draw.set_meta("condition_receiving_template", true)
	draw.custom_aabb = AABB(Vector3.ONE * -8.0, Vector3.ONE * 16.0)
	var material: ShaderMaterial = draw.material_override
	var code: String = material.shader.code
	var support := VfxPackageIO_c3a53ddb57.text("res://assets/vfx/sources/bebc4dd61df33d98d06f/receiving_forms.gdshaderinc")
	code = code.insert(code.find(";") + 1, "\n" + support + "\n")
	code = SourceMaterials.finish_function(code, "vertex", """
// Normalize only the selected original panel; preserve its physical contour
// and shallow native curvature, independently of the original donor's radius.
float shield_across=VERTEX.x/.455;
float shield_along=(VERTEX.y-.0595)/.5395;
float shield_curve=clamp((VERTEX.z-.882)/.184,0.0,1.0);
vec3 shield_support;vec3 shield_normal;
gpu_body_support(shield_along*gpu_body_radii.x*.88,shield_across*gpu_body_radii.y*.88,shield_support,shield_normal);
VERTEX=shield_support+shield_normal*(.009+.010*shield_curve);
NORMAL=shield_normal;
""")
	code = SourceMaterials.finish_fragment(code, "\nif(gpu_body_count<8)discard;\n")
	var shader := Shader.new()
	shader.code = code
	SourceMaterials.replace_shader(material, shader)
	return root

const VfxPackageIO_c3a53ddb57 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
